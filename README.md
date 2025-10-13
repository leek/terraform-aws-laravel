# Laravel AWS Infrastructure with Terraform

Production-ready AWS infrastructure for Laravel applications using Terraform. This configuration deploys a complete, scalable infrastructure on AWS with best practices for security, monitoring, and high availability.

## Features

### Core Infrastructure
- **ECS Fargate** - Containerized Laravel application with auto-scaling
- **RDS MySQL** - Managed database with automated backups
- **ElastiCache Redis** - Session and cache storage
- **Application Load Balancer** - HTTPS traffic routing with AWS WAF
- **S3** - File storage for Laravel filesystem
- **SQS** - Queue management for Laravel jobs
- **CloudWatch** - Centralized logging and monitoring
- **Route53** - DNS management and health checks

### Optional Features
- **Meilisearch** - Fast, typo-tolerant search engine (optional)
- **AWS SES** - Email sending capability (optional)
- **Client VPN** - Secure remote access to VPC (optional)
- **Bastion Host** - Secure database access (optional)
- **CloudTrail** - API audit logging (optional)
- **Read Replicas** - Database read replicas for analytics (optional)

### Security
- **KMS encryption** - All data encrypted at rest
- **VPC isolation** - Private subnets for application and database
- **IAM roles** - Least-privilege access controls
- **Security groups** - Network-level firewalling
- **SSL/TLS** - HTTPS everywhere with ACM certificates

## Architecture

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
    ┌───────────────────────┴───────────────────────┐
    │              ECS Fargate Cluster              │
    │  ┌────────────┐  ┌────────────┐               │
    │  │ Laravel    │  │ Laravel    │  (Auto-scale) │
    │  │ Container  │  │ Container  │               │
    │  └────────────┘  └────────────┘               │
    └───────┬─────────────────┬─────────────────────┘
            │                 │
    ┌───────▼────────┐  ┌─────▼─────────────┐
    │ ElastiCache    │  │  RDS MySQL        │
    │ Redis          │  │  (+ Read Replica) │
    └────────────────┘  └───────────────────┘
            │                 │
            │           ┌─────▼──────┐
            │           │  Bastion   │ (Optional)
            │           └────────────┘
            │
    ┌───────▼─────────────────────────────────┐
    │  S3 (Filesystem) + SQS (Queues)         │
    └─────────────────────────────────────────┘
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

# Database credentials
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

# Force new ECS deployment
aws ecs update-service --cluster laravel-app-production --service laravel-app-production-service --force-new-deployment
```

## Configuration Guide

### Minimal Configuration

For a basic setup (good for staging/development):

```hcl
environment = "staging"
domain_name = "staging.example.com"
app_key     = "base64:..."

app_db_password       = "..."
db_reporting_password = "..."

# Small instance sizes
container_cpu        = 512
container_memory     = 1024
db_instance_class    = "db.t3.micro"
redis_node_type      = "cache.t3.micro"

# Disable optional features
enable_meilisearch   = false
enable_ses           = false
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

# Production Redis
redis_node_type       = "cache.t3.medium"
redis_num_cache_nodes = 2

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

### Enable Client VPN

```hcl
enable_client_vpn     = true
vpn_client_cidr_block = "10.4.0.0/22"
vpn_saml_provider_arn = "arn:aws:iam::ACCOUNT:saml-provider/YourProvider"
```

Provides secure remote access to your VPC for development and debugging.

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
    ├── compute/                # ECS Fargate cluster
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

## Support & Contributing

This infrastructure template is designed to be a starting point for Laravel applications on AWS. Feel free to customize it for your specific needs.

For issues, questions, or contributions, please open an issue or pull request.

## License

MIT License - use this infrastructure configuration however you'd like!
