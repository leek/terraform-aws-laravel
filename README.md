> [!WARNING]
> This Terraform configuration provisions real AWS infrastructure that may incur significant costs depending on your usage and configuration. **Use at your own risk** - you are solely responsible for reviewing, understanding, and monitoring any resources and charges created by this code. Always test in a non-production environment and review the Terraform plan carefully before applying changes.

# Laravel AWS Infrastructure with Terraform

Production-ready AWS infrastructure for Laravel applications using Terraform. This configuration deploys a complete, scalable infrastructure on AWS with best practices for security, monitoring, high availability, and compliance.

## What Makes This Different

This isn't just another Laravel deployment template - it's a **production-grade, compliance-ready** infrastructure with:

- **Healthcare/HIPAA Ready**: Full compliance suite with AWS Config, Security Hub, GuardDuty, Macie, and VPC Flow Logs
- **Blazing Fast Containers**: PHP 8.4 + optimized multi-stage Docker builds with 2-5 second startup times
- **Cost Optimized**: Scheduled scaling to reduce staging costs by 50-70% during off-hours
- **Zero-Downtime Octane**: Pre-installed Swoole, RoadRunner, and FrankenPHP - switch modes without rebuilding
- **Enterprise Security**: CIS, PCI-DSS, and AWS Foundational standards with automated threat detection
- **Production Proven**: Battle-tested patterns for high-traffic Laravel applications

## Features

### Core Infrastructure
- **ECS Fargate** - Containerized Laravel application with auto-scaling
  - Web service (handles HTTP traffic via ALB)
  - Queue worker service (processes SQS queue jobs)
  - Scheduler service (runs Laravel task scheduler)
- **RDS MySQL** - Managed database with automated backups
- **ElastiCache Redis** - Session and cache storage (single-node configuration)
- **Application Load Balancer** - HTTPS traffic routing with AWS WAF
- **S3** - File storage for Laravel filesystem
- **SQS** - Queue management for Laravel jobs
- **CloudWatch** - Centralized logging and monitoring
- **Route53** - DNS management and health checks

### Optional Features
- **Meilisearch** - Fast, typo-tolerant search engine (optional)
- **AWS SES** - Email sending capability (optional)
- **Laravel Nightwatch** - Production monitoring and performance insights (optional)
- **Client VPN** - Secure remote access to VPC (optional)
- **Bastion Host** - Secure database access (optional)
- **CloudTrail** - API audit logging (optional)
- **Read Replicas** - Database read replicas for analytics (optional)
- **Scheduled Scaling** - Automatic scale down during nights and weekends for cost savings (optional)

### Compliance & Security Features
- **AWS Config** - Resource configuration tracking and compliance rules (including HIPAA)
- **AWS Security Hub** - Centralized security findings with CIS, PCI-DSS, and AWS Foundational standards
- **AWS GuardDuty** - Intelligent threat detection and continuous monitoring
- **AWS Macie** - PHI/PII detection in S3 buckets (production only)
- **IAM Access Analyzer** - Identifies resources shared with external entities (production only)
- **AWS Backup Audit Manager** - Backup compliance auditing with HIPAA framework (production only)
- **VPC Flow Logs** - Network traffic logging (required for HIPAA compliance)

### Security
- **KMS encryption** - All data encrypted at rest
- **VPC isolation** - Private subnets for application and database
- **IAM roles** - Least-privilege access controls
- **Security groups** - Network-level firewalling
- **SSL/TLS** - HTTPS everywhere with ACM certificates (includes VPN server certificates)



## Architecture

