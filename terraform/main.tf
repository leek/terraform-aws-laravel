# ========================================
# Terraform Configuration
# ========================================

# Common configuration
locals {
  common_tags = {
    Environment = var.environment
    Application = var.app_name
    Owner       = var.github_org
    Repository  = var.github_repo
    ManagedBy   = "Terraform"
    CostCenter  = var.cost_center
    Project     = "Laravel"
    CreatedBy   = "Terraform"
  }

  # Extract the root domain from the full domain name
  domain_parts = split(".", var.domain_name)
  root_domain  = length(local.domain_parts) > 2 ? join(".", slice(local.domain_parts, length(local.domain_parts) - 2, length(local.domain_parts))) : var.domain_name
  route53_zone_id = var.route53_zone_id != "" ? var.route53_zone_id : (
    var.manage_route53_dns ? data.aws_route53_zone.main[0].zone_id : ""
  )
  wait_for_acm_validation = coalesce(var.wait_for_acm_validation, var.manage_route53_dns)

  primary_certificate_ready = var.acm_certificate_arn != "" || local.wait_for_acm_validation
  vpn_certificate_ready     = var.vpn_server_certificate_arn != "" || local.wait_for_acm_validation

  # Workspace validation mapping
  workspace_environment_map = {
    staging    = "staging"
    uat        = "uat"
    production = "production"
  }

  # Database port mapping based on engine type
  db_port_map = {
    mysql             = 3306
    mariadb           = 3306
    postgres          = 5432
    aurora-mysql      = 3306
    aurora-postgresql = 5432
  }
  db_port = local.db_port_map[var.db_engine]

  db_connection_map = {
    mysql             = "mysql"
    mariadb           = "mysql"
    postgres          = "pgsql"
    aurora-mysql      = "mysql"
    aurora-postgresql = "pgsql"
  }
  db_connection = local.db_connection_map[var.db_engine]
}

# ========================================
# Workspace Validation
# ========================================

