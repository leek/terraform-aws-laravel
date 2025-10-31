> [!WARNING]
> This Terraform configuration provisions real AWS infrastructure that may incur significant costs depending on your usage and configuration. **Use at your own risk** - you are solely responsible for reviewing, understanding, and monitoring any resources and charges created by this code. Always test in a non-production environment and review the Terraform plan carefully before applying changes.

# Laravel AWS Infrastructure with Terraform

Production-ready AWS infrastructure for Laravel applications using Terraform. This configuration deploys a complete, scalable infrastructure on AWS with best practices for security, monitoring, and high availability.

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
- **Nightwatch** - Browser automation and end-to-end testing (optional)
- **Client VPN** - Secure remote access to VPC (optional)
- **Bastion Host** - Secure database access (optional)
- **CloudTrail** - API audit logging (optional)
- **Read Replicas** - Database read replicas for analytics (optional)

### Security
- **KMS encryption** - All data encrypted at rest
- **VPC isolation** - Private subnets for application and database
- **IAM roles** - Least-privilege access controls
- **Security groups** - Network-level firewalling
- **SSL/TLS** - HTTPS everywhere with ACM certificates (includes VPN server certificates)

## Architecture

The infrastructure deploys three core ECS services, with optional Nightwatch service available:
1. **Web Service** - Handles HTTP/HTTPS traffic through the ALB (auto-scales based on traffic)
2. **Queue Worker Service** - Processes Laravel queue jobs from SQS (always runs 1 task)
3. **Scheduler Service** - Runs Laravel's task scheduler (`php artisan schedule:work`) (always runs 1 task)
4. **Nightwatch Service** (Optional) - Runs browser automation and end-to-end tests (disabled by default)

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

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0
3. **AWS CLI** configured with credentials
4. **Domain name** registered (can be managed elsewhere)
5. **Laravel application** containerized with Docker

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

### 4. Deploy Your Application

After infrastructure is created:

```bash
# Build and push your Docker image
docker build -t myapp .
aws ecr get-login-password | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url)
docker tag myapp:latest $(terraform output -raw ecr_repository_url):latest
docker push $(terraform output -raw ecr_repository_url):latest

# Force new ECS deployment (updates core services: web, queue-worker, scheduler)
CLUSTER=$(terraform output -raw ecs_cluster_name)
aws ecs update-service --cluster $CLUSTER --service $(terraform output -raw ecs_service_name) --force-new-deployment
aws ecs update-service --cluster $CLUSTER --service $(terraform output -raw ecs_queue_worker_service_name) --force-new-deployment
aws ecs update-service --cluster $CLUSTER --service $(terraform output -raw ecs_scheduler_service_name) --force-new-deployment

# Optionally update Nightwatch service (if enabled)
# aws ecs update-service --cluster $CLUSTER --service $(terraform output -raw ecs_nightwatch_service_name) --force-new-deployment
```

## Configuration Guide

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

# Small instance sizes
container_cpu        = 512
container_memory     = 1024
desired_count        = 1
min_capacity         = 1
max_capacity         = 4

db_instance_class    = "db.t3.micro"
redis_node_type      = "cache.t3.micro"

# Disable optional features
enable_meilisearch   = false
enable_ses           = false
enable_nightwatch    = false
enable_client_vpn    = false
enable_bastion       = false
enable_cloudtrail    = false
```

**Estimated cost**: ~$50-100/month

### Production Configuration

For production with high availability:

```hcl
environment = "production"
domain_name = "example.com"
app_key     = "base64:..."
github_org  = "your-org"
github_repo = "your-repo"

app_db_password       = "..."
db_reporting_password = "..."

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
```

**Estimated cost**: ~$300-500/month

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

### Enable Nightwatch (Browser Testing)

```hcl
enable_nightwatch        = true
nightwatch_cpu           = 512   # CPU units (512 = 0.5 vCPU)
nightwatch_memory        = 1024  # Memory in MB
nightwatch_desired_count = 1     # Number of tasks (typically 0 or 1)
```

Laravel Nightwatch provides browser automation and end-to-end testing capabilities. When enabled, a dedicated ECS service is created to run Nightwatch tests.

Key features:
- Runs as a separate ECS Fargate service
- Uses the same Docker image as your web application
- Identified by `CONTAINER_ROLE=nightwatch` environment variable
- Can be scaled independently from web and worker services

Usage in your Laravel application:
```dockerfile
# In your Dockerfile entrypoint or startup script
if [ "$CONTAINER_ROLE" = "nightwatch" ]; then
    # Run Nightwatch tests
    php artisan nightwatch:run
fi
```

To deploy Nightwatch tests:
```bash
# Force redeploy Nightwatch service after pushing new image
CLUSTER=$(terraform output -raw ecs_cluster_name)
aws ecs update-service --cluster $CLUSTER --service $(terraform output -raw ecs_nightwatch_service_name) --force-new-deployment
```

**Note**: Set `nightwatch_desired_count = 0` or `enable_nightwatch = false` to disable the service and avoid incurring costs when not running tests.

### Enable Client VPN

```hcl
enable_client_vpn     = true
vpn_client_cidr_block = "10.4.0.0/22"
vpn_saml_provider_arn = "arn:aws:iam::ACCOUNT:saml-provider/YourProvider"
```

Provides secure remote access to your VPC for development and debugging.

> **Note**: VPN server certificates are automatically provisioned for all environments via ACM (even if Client VPN is disabled). This allows you to enable VPN later without additional certificate setup.

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

- Use `db.t3.micro` (free tier eligible)
- Single AZ database (`db_multi_az = false`)
- Smaller ECS tasks (512 CPU, 1024 memory)
- Disable optional features (VPN, Meilisearch, CloudTrail)
- Use `filesystem_disk = "local"` instead of S3

### Production

- Enable Multi-AZ for high availability
- Use reserved instances for predictable workloads
- Enable storage auto-scaling to avoid over-provisioning
- Use Fargate Spot for non-critical tasks (50% cost savings)
- Enable S3 lifecycle policies for old logs

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
│   └── production.tfvars       # Production environment
└── modules/
    ├── bastion/                # Bastion host (optional)
    ├── cache/                  # ElastiCache Redis
    ├── certificates/           # ACM SSL certificates
    ├── client_vpn/             # AWS Client VPN (optional)
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

The compute module deploys three core ECS services, with optional Nightwatch service available:

- **Web Service**: Handles HTTP/HTTPS requests via the Application Load Balancer. Auto-scales based on CPU and memory utilization.
- **Queue Worker Service**: Processes Laravel queue jobs from SQS. Runs continuously with 1 task by default.
- **Scheduler Service**: Runs Laravel's task scheduler (`php artisan schedule:work`). Runs continuously with 1 task.
- **Nightwatch Service** (Optional): Runs browser automation and end-to-end tests. Disabled by default (`enable_nightwatch = false`).

All services share the same Docker image from ECR but run different commands based on their role (identified by the `CONTAINER_ROLE` environment variable).

## Support & Contributing

This infrastructure template is designed to be a starting point for Laravel applications on AWS. Feel free to customize it for your specific needs.

For issues, questions, or contributions, please open an issue or pull request.

## License

MIT License - use this infrastructure configuration however you'd like!