The infrastructure deploys three separate ECS services:
1. **Web Service** - Handles HTTP/HTTPS traffic through the ALB (auto-scales based on traffic)
2. **Queue Worker Service** - Processes Laravel queue jobs from SQS (always runs 1 task)
3. **Scheduler Service** - Runs Laravel's task scheduler (`php artisan schedule:work`) (always runs 1 task)

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└───────────────────────────┬─────────────────────────────────┘
                            │
                  ┌─────────▼──────────┐
                  │   Route53 + ACM    │
                  └─────────┬──────────┘
                            │
         ┌──────────────────▼───────────────────┐
         │  Application Load Balancer (+ WAF)   │
         └──────────────────┬───────────────────┘
                            │
    ┌───────────────────────┴────────────────────────────┐
    │              ECS Fargate Cluster                   │
    │  ┌────────────┐  ┌──────────┐  ┌──────────┐       │
    │  │  Web       │  │ Queue    │  │Scheduler │       │
    │  │ Service    │  │ Worker   │  │ Service  │       │
    │  │(Auto-scale)│  │ Service  │  │ (1 task) │       │
    │  └────────────┘  └──────────┘  └──────────┘       │
    └───────┬──────────────┬──────────────┬──────────────┘
            │              │              │
    ┌───────▼────────┐  ┌──▼──────────┐  │
    │ ElastiCache    │  │  RDS MySQL  │  │
    │ Redis          │  │ (+ Replica) │  │
    └────────────────┘  └─────────────┘  │
            │                 │           │
            │           ┌─────▼──────┐    │
            │           │  Bastion   │    │
            │           └────────────┘    │
            │                             │
    ┌───────▼─────────────────────────────▼──────┐
    │  S3 (Filesystem) + SQS (Queues)            │
    └────────────────────────────────────────────┘
```

## Docker Architecture

The included Docker setup is highly optimized for production deployments with support for multiple application server modes.

### Multi-Stage Build

The Dockerfile uses a sophisticated 3-stage build process:

1. **Binaries Stage** - Downloads and prepares Octane binaries (RoadRunner, FrankenPHP)
2. **Builder Stage** - Installs dependencies and builds frontend assets with BuildKit cache mounts
3. **Production Stage** - Creates minimal runtime image with all necessary components

### Key Features

**PHP 8.4 on Alpine Linux:**
- Latest PHP features and performance improvements
- Minimal base image (~80MB vs 400MB+ for Debian-based images)
- Security updates and patches included

**Build-Time Optimization:**
- Laravel artifacts cached during build (events, routes, views, icons, Filament components)
- Composer and NPM dependencies use BuildKit cache mounts for faster rebuilds
- Frontend assets built once and included in the image
- Memory-optimized build process with `-d memory_limit=-1`

**Runtime Flexibility:**
- All Octane servers pre-installed (Swoole, RoadRunner, FrankenPHP)
- Switch between PHP-FPM and Octane modes without rebuilding
- Intelligent entrypoint script selects the correct configuration
- Separate supervisor configs for each mode

**Performance Benefits:**
- Container startup: 2-5 seconds (vs 20-30 seconds traditional)
- Image size: 30-40% smaller than traditional builds
- No cold start delays for Laravel framework
- Config cache is the only runtime cache operation needed

### Container Roles

A single Docker image serves three different roles via the `CONTAINER_ROLE` environment variable:

- **web** - Runs Nginx + PHP-FPM or Octane (based on `APP_SERVER_MODE`)
- **queue-worker** - Processes Laravel queue jobs with `php artisan queue:work`
- **scheduler** - Runs Laravel's task scheduler with `php artisan schedule:work`

This approach ensures consistency across all services while using the same codebase.

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0
3. **AWS CLI** configured with credentials
4. **Domain name** registered (can be managed elsewhere)
5. **Laravel application** with PHP 8.4+ ready to containerize
6. **Docker** with BuildKit enabled (for multi-stage builds)

## Quick Start

### 1. Clone and Configure

```bash
# Navigate to terraform directory
cd terraform

# Copy example configuration
cp environments/example.tfvars environments/production.tfvars

# Edit with your values
vim environments/production.tfvars
```

### 2. Required Configuration

Edit `production.tfvars` and set these required values:

```hcl
environment = "production"
domain_name = "yourdomain.com"
app_key     = "base64:YOUR_APP_KEY_HERE"
github_org  = "your-org"
github_repo = "your-repo"

# Database credentials (use strong random passwords)
app_db_password       = "STRONG_RANDOM_PASSWORD"
db_reporting_password = "STRONG_RANDOM_PASSWORD"
```

### 3. Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Create workspace (if using workspaces)
terraform workspace new production

# Review the plan
terraform plan -var-file="environments/production.tfvars"

# Deploy infrastructure
terraform apply -var-file="environments/production.tfvars"
```

**Workspace Validation:**
The Terraform configuration includes built-in workspace validation to prevent accidental deployments. The workspace name must match your environment variable:
- If `environment = "production"`, you must be in the `production` workspace
- If `environment = "staging"`, you must be in the `staging` workspace
- This prevents deploying production config to staging or vice versa

### 4. Deploy Your Application