# Validate workspace matches environment to prevent accidental deployments.
check "workspace_matches_environment" {
  assert {
    condition     = terraform.workspace == var.environment
    error_message = "Terraform workspace '${terraform.workspace}' does not match environment '${var.environment}'. Please switch to the correct workspace using: terraform workspace select ${var.environment}"
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_route53_zone" "main" {
  count        = var.manage_route53_dns && var.route53_zone_id == "" ? 1 : 0
  name         = local.root_domain
  private_zone = false
}

# Data source for test email domains (only needed for non-production environments)
data "aws_route53_zone" "test_email_domain" {
  count        = var.manage_route53_dns && length(var.ses_test_email_domains) > 0 ? 1 : 0
  name         = var.ses_test_email_domains[0]
  private_zone = false
}

data "aws_caller_identity" "current" {}

# Random passwords
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# ========================================
# Core Infrastructure Modules
# ========================================

# Networking (VPC, Security Groups)
module "networking" {
  source = "./modules/networking"

  app_name                                  = var.app_name
  environment                               = var.environment
  aws_region                                = var.aws_region
  vpc_cidr                                  = var.vpc_cidr
  availability_zones                        = data.aws_availability_zones.available.names
  db_port                                   = local.db_port
  single_nat_gateway                        = var.single_nat_gateway
  enable_vpc_interface_endpoints            = var.enable_vpc_interface_endpoints
  enabled_vpc_interface_endpoints           = var.enabled_vpc_interface_endpoints
  rds_additional_ingress_cidrs              = var.rds_additional_ingress_cidrs
  rds_additional_ingress_security_group_ids = var.rds_additional_ingress_security_group_ids
  common_tags                               = local.common_tags
}

# SSL Certificates
module "certificates" {
  source = "./modules/certificates"

  app_name                   = var.app_name
  environment                = var.environment
  domain_name                = var.domain_name
  route53_zone_id            = local.route53_zone_id
  certificate_arn            = var.acm_certificate_arn
  vpn_server_certificate_arn = var.vpn_server_certificate_arn
  manage_route53_records     = var.manage_route53_dns
  wait_for_validation        = local.wait_for_acm_validation
  vanity_domains = [
    for vanity_domain in var.vanity_domains : {
      domain          = vanity_domain.domain
      certificate_arn = vanity_domain.certificate_arn
    }
  ]
  common_tags = local.common_tags
}

# Container Registry
module "container_registry" {
  source = "./modules/container_registry"

  app_name                       = var.app_name
  environment                    = var.environment
  enable_nightwatch_agent_mirror = var.enable_nightwatch_agent_mirror
  common_tags                    = local.common_tags
}

# SQS Message Queues
module "messaging" {
  source = "./modules/messaging"

  app_name        = var.app_name
  environment     = var.environment
  sqs_kms_key_arn = module.security.sqs_kms_key_arn
  common_tags     = local.common_tags
  queue_names     = var.queue_names
}

# Security (KMS, IAM) - create KMS keys first
module "security" {
  source = "./modules/security"

  app_name                    = var.app_name
  environment                 = var.environment
  aws_region                  = var.aws_region
  github_org                  = var.github_org
  github_repo                 = var.github_repo
  kms_deletion_window         = var.kms_deletion_window
  create_github_oidc_provider = var.environment == "staging" ? true : false
  common_tags                 = local.common_tags
  caller_identity_account_id  = data.aws_caller_identity.current.account_id
  enable_bedrock              = var.enable_bedrock
  bedrock_region              = var.bedrock_region
  dockerhub_username          = var.dockerhub_username
  dockerhub_access_token      = var.dockerhub_access_token
}

# Database (RDS / Aurora)
module "database" {
  source = "./modules/database"

  app_name                      = var.app_name
  environment                   = var.environment
  aws_region                    = var.aws_region
  vpc_id                        = module.networking.vpc_id
  private_subnets               = module.networking.private_subnets
  rds_security_group_id         = module.networking.rds_security_group_id
  db_engine                     = var.db_engine
  db_engine_version             = var.db_engine_version
  db_master_username            = var.db_master_username
  enable_postgres_audit         = var.enable_postgres_audit
  cloudwatch_log_retention_days = var.db_cloudwatch_log_retention_days
  db_instance_class             = var.db_instance_class
  db_allocated_storage          = var.db_allocated_storage
  db_max_allocated_storage      = var.db_max_allocated_storage
  rds_kms_key_arn               = module.security.rds_kms_key_arn
  multi_az                      = var.db_multi_az
  enable_performance_insights   = var.enable_performance_insights
  enable_deletion_protection    = var.enable_deletion_protection
  create_read_replica           = var.db_create_read_replica
  read_replica_instance_class   = var.db_read_replica_instance_class
  aurora_enable_serverlessv2    = var.aurora_enable_serverlessv2
  aurora_min_capacity           = var.aurora_min_capacity
  aurora_max_capacity           = var.aurora_max_capacity
  aurora_instance_count         = var.aurora_instance_count
  common_tags                   = local.common_tags
}

# Cache (Redis)
module "cache" {
  source = "./modules/cache"

  app_name                 = var.app_name
  environment              = var.environment
  private_subnets          = module.networking.private_subnets
  redis_security_group_id  = module.networking.redis_security_group_id
  redis_node_type          = var.redis_node_type
  redis_num_cache_clusters = var.redis_num_cache_nodes
  redis_engine_version     = var.redis_engine_version
  apply_immediately        = var.redis_apply_immediately
  common_tags              = local.common_tags
}

# Storage (S3 buckets)
module "storage" {
  source = "./modules/storage"

  app_name                   = var.app_name
  environment                = var.environment
  domain_name                = var.domain_name
  aws_region                 = var.aws_region
  caller_identity_account_id = data.aws_caller_identity.current.account_id
  s3_filesystem_kms_key_arn  = module.security.s3_filesystem_kms_key_arn
  certificate_arn            = module.certificates.certificate_arn
  enable_cloudfront          = var.enable_cloudfront && local.primary_certificate_ready
  common_tags                = local.common_tags
}

# Monitoring (CloudWatch, SNS, CloudTrail)
module "monitoring" {
  source = "./modules/monitoring"

  app_name                   = var.app_name
  environment                = var.environment
  aws_region                 = var.aws_region
  domain_name                = var.domain_name
  cloudtrail_bucket_name     = module.storage.cloudtrail_bucket_name
  caller_identity_account_id = data.aws_caller_identity.current.account_id
  healthcheck_alarm_emails   = var.healthcheck_alarm_emails
  enable_cloudtrail          = var.enable_cloudtrail
  cloudwatch_logs_kms_key_id = module.security.cloudwatch_logs_kms_key_arn
  log_retention_days         = var.log_retention_days
  common_tags                = local.common_tags
}

# Email (SES) - Optional
module "email" {
  count  = var.enable_ses ? 1 : 0
  source = "./modules/email"

  app_name                         = var.app_name
  environment                      = var.environment
  aws_region                       = var.aws_region
  caller_identity_account_id       = data.aws_caller_identity.current.account_id
  domain_name                      = var.domain_name
  route53_zone_id                  = local.route53_zone_id
  manage_route53_records           = var.manage_route53_dns
  test_email_addresses             = var.ses_test_emails
  test_email_domains               = var.ses_test_email_domains
  test_domain_route53_zone_id      = var.manage_route53_dns && length(var.ses_test_email_domains) > 0 ? data.aws_route53_zone.test_email_domain[0].zone_id : ""
  mail_from_subdomain              = var.ses_mail_from_subdomain
  mail_from_behavior_on_mx_failure = var.ses_mail_from_behavior_on_mx_failure
  enable_event_destination         = var.ses_enable_event_destination
  event_matching_types             = var.ses_event_matching_types
  event_notification_emails        = var.ses_event_notification_emails
  enable_account_suppression       = var.ses_enable_account_suppression
  suppressed_reasons               = var.ses_suppressed_reasons
  common_tags                      = local.common_tags
}

# Load Balancer (ALB, WAF)
module "load_balancer" {
  source = "./modules/load_balancer"

  app_name                           = var.app_name
  environment                        = var.environment
  aws_region                         = var.aws_region
  domain_name                        = var.domain_name
  vpc_id                             = module.networking.vpc_id
  public_subnets                     = module.networking.public_subnets
  alb_security_group_id              = module.networking.alb_security_group_id
  certificate_arn                    = module.certificates.certificate_arn
  enable_https_listener              = local.primary_certificate_ready
  alb_logs_bucket_name               = module.storage.alb_logs_bucket_name
  enable_access_logs                 = var.enable_alb_access_logs
  blocked_uri_patterns               = var.blocked_uri_patterns
  enable_bot_control                 = var.enable_bot_control
  bot_control_excluded_path_prefixes = var.bot_control_excluded_path_prefixes
  rate_limit_general                 = var.rate_limit_general
  rate_limit_livewire                = var.rate_limit_livewire
  rate_limit_excluded_path_prefixes  = var.rate_limit_excluded_path_prefixes
  rate_limit_excluded_exact_paths    = var.rate_limit_excluded_exact_paths
  health_check_path                  = var.alb_health_check_path
  enable_stickiness                  = var.enable_alb_stickiness
  ssl_policy                         = var.alb_ssl_policy
  enable_cloudfront_app              = var.enable_cloudfront_app
  cloudfront_app_aliases             = var.cloudfront_app_aliases
  cloudfront_app_certificate_arn     = var.cloudfront_app_certificate_arn
  cloudfront_app_price_class         = var.cloudfront_app_price_class
  cloudfront_web_acl_arn             = var.cloudfront_web_acl_arn
  vanity_domains = [
    for vanity_domain in var.vanity_domains : {
      domain          = vanity_domain.domain
      redirect_host   = vanity_domain.redirect_host
      redirect_path   = vanity_domain.redirect_path
      certificate_arn = vanity_domain.certificate_arn != "" ? vanity_domain.certificate_arn : module.certificates.vanity_domain_certificate_arns[vanity_domain.domain]
    }
    if local.wait_for_acm_validation || vanity_domain.certificate_arn != ""
  ]
  common_tags = local.common_tags
}

# Configuration (SSM parameters)
module "configuration" {
  source = "./modules/configuration"

  app_name                                = var.app_name
  app_key                                 = var.app_key
  environment                             = var.environment
  parameter_store_kms_key_id              = module.security.parameter_store_kms_key_id
  rds_endpoint                            = module.database.rds_endpoint
  rds_database_name                       = module.database.rds_database_name
  db_connection                           = local.db_connection
  db_port                                 = module.database.rds_port
  rds_username                            = module.database.rds_username
  app_db_username                         = var.app_db_username
  app_db_password                         = var.app_db_password
  rds_read_replica_endpoint               = module.database.rds_read_replica_endpoint != null ? module.database.rds_read_replica_endpoint : ""
  redis_auth_token                        = module.cache.redis_auth_token
  aws_region                              = var.aws_region
  aws_access_key_id                       = module.security.laravel_user_access_key_id
  aws_secret_access_key                   = module.security.laravel_user_secret_access_key
  additional_secret_environment_variables = var.additional_secret_environment_variables
  common_tags                             = local.common_tags
}

# Compute (ECS cluster, services)
module "compute" {
  source     = "./modules/compute"
  depends_on = [module.load_balancer, module.configuration]

  app_name                   = var.app_name
  environment                = var.environment
  aws_region                 = var.aws_region
  domain_name                = var.domain_name
  db_connection              = local.db_connection
  db_port                    = module.database.rds_port
  vpc_id                     = module.networking.vpc_id
  private_subnets            = module.networking.private_subnets
  ecs_security_group_id      = module.networking.ecs_security_group_id
  target_group_arn           = module.load_balancer.target_group_arn
  ecr_repository_url         = module.container_registry.repository_url
  image_tag                  = var.image_tag
  ecs_execution_role_arn     = module.security.ecs_execution_role_arn
  ecs_task_role_arn          = module.security.ecs_task_role_arn
  log_group_name             = module.monitoring.log_group_name
  s3_filesystem_bucket_name  = module.storage.app_filesystem_bucket_name
  cloudfront_domain          = var.cloudfront_domain
  sqs_suffix                 = module.messaging.sqs_suffix
  sqs_queue_names_csv        = module.messaging.queue_names_csv
  sqs_queue_full_names       = module.messaging.queue_full_names
  caller_identity_account_id = data.aws_caller_identity.current.account_id

  # Web service configuration
  container_cpu    = var.container_cpu
  container_memory = var.container_memory
  desired_count    = var.desired_count
  min_capacity     = var.min_capacity
  max_capacity     = var.max_capacity

  # Queue worker configuration
  queue_worker_cpu                = var.queue_worker_cpu
  queue_worker_memory             = var.queue_worker_memory
  queue_worker_desired_count      = var.queue_worker_desired_count
  queue_worker_min_capacity       = var.queue_worker_min_capacity
  queue_worker_max_capacity       = var.queue_worker_max_capacity
  queue_worker_target_age_seconds = var.queue_worker_target_age_seconds

  # Scheduler configuration
  scheduler_cpu           = var.scheduler_cpu
  scheduler_memory        = var.scheduler_memory
  scheduler_desired_count = var.scheduler_desired_count

  meilisearch_host                             = var.enable_meilisearch ? module.meilisearch[0].meilisearch_host : ""
  meilisearch_master_key                       = var.enable_meilisearch ? var.meilisearch_master_key : ""
  redis_endpoint                               = module.cache.redis_endpoint
  redis_port                                   = module.cache.redis_port
  ses_configuration_set_name                   = var.enable_ses ? module.email[0].ses_configuration_set_name : ""
  mail_from_name                               = coalesce(var.mail_from_name, var.app_name)
  enable_container_insights                    = var.enable_container_insights
  off_hours_min_capacity                       = var.off_hours_min_capacity
  app_server_mode                              = var.app_server_mode
  additional_environment_variables             = var.additional_environment_variables
  additional_secret_environment_variable_names = nonsensitive([for secret in var.additional_secret_environment_variables : secret.name])

  # Nightwatch configuration
  enable_nightwatch                = var.enable_nightwatch
  nightwatch_token                 = var.nightwatch_token
  nightwatch_request_sample_rate   = var.nightwatch_request_sample_rate
  nightwatch_command_sample_rate   = var.nightwatch_command_sample_rate
  nightwatch_exception_sample_rate = var.nightwatch_exception_sample_rate
  nightwatch_agent_image           = var.nightwatch_agent_image
  nightwatch_agent_cpu             = var.nightwatch_agent_cpu
  nightwatch_agent_memory          = var.nightwatch_agent_memory
  dockerhub_credentials_secret_arn = module.security.dockerhub_credentials_secret_arn

  # Scheduled scaling configuration
  enable_scheduled_scaling    = var.enable_scheduled_scaling
  scale_down_schedule         = var.scale_down_schedule
  scale_up_schedule           = var.scale_up_schedule
  weekend_scale_down_schedule = var.weekend_scale_down_schedule

  common_tags = local.common_tags
}

# DNS (Route53 records)
module "dns" {
  count  = var.manage_route53_dns ? 1 : 0
  source = "./modules/dns"

  app_name                      = var.app_name
  environment                   = var.environment
  domain_name                   = var.domain_name
  route53_zone_id               = local.route53_zone_id
  alb_dns_name                  = module.load_balancer.alb_dns_name
  alb_zone_id                   = module.load_balancer.alb_zone_id
  cloudfront_app_enabled        = var.enable_cloudfront_app
  cloudfront_app_domain_name    = module.load_balancer.app_cloudfront_distribution_domain
  cloudfront_app_hosted_zone_id = module.load_balancer.app_cloudfront_distribution_hosted_zone_id
  dmarc_record                  = var.dmarc_record
  common_tags                   = local.common_tags
}

# Meilisearch (Search Engine) - Optional
module "meilisearch" {
  count  = var.enable_meilisearch ? 1 : 0
  source = "./modules/meilisearch"

  app_name               = var.app_name
  environment            = var.environment
  vpc_id                 = module.networking.vpc_id
  vpc_cidr_block         = module.networking.vpc_cidr_block
  private_subnets        = module.networking.private_subnets
  ecs_cluster_id         = module.compute.cluster_id
  ecs_execution_role_arn = module.security.ecs_execution_role_arn
  ecs_task_role_arn      = module.security.ecs_task_role_arn
  log_group_name         = module.monitoring.log_group_name
  aws_region             = var.aws_region
  meilisearch_master_key = var.meilisearch_master_key
  common_tags            = local.common_tags
}

# Bastion (conditional module)
module "bastion" {
  count  = var.enable_bastion ? 1 : 0
  source = "./modules/bastion"

  app_name            = var.app_name
  environment         = var.environment
  vpc_id              = module.networking.vpc_id
  subnet_id           = module.networking.public_subnets[0]
  key_name            = var.ec2_key_name
  instance_type       = var.bastion_instance_type
  allowed_cidr_blocks = length(var.bastion_allowed_ips) > 0 ? var.bastion_allowed_ips : []

  # Database configuration for user setup
  rds_endpoint                   = module.database.rds_endpoint
  rds_master_username            = module.database.rds_username
  rds_master_password_secret_arn = module.database.rds_secret_arn
  rds_kms_key_arn                = module.security.rds_kms_key_arn
  rds_database_name              = module.database.rds_database_name
  app_db_username                = var.app_db_username
  app_db_password                = var.app_db_password
  db_read_only_password          = var.db_read_only_password
  aws_region                     = var.aws_region
  db_engine                      = var.db_engine
  db_port                        = local.db_port
  enable_database_bootstrap      = var.enable_bastion_database_bootstrap
  enable_scheduled_stop          = var.enable_bastion_scheduled_stop
  stop_schedule                  = var.bastion_stop_schedule
  start_schedule                 = var.bastion_start_schedule
  schedule_timezone              = var.bastion_schedule_timezone

  tags = local.common_tags
}

# Allow bastion to access RDS (for user setup script)
resource "aws_security_group_rule" "bastion_to_rds" {
  count                    = var.enable_bastion ? 1 : 0
  type                     = "ingress"
  from_port                = module.database.rds_port
  to_port                  = module.database.rds_port
  protocol                 = "tcp"
  source_security_group_id = module.bastion[0].security_group_id
  security_group_id        = module.networking.rds_security_group_id
  description              = "Allow database access from bastion host"
}

# Client VPN - Optional
module "client_vpn" {
  count  = var.enable_client_vpn && local.vpn_certificate_ready ? 1 : 0
  source = "./modules/client_vpn"

  name                           = "${var.app_name}-${var.environment}-vpn"
  description                    = "Client VPN endpoint for ${var.app_name} ${var.environment}"
  server_certificate_arn         = module.certificates.vpn_server_certificate_arn
  client_cidr_block              = var.vpn_client_cidr_block
  dns_servers                    = var.vpn_dns_servers
  split_tunnel                   = var.vpn_split_tunnel
  saml_provider_arn              = var.vpn_saml_provider_arn
  self_service_saml_provider_arn = var.vpn_saml_provider_arn
  connection_log_enabled         = var.vpn_connection_log_enabled
  cloudwatch_log_group           = var.vpn_connection_log_enabled ? var.vpn_cloudwatch_log_group : null
  cloudwatch_log_stream          = var.vpn_connection_log_enabled ? var.vpn_cloudwatch_log_stream : null
  cloudwatch_logs_kms_key_id     = module.security.cloudwatch_logs_kms_key_arn
  login_banner_enabled           = var.vpn_login_banner_enabled
  login_banner_text              = var.vpn_login_banner_text
  vpc_id                         = module.networking.vpc_id
  vpc_cidr                       = var.vpc_cidr
  security_group_ids             = [module.networking.vpn_security_group_id]
  target_subnet_id               = module.networking.private_subnets[1]
  additional_authorized_cidrs    = var.vpn_additional_authorized_cidrs
  common_tags                    = local.common_tags
}

# SMS - Optional (AWS End User Messaging SMS / Pinpoint SMS Voice v2)
module "sms" {
  count  = var.enable_sms ? 1 : 0
  source = "./modules/sms"

  app_name                                  = var.app_name
  environment                               = var.environment
  aws_region                                = var.aws_region
  domain_name                               = var.domain_name
  webhook_path                              = var.aws_sms_webhook_path
  phone_number_id                           = var.aws_sms_phone_number_id
  configuration_set_name                    = var.aws_sms_configuration_set_name
  default_message_type                      = var.aws_sms_default_message_type
  subscription_confirmation_timeout_minutes = var.aws_sms_subscription_confirmation_timeout_minutes
  caller_identity_account_id                = data.aws_caller_identity.current.account_id
  common_tags                               = local.common_tags
}

# Compliance and Auditing
module "compliance" {
  source = "./modules/compliance"

  app_name                   = var.app_name
  environment                = var.environment
  aws_region                 = var.aws_region
  caller_identity_account_id = data.aws_caller_identity.current.account_id
  vpc_id                     = module.networking.vpc_id
  vpc_flow_logs_bucket_arn   = module.storage.vpc_flow_logs_bucket_arn
  config_bucket_name         = module.storage.config_bucket_name
  common_tags                = local.common_tags

  # AWS Config
  enable_aws_config  = var.enable_aws_config
  enable_hipaa_rules = var.enable_hipaa_rules

  # Security Hub
  enable_security_hub              = var.enable_security_hub
  enable_cis_standard              = var.enable_cis_standard
  enable_pci_dss_standard          = var.enable_pci_dss_standard
  enable_aws_foundational_standard = var.enable_aws_foundational_standard
  security_hub_notification_emails = var.security_hub_notification_emails

  # GuardDuty
  enable_guardduty              = var.enable_guardduty
  guardduty_finding_frequency   = var.guardduty_finding_frequency
  guardduty_notification_emails = var.guardduty_notification_emails

  # Macie (production only)
  enable_macie            = var.enable_macie
  macie_finding_frequency = var.macie_finding_frequency
  macie_s3_buckets = var.enable_macie && var.environment == "production" ? [
    module.storage.app_filesystem_bucket_name,
    module.storage.alb_logs_bucket_name,
    module.storage.cloudtrail_bucket_name
  ] : []
  macie_findings_bucket_name = var.enable_macie && var.environment == "production" ? module.storage.macie_findings_bucket_name : ""
  s3_filesystem_kms_key_arn  = module.security.s3_filesystem_kms_key_arn

  # Access Analyzer (production only)
  enable_access_analyzer = var.enable_access_analyzer

  # Backup Audit Manager (production only)
  enable_backup_audit_manager = var.enable_backup_audit_manager
  enable_hipaa_framework      = var.enable_hipaa_framework
  backup_vault_arn            = var.backup_vault_arn
  backup_kms_key_arn          = module.security.backup_kms_key_arn

  # VPC Flow Logs
  enable_vpc_flow_logs     = var.enable_vpc_flow_logs
  flow_logs_retention_days = var.flow_logs_retention_days
  flow_logs_traffic_type   = var.flow_logs_traffic_type
}