After infrastructure is created:

```bash
# Build and push your Docker image (uses optimized multi-stage build)
docker build -f docker/Dockerfile -t myapp .
aws ecr get-login-password | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url)
docker tag myapp:latest $(terraform output -raw ecr_repository_url):latest
docker push $(terraform output -raw ecr_repository_url):latest

# Force new ECS deployment (updates all three services: web, queue-worker, scheduler)
CLUSTER=$(terraform output -raw ecs_cluster_name)
aws ecs update-service --cluster $CLUSTER --service $(terraform output -raw ecs_service_name) --force-new-deployment
aws ecs update-service --cluster $CLUSTER --service $(terraform output -raw ecs_queue_worker_service_name) --force-new-deployment
aws ecs update-service --cluster $CLUSTER --service $(terraform output -raw ecs_scheduler_service_name) --force-new-deployment
```

**Docker Build Performance:**
The included Dockerfile uses an optimized multi-stage build that:
- Caches Laravel artifacts at build time (events, routes, views, icons, Filament components)
- Pre-installs all Octane binaries (Swoole, RoadRunner, FrankenPHP) for instant switching
- Uses BuildKit cache mounts for Composer and NPM dependencies
- Runs on PHP 8.4 Alpine Linux for minimal image size
- Significantly reduces container startup time (typically 2-5 seconds vs 20-30 seconds)
- Reduces image size by 30-40% compared to traditional builds

## Configuration Guide

### Application Server Mode

Choose between **PHP-FPM** (default) or **Laravel Octane** with your preferred driver:

```hcl
# Traditional PHP-FPM with Nginx (default, most compatible)
app_server_mode = "php-fpm"

# Laravel Octane with Swoole (battle-tested, excellent performance)
app_server_mode = "octane-swoole"

# Laravel Octane with RoadRunner (Go-based, great for long-running tasks)
app_server_mode = "octane-roadrunner"

# Laravel Octane with FrankenPHP (modern, includes Early Hints support)
app_server_mode = "octane-frankenphp"
```

**Octane Driver Comparison:**
- **Swoole**: Battle-tested, excellent performance, requires Swoole PHP extension
- **RoadRunner**: Go-based server, great for long-running tasks, excellent stability
- **FrankenPHP**: Modern PHP app server built on Caddy, supports Early Hints and modern HTTP features

**Laravel Octane Benefits:**
- 2-5x better request throughput
- Lower latency for API responses
- Reduced memory usage per request
- Better for high-traffic applications

> [!IMPORTANT]
> Ensure your Laravel application is installed with the Octane package and is compatible with Octane (no global state, stateless services). See [Laravel Octane documentation](https://laravel.com/docs/octane) for details.

### Minimal Configuration

For a basic setup (good for staging/development):

```hcl
environment = "staging"
domain_name = "staging.example.com"
app_key     = "base64:..."
github_org  = "your-org"
github_repo = "your-repo"

app_db_password       = "..."
db_reporting_password = "..."

# Application server mode
app_server_mode      = "php-fpm"  # or "octane-swoole", "octane-roadrunner", or "octane-frankenphp" for better performance

# Small instance sizes
container_cpu        = 512
container_memory     = 1024
desired_count        = 1
min_capacity         = 1
max_capacity         = 4

db_instance_class    = "db.t3.micro"
redis_node_type      = "cache.t3.micro"

# Enable scheduled scaling for cost savings
enable_scheduled_scaling = true

# Disable optional features
enable_meilisearch   = false
enable_ses           = false
enable_client_vpn    = false
enable_bastion       = false
enable_cloudtrail    = false

# Basic compliance (recommended)
enable_aws_config    = true
enable_security_hub  = true
enable_guardduty     = true
enable_vpc_flow_logs = true

# Disable production-only compliance features
enable_macie               = false
enable_access_analyzer     = false
enable_backup_audit_manager = false
```

> [!NOTE]
> **Estimated cost**: ~$50-100/month (infrastructure) + ~$30-50/month (compliance)

### Production Configuration

For production with high availability and full compliance:

```hcl
environment = "production"
domain_name = "example.com"
app_key     = "base64:..."
github_org  = "your-org"
github_repo = "your-repo"

app_db_password       = "..."
db_reporting_password = "..."

# Use Laravel Octane for better performance in production (choose your preferred driver)
app_server_mode      = "octane-swoole"  # or "octane-roadrunner" or "octane-frankenphp"

# Larger instance sizes
container_cpu        = 2048
container_memory     = 4096
desired_count        = 3
min_capacity         = 2
max_capacity         = 10

# Production database settings
db_instance_class            = "db.t3.large"
db_allocated_storage         = 100
db_max_allocated_storage     = 1000
db_multi_az                  = true
enable_performance_insights  = true
enable_deletion_protection   = true
db_create_read_replica       = true

# Production Redis (note: currently single-node only)
redis_node_type = "cache.t3.medium"

# Enable production features
enable_cloudtrail       = true
enable_alb_access_logs  = true
log_retention_days      = 30

healthcheck_alarm_emails = ["ops@example.com"]

# Full compliance suite for production
enable_aws_config              = true
enable_hipaa_rules             = true
enable_security_hub            = true
enable_cis_standard            = true
enable_aws_foundational_standard = true
enable_guardduty               = true
enable_vpc_flow_logs           = true
flow_logs_retention_days       = 90

# Production-only compliance features
enable_macie                   = true
enable_access_analyzer         = true
enable_backup_audit_manager    = true

# Compliance notifications
security_hub_notification_emails = ["security@example.com"]
guardduty_notification_emails    = ["security@example.com"]
```

> [!NOTE]
> **Estimated cost**: ~$300-500/month (infrastructure) + ~$100-200/month (compliance)

## Switching Between PHP-FPM and Octane

You can switch between PHP-FPM and Laravel Octane (with any driver) at any time by updating your Terraform configuration:

### Prerequisites for Octane

Before switching to Octane, ensure your Laravel application:

1. **Has Laravel Octane installed:**
   ```bash
   composer require laravel/octane
   
   # Install your preferred server
   php artisan octane:install --server=swoole      # For Swoole
   php artisan octane:install --server=roadrunner  # For RoadRunner
   php artisan octane:install --server=frankenphp  # For FrankenPHP
   ```

2. **Is Octane-compatible:**
   - No reliance on global state or static variables
   - Uses dependency injection properly
   - Stateless service classes
   - See [Laravel Octane documentation](https://laravel.com/docs/octane#introduction) for details

### Switching to Octane

1. Update your `.tfvars` file with your preferred driver:
   ```hcl
   app_server_mode = "octane-swoole"       # Most battle-tested
   # OR
   app_server_mode = "octane-roadrunner"   # Great for long-running tasks
   # OR
   app_server_mode = "octane-frankenphp"   # Modern with Early Hints support
   ```

2. Apply the Terraform changes:
   ```bash
   terraform apply -var-file="environments/production.tfvars"
   ```

3. Deploy your updated Docker image (with Octane installed) and force a new ECS deployment:
   ```bash
   # The new tasks will automatically start with your chosen Octane driver
   aws ecs update-service --cluster $CLUSTER --service $(terraform output -raw ecs_service_name) --force-new-deployment
   ```

### Switching Back to PHP-FPM

If you need to revert to PHP-FPM:

1. Update your `.tfvars` file:
   ```hcl
   app_server_mode = "php-fpm"
   ```

2. Apply the Terraform changes and redeploy:
   ```bash
   terraform apply -var-file="environments/production.tfvars"
   aws ecs update-service --cluster $CLUSTER --service $(terraform output -raw ecs_service_name) --force-new-deployment
   ```

### Testing Your Configuration

Test Octane locally before deploying to production:

```bash
# Build the Docker image
docker build -f docker/Dockerfile -t myapp .

# Generate an APP_KEY first (use an existing Laravel project or Docker)
# Option 1: From your Laravel project directory
APP_KEY=$(php artisan key:generate --show)

# Option 2: Or generate inside a temporary container
APP_KEY=$(docker run --rm myapp php artisan key:generate --show)

# Run with Octane Swoole
docker run -p 8080:80 \
  -e APP_ENV=local \
  -e CONTAINER_ROLE=web \
  -e APP_SERVER_MODE=octane-swoole \
  -e APP_KEY=$APP_KEY \
  myapp

# Or run with Octane RoadRunner
docker run -p 8080:80 \
  -e APP_ENV=local \
  -e CONTAINER_ROLE=web \
  -e APP_SERVER_MODE=octane-roadrunner \
  -e APP_KEY=$APP_KEY \
  myapp

# Or run with Octane FrankenPHP
docker run -p 8080:80 \
  -e APP_ENV=local \
  -e CONTAINER_ROLE=web \
  -e APP_SERVER_MODE=octane-frankenphp \
  -e APP_KEY=$APP_KEY \
  myapp

# Test in browser or with curl
curl http://localhost:8080

# Test queue worker role
docker run \
  -e CONTAINER_ROLE=queue-worker \
  -e APP_KEY=$APP_KEY \
  myapp

# Test scheduler role
docker run \
  -e CONTAINER_ROLE=scheduler \
  -e APP_KEY=$APP_KEY \
  myapp
```

> [!TIP]
> All Octane binaries are pre-installed in the image, so switching between modes is instant - no rebuild required!

## Optional Features

### Enable Meilisearch (Search Engine)

```hcl
enable_meilisearch     = true
meilisearch_master_key = "YOUR_RANDOM_32_CHAR_KEY"
```

Laravel configuration:
```env
SCOUT_DRIVER=meilisearch
MEILISEARCH_HOST=http://meilisearch:7700
MEILISEARCH_KEY=YOUR_RANDOM_32_CHAR_KEY
```

### Enable AWS SES (Email)

```hcl
enable_ses      = true
ses_test_emails = ["test@example.com"]  # Required in sandbox mode
```

Laravel configuration:
```env
MAIL_MAILER=ses
MAIL_FROM_ADDRESS=noreply@yourdomain.com
```

### Enable Laravel Nightwatch (Monitoring)

```hcl
enable_nightwatch  = true
nightwatch_token   = "your-token-from-nightwatch.laravel.com"

# Optional: Adjust sample rates to control costs and overhead
nightwatch_request_sample_rate   = 0.1  # 10% of requests
nightwatch_command_sample_rate   = 1.0  # 100% of commands
nightwatch_exception_sample_rate = 1.0  # 100% of exceptions
```

**How it works:**
- Nightwatch runs as a sidecar container alongside your Laravel application
- The agent is added to all three services: web, queue worker, and scheduler
- Your Laravel app communicates with the agent via localhost on port 2407
- A secure random token is automatically generated for communication

**Prerequisites:**
1. Sign up at [nightwatch.laravel.com](https://nightwatch.laravel.com)
2. Install the Nightwatch package in your Laravel application:
   ```bash
   composer require laravel/nightwatch
   ```
3. Minimum version: `laravel/nightwatch` v1.11.0 or later

**Notes:**
- The agent is marked as `essential = false`, so your app will continue running if the agent fails
- Agent logs are available in CloudWatch under the `nightwatch` stream prefix
- Sample rates help reduce costs in high-traffic applications while still capturing important events

### Enable Client VPN

```hcl
enable_client_vpn     = true
vpn_client_cidr_block = "10.4.0.0/22"
vpn_saml_provider_arn = "arn:aws:iam::ACCOUNT:saml-provider/YourProvider"
```

Provides secure remote access to your VPC for development and debugging.

> [!NOTE]
> VPN server certificates are automatically provisioned for all environments via ACM (even if Client VPN is disabled). This allows you to enable VPN later without additional certificate setup.

### Enable Bastion Host

```hcl
enable_bastion        = true
ec2_key_name          = "my-key-pair"
bastion_allowed_ips   = ["203.0.113.0/32"]  # Your office IP
```

Provides secure SSH access to your database:
```bash
ssh -i ~/.ssh/my-key.pem ec2-user@bastion-ip
mysql -h rds-endpoint -u app_user -p
```

### Enable Read Replica

```hcl
db_create_read_replica       = true
db_read_replica_instance_class = "db.t3.large"
```

Laravel will automatically use the read replica for read queries when configured with `DB_READ_HOST`.

## Compliance & Auditing

This infrastructure includes comprehensive compliance and security monitoring capabilities, ideal for healthcare, financial services, and other regulated industries.

### AWS Config (Resource Compliance Tracking)

Enable AWS Config to track all resource configuration changes and enforce compliance rules:

```hcl
enable_aws_config  = true
enable_hipaa_rules = true  # Enable HIPAA-specific compliance rules
```

**Features:**
- Tracks configuration changes for all resources
- Evaluates resources against compliance rules
- Provides compliance dashboard and history
- Includes HIPAA-specific rules when enabled
- **Note:** Config Recorder is account-level (only created in production to avoid conflicts)

**HIPAA Rules Include:**
- Encrypted volumes and RDS instances
- S3 bucket encryption and versioning
- CloudTrail and VPC Flow Logs enabled
- And many more...

### AWS Security Hub (Centralized Security Dashboard)

Security Hub aggregates security findings from multiple AWS services:

```hcl
enable_security_hub              = true
enable_cis_standard              = true  # CIS AWS Foundations Benchmark
enable_aws_foundational_standard = true  # AWS Foundational Security Best Practices
enable_pci_dss_standard          = false # Enable if handling payment cards

# Email notifications for critical/high findings
security_hub_notification_emails = ["security@example.com"]
```

**Compliance Standards:**
- **CIS AWS Foundations Benchmark**: Industry-standard security baseline
- **AWS Foundational Security Best Practices**: AWS-recommended security controls
- **PCI DSS**: Payment Card Industry Data Security Standard (optional)

### AWS GuardDuty (Threat Detection)

Intelligent threat detection using machine learning:

```hcl
enable_guardduty            = true
guardduty_finding_frequency = "FIFTEEN_MINUTES"  # or ONE_HOUR, SIX_HOURS

# Email notifications for threats
guardduty_notification_emails = ["security@example.com"]
```

**Detects:**
- Compromised instances
- Reconnaissance activity
- Unauthorized API calls
- Malicious IP communications
- Cryptocurrency mining

### AWS Macie (PHI/PII Detection - Production Only)

Automatically scans S3 buckets for sensitive data:

```hcl
enable_macie            = true  # Production only
macie_finding_frequency = "ONE_HOUR"
```

**Capabilities:**
- Discovers and classifies PHI/PII in S3
- Monitors S3 for sensitive data exposure
- Generates detailed findings reports
- Scans application filesystem, ALB logs, and CloudTrail buckets
- **Note:** Only available in production environment due to cost

### VPC Flow Logs (Network Traffic Logging)

Required for HIPAA compliance and network forensics:

```hcl
enable_vpc_flow_logs     = true
flow_logs_retention_days = 90     # Minimum 90 days recommended
flow_logs_traffic_type   = "ALL"  # Log all traffic (ACCEPT, REJECT, ALL)
```

**Features:**
- Logs stored in S3 in Parquet format
- Hive-compatible partitions for analytics
- Hourly partitioning for efficient queries
- Useful for security investigations and compliance

### IAM Access Analyzer (Production Only)

Identifies resources shared with external entities:

```hcl
enable_access_analyzer = true  # Production only
```

**Analyzes:**
- S3 buckets with external access
- IAM roles assumable by external accounts
- KMS keys with external permissions
- Lambda functions with cross-account access

### AWS Backup Audit Manager (Production Only)

Audits backup compliance for disaster recovery requirements:

```hcl
enable_backup_audit_manager = true  # Production only
enable_hipaa_framework      = true
backup_vault_arn            = "arn:aws:backup:region:account:backup-vault:vault-name"
```

**Frameworks:**
- HIPAA backup compliance framework
- Validates backup policies meet requirements
- Generates audit reports

### Compliance Dashboard

After enabling these services, view your compliance posture:

```bash
# View Security Hub findings
aws securityhub get-findings --filters '{"SeverityLabel":[{"Value":"CRITICAL","Comparison":"EQUALS"}]}'

# View AWS Config compliance
aws configservice describe-compliance-by-config-rule

# View GuardDuty findings
aws guardduty list-findings --detector-id <detector-id>

# View Macie findings (if enabled)
aws macie2 list-findings
```

### Compliance Cost Optimization

**For Staging/Development:**
- Enable: Config, Security Hub, GuardDuty, VPC Flow Logs
- Disable: Macie, Access Analyzer, Backup Audit Manager
- Estimated additional cost: ~$30-50/month

**For Production:**
- Enable all compliance features for maximum security and auditability
- Estimated additional cost: ~$100-200/month (varies by data volume)

## Database Users

Three database users are automatically configured:

1. **Master User** (`admin`)
   - Full administrative access
   - Credentials stored in AWS Secrets Manager
   - Used only for infrastructure management

2. **Application User** (`app_user` by default)
   - CRUD operations + migrations
   - Used by Laravel application
   - Created automatically by bastion host

3. **Reporting User** (`reporting`)
   - Read-only access
   - For BI tools and analytics
   - Safe for external reporting tools

## Monitoring & Alerts

### Health Checks

Route53 health checks monitor your application endpoint (`/up`) every 30 seconds:

```hcl
healthcheck_alarm_emails = ["ops@example.com", "team@example.com"]
```

You'll receive email alerts when the application goes down.

### CloudWatch Logs

All application logs are stored in CloudWatch Logs:

```bash
# View recent logs
aws logs tail /ecs/laravel-app-production --follow

# Search logs
aws logs filter-log-events \
  --log-group-name /ecs/laravel-app-production \
  --filter-pattern "ERROR"
```

### CloudTrail (Optional)

Enable API audit logging:

```hcl
enable_cloudtrail = true
```

All AWS API calls are logged to S3 for security auditing.

## Scaling

### Horizontal Scaling (ECS Tasks)

Configure auto-scaling based on CPU and memory:

```hcl
desired_count = 3   # Normal load
min_capacity  = 2   # Minimum tasks
max_capacity  = 10  # Maximum tasks
```

Tasks auto-scale when CPU > 70% or Memory > 80%.

### Scheduled Scaling (Cost Optimization)

Save costs by automatically scaling down during off-hours (recommended for staging/development):

```hcl
enable_scheduled_scaling = true

# Weekday evening scale down (6 PM EST = 11 PM UTC)
scale_down_schedule = "cron(0 23 ? * MON-FRI *)"

# Weekday morning scale up (8 AM EST = 12 PM UTC)
scale_up_schedule = "cron(0 12 ? * MON-FRI *)"

# Weekend scale down (Saturday 12 AM EST = 5 AM UTC)
weekend_scale_down_schedule = "cron(0 5 ? * SAT *)"
```

**Benefits:**
- Scales ECS tasks down to minimum (1) during nights and weekends
- Can reduce staging environment costs by 50-70%
- Automatically scales back up during business hours
- Fully configurable with cron expressions

### Vertical Scaling (Task Size)

Adjust CPU and memory per task:

```hcl
container_cpu    = 2048  # 2 vCPU
container_memory = 4096  # 4 GB
```

### Redis Scaling

**Vertical**: Change node type:
```hcl
redis_node_type = "cache.t3.medium"  # or cache.r6g.large, etc.
```

> **Note**: Redis is currently configured as a single-node cluster. Multi-node replication (for high availability) is not yet implemented but can be added in the future using ElastiCache Replication Groups.

### Database Scaling

**Vertical**: Change instance class:
```hcl
db_instance_class = "db.t3.large"  # or db.r6g.xlarge, etc.
```

**Storage**: Enable auto-scaling:
```hcl
db_allocated_storage     = 100
db_max_allocated_storage = 1000  # Auto-grow to 1TB
```

## Cost Optimization

### Development/Staging

**Infrastructure:**
- Use `db.t3.micro` (free tier eligible)
- Single AZ database (`db_multi_az = false`)
- Smaller ECS tasks (512 CPU, 1024 memory)
- Enable scheduled scaling (`enable_scheduled_scaling = true`) to scale down nights/weekends
- Disable optional features (VPN, Meilisearch, CloudTrail when not needed)
- Use `filesystem_disk = "local"` instead of S3 for testing

**Compliance:**
- Enable basic compliance (Config, Security Hub, GuardDuty)
- Disable production-only features (Macie, Access Analyzer, Backup Audit Manager)
- Use shorter log retention (7-14 days)

**Estimated Savings:**
- Scheduled scaling: 50-70% reduction during off-hours
- Basic compliance only: ~$70/month saved vs full compliance
- Total staging cost: ~$80-150/month

### Production

**Infrastructure:**
- Enable Multi-AZ for high availability
- Use reserved instances for predictable workloads
- Enable storage auto-scaling to avoid over-provisioning
- Use Fargate Spot for non-critical tasks (50% cost savings)
- Enable S3 lifecycle policies for old logs

**Compliance:**
- Enable full compliance suite for maximum security
- Use 90-day log retention for HIPAA compliance
- Enable all production-only features (Macie, Access Analyzer, Backup Audit Manager)

**Cost Management:**
- Set up AWS Budgets alerts
- Use Cost Explorer to track compliance costs separately
- Monitor Macie job frequency to control scanning costs
- Total production cost: ~$400-700/month (varies by traffic and data volume)

## Security Best Practices

1. **Secrets Management**
   - Never commit `.tfvars` files with real credentials
   - Use environment variables or CI/CD secrets
   - Rotate passwords regularly

2. **Network Security**
   - All resources in private subnets
   - Bastion host required for database access
   - Security groups follow least-privilege

3. **Encryption**
   - All data encrypted at rest (RDS, S3, EBS)
   - All data encrypted in transit (TLS 1.2+)
   - Separate KMS keys per service

4. **IAM**
   - Separate roles for ECS tasks and execution
   - No IAM users (use OIDC for CI/CD)
   - Regular access reviews

## Troubleshooting

### ECS Tasks Won't Start

```bash
# Check task logs
aws logs tail /ecs/laravel-app-production --follow

# Check task definition
aws ecs describe-task-definition --task-definition laravel-app-production

# Check service events
aws ecs describe-services --cluster laravel-app-production --services laravel-app-production-service
```

### Database Connection Issues

1. Check security group allows ECS -> RDS
2. Verify SSM parameters are correct
3. Test from bastion host
4. Check RDS is in `available` state

### Application Not Accessible

1. Check ALB target health
2. Verify Route53 DNS resolves correctly
3. Check ACM certificate status
4. Review WAF rules (if blocking)

## Maintenance

### Updating Infrastructure

```bash
# Update your .tfvars file
vim environments/production.tfvars

# Preview changes
terraform plan -var-file="environments/production.tfvars"

# Apply changes
terraform apply -var-file="environments/production.tfvars"
```

### Database Backups

Automated daily backups with 7-day retention. To restore:

```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier myapp-restored \
  --db-snapshot-identifier rds:myapp-2024-01-01
```

### Disaster Recovery

1. **Database**: Automated backups + optional Multi-AZ
2. **Application**: Stateless containers, quick redeploy
3. **Files**: S3 with versioning enabled
4. **Infrastructure**: Terraform state in S3 with versioning

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v1
  with:
    role-to-assume: arn:aws:iam::ACCOUNT:role/GitHubActionsRole
    aws-region: us-east-1

- name: Deploy to ECS
  run: |
    docker build -t myapp .
    docker tag myapp:latest $ECR_REPO:latest
    docker push $ECR_REPO:latest
    aws ecs update-service --cluster myapp-production --service myapp-production-service --force-new-deployment
```

## Module Structure

```
terraform/
├── main.tf                      # Root module configuration
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── versions.tf                  # Provider versions
├── environments/
│   ├── example.tfvars          # Template configuration
│   ├── staging.tfvars          # Staging environment
│   ├── uat.tfvars              # UAT environment
│   └── production.tfvars       # Production environment
└── modules/
    ├── bastion/                # Bastion host (optional)
    ├── cache/                  # ElastiCache Redis
    ├── certificates/           # ACM SSL certificates
    ├── client_vpn/             # AWS Client VPN (optional)
    ├── compliance/             # AWS Config, Security Hub, GuardDuty, Macie, etc.
    ├── compute/                # ECS Fargate cluster (web + queue-worker + scheduler)
    ├── configuration/          # SSM parameters
    ├── container_registry/     # ECR repository
    ├── database/               # RDS MySQL
    ├── dns/                    # Route53 records
    ├── email/                  # SES configuration (optional)
    ├── load_balancer/          # ALB + WAF
    ├── meilisearch/            # Meilisearch (optional)
    ├── messaging/              # SQS queues
    ├── monitoring/             # CloudWatch + CloudTrail
    ├── networking/             # VPC + Security Groups
    ├── security/               # IAM + KMS
    └── storage/                # S3 buckets
```

### ECS Services

The compute module deploys three ECS services:

- **Web Service**: Handles HTTP/HTTPS requests via the Application Load Balancer. Auto-scales based on CPU and memory utilization.
- **Queue Worker Service**: Processes Laravel queue jobs from SQS. Runs continuously with 1 task by default.
- **Scheduler Service**: Runs Laravel's task scheduler (`php artisan schedule:work`). Runs continuously with 1 task.

All three services share the same Docker image from ECR but run different commands based on their role.

## Support & Contributing

This infrastructure template is designed to be a starting point for Laravel applications on AWS. Feel free to customize it for your specific needs.

For issues, questions, or contributions, please open an issue or pull request.

## License

MIT License - use this infrastructure configuration however you'd like!
