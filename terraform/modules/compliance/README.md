# Compliance and Auditing Module

This module provides comprehensive compliance and auditing capabilities for healthcare applications subject to HIPAA and other regulatory requirements. It configures multiple AWS services to track configuration changes, detect threats, identify sensitive data, and maintain audit trails.

## Services Included

### Environment-Specific Services
These services are created in each environment (dev, staging, production):

#### 1. AWS Config
- **Purpose**: Tracks all resource configuration changes and evaluates compliance rules
- **Features**:
  - Continuous monitoring of resource configurations
  - 12 HIPAA-specific compliance rules
  - Configuration change history
  - Compliance reporting
- **Rules Checked**:
  - ✅ EBS volumes are encrypted
  - ✅ RDS storage is encrypted
  - ✅ S3 buckets have encryption enabled
  - ✅ S3 buckets have logging enabled
  - ✅ CloudTrail is enabled
  - ✅ RDS has Multi-AZ enabled
  - ✅ Database backups are enabled
  - ✅ IAM password policy meets requirements
  - ✅ Root account has MFA enabled
  - ✅ VPC Flow Logs are enabled
  - ✅ Security groups restrict unauthorized ports

#### 2. AWS Security Hub
- **Purpose**: Centralized security and compliance dashboard
- **Features**:
  - Aggregates findings from multiple AWS services
  - Continuous compliance checks against industry standards
  - Email notifications for critical/high findings
- **Standards Enabled** (configurable):
  - CIS AWS Foundations Benchmark
  - AWS Foundational Security Best Practices
  - PCI DSS (optional)

#### 3. AWS GuardDuty
- **Purpose**: Intelligent threat detection
- **Features**:
  - Monitors CloudTrail events, VPC Flow Logs, and DNS logs
  - Detects cryptocurrency mining, unauthorized access attempts, data exfiltration
  - Machine learning-based anomaly detection
  - Email notifications for medium+ severity findings
  - Configurable finding frequency (15 min, 1 hour, 6 hours)

#### 4. VPC Flow Logs
- **Purpose**: Network traffic logging (HIPAA requirement)
- **Features**:
  - Captures all network traffic metadata
  - Stored in S3 with 90-day retention by default
  - Configurable traffic type (ACCEPT, REJECT, ALL)
  - Required for security audits and incident investigation

### Production-Only Services
These services are only created when `environment = "production"` to avoid duplication of global resources:

#### 5. AWS Macie
- **Purpose**: Discovers and protects sensitive data (PHI/PII) in S3
- **Features**:
  - Automated daily scanning of S3 buckets
  - Machine learning-based PHI/PII detection
  - Identifies HIPAA-regulated health information
  - Alerts on sensitive data exposure
  - Scans:
    - Application filesystem bucket
    - ALB logs bucket
    - CloudTrail logs bucket

#### 6. IAM Access Analyzer
- **Purpose**: Identifies resources shared with external entities
- **Features**:
  - Analyzes resource policies
  - Detects cross-account access
  - Identifies public S3 buckets
  - Validates least-privilege access

#### 7. AWS Backup Audit Manager
- **Purpose**: Audits backup compliance against frameworks
- **Features**:
  - HIPAA backup compliance framework
  - Daily compliance reports delivered to S3
  - Checks for:
    - Minimum 35-day retention
    - Encrypted recovery points
    - Daily backup frequency
    - Manual deletion protection
    - Recovery points created within 24 hours

## Architecture Diagram

```text
┌─────────────────────────────────────────────────────────────────┐
│                      Compliance & Auditing                       │
└─────────────────────────────────────────────────────────────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
          ┌─────────▼───┐  ┌──────▼──────┐  ┌──▼──────────┐
          │ AWS Config  │  │ Security Hub│  │  GuardDuty  │
          │  (Rules &   │  │ (Standards) │  │ (Threats)   │
          │   History)  │  └─────────────┘  └─────────────┘
          └─────────────┘         │                 │
                    │             │                 │
                    └─────────────┼─────────────────┘
                                  │
                          ┌───────▼────────┐
                          │   Email SNS    │
                          │ Notifications  │
                          └────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    Production-Only Services                       │
└──────────────────────────────────────────────────────────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
    ┌─────▼────────┐    ┌────────▼────────┐    ┌────────▼────────┐
    │ AWS Macie    │    │ IAM Access      │    │ Backup Audit    │
    │ (PHI Scan)   │    │ Analyzer        │    │ Manager         │
    └──────────────┘    └─────────────────┘    └─────────────────┘
          │                                              │
    ┌─────▼─────┐                                ┌──────▼──────┐
    │ S3 Buckets│                                │   Reports   │
    │  Scanning │                                │   (S3)      │
    └───────────┘                                └─────────────┘
```

## Usage

### Basic Configuration (All Environments)

```hcl
module "compliance" {
  source = "./modules/compliance"

  # Basic configuration
  app_name                   = var.app_name
  environment                = var.environment
  aws_region                 = var.aws_region
  caller_identity_account_id = data.aws_caller_identity.current.account_id
  vpc_id                     = module.networking.vpc_id
  vpc_flow_logs_bucket_arn   = module.storage.vpc_flow_logs_bucket_arn
  config_bucket_name         = module.storage.config_bucket_name
  common_tags                = local.common_tags

  # Enable all environment-specific services
  enable_aws_config    = true
  enable_hipaa_rules   = true
  enable_security_hub  = true
  enable_guardduty     = true
  enable_vpc_flow_logs = true
}
```

### Production Configuration (Full Compliance)

```hcl
module "compliance" {
  source = "./modules/compliance"

  # ... basic configuration ...

  # Environment-specific services
  enable_aws_config                    = true
  enable_hipaa_rules                   = true
  enable_security_hub                  = true
  enable_cis_standard                  = true
  enable_aws_foundational_standard     = true
  security_hub_notification_emails     = ["security@example.com"]
  enable_guardduty                     = true
  guardduty_finding_frequency          = "FIFTEEN_MINUTES"
  guardduty_notification_emails        = ["security@example.com"]
  enable_vpc_flow_logs                 = true

  # Production-only services (automatically enabled only in production)
  enable_macie                 = true
  enable_access_analyzer       = true
  enable_backup_audit_manager  = true
  enable_hipaa_framework       = true
}
```

## Required IAM Permissions

The services require the following AWS-managed policies, which are automatically configured:

- `AWSConfigRole` - For AWS Config
- Service-linked roles (automatically created):
  - `AWSServiceRoleForSecurityHub`
  - `AWSServiceRoleForAmazonGuardDuty`
  - `AWSServiceRoleForAccessAnalyzer`
  - `AWSServiceRoleForAmazonMacie`

## S3 Buckets Required

The module requires these S3 buckets (created by the storage module):

1. **Config Bucket** - Stores AWS Config data and backup audit reports
2. **VPC Flow Logs Bucket** - Stores network traffic logs
3. **Application Filesystem** - Scanned by Macie for PHI
4. **ALB Logs** - Scanned by Macie for sensitive data
5. **CloudTrail** - Scanned by Macie for sensitive data

## Email Notifications

Configure email notifications for security findings:

```hcl
security_hub_notification_emails = [
  "security-team@example.com",
  "compliance-team@example.com"
]

guardduty_notification_emails = [
  "security-team@example.com"
]
```

**Important**: Recipients must confirm their subscription via email after the first Terraform apply.

## Compliance Standards Supported

### HIPAA (Health Insurance Portability and Accountability Act)
- ✅ Encryption at rest (EBS, RDS, S3)
- ✅ Encryption in transit (TLS)
- ✅ Access logging (CloudTrail, VPC Flow Logs, S3 logs)
- ✅ Audit trails (AWS Config history)
- ✅ Backup and recovery (RDS, Backup Audit Manager)
- ✅ PHI detection and protection (Macie)
- ✅ Multi-AZ deployments for HA

### CIS AWS Foundations Benchmark
- ✅ Identity and Access Management
- ✅ Storage encryption
- ✅ Logging and monitoring
- ✅ Networking security

### AWS Foundational Security Best Practices
- ✅ Account management
- ✅ Data protection
- ✅ Detective controls
- ✅ Network security
- ✅ Resource configuration

## Cost Estimates

### Per Environment (Dev/Staging)
- AWS Config: $20-40/month
- Security Hub: $20-30/month
- GuardDuty: $15-60/month
- VPC Flow Logs: $5-15/month
- **Total: ~$60-145/month**

### Production (Additional)
- Macie: $10-40/month
- Backup Audit Manager: Free (S3 storage only)
- Access Analyzer: Free
- **Additional: ~$10-40/month**

### Total Estimated Costs
- **Development**: $60-145/month
- **Staging**: $60-145/month
- **Production**: $70-185/month

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_aws_config` | bool | `true` | Enable AWS Config |
| `enable_hipaa_rules` | bool | `true` | Enable HIPAA-specific rules |
| `enable_security_hub` | bool | `true` | Enable Security Hub |
| `enable_cis_standard` | bool | `true` | Enable CIS benchmark |
| `enable_pci_dss_standard` | bool | `false` | Enable PCI DSS standard |
| `enable_aws_foundational_standard` | bool | `true` | Enable AWS best practices |
| `security_hub_notification_emails` | list(string) | `[]` | Email addresses for Security Hub alerts |
| `enable_guardduty` | bool | `true` | Enable GuardDuty |
| `guardduty_finding_frequency` | string | `"FIFTEEN_MINUTES"` | Finding frequency |
| `guardduty_notification_emails` | list(string) | `[]` | Email addresses for GuardDuty alerts |
| `enable_macie` | bool | `false` | Enable Macie (production only) |
| `macie_finding_frequency` | string | `"ONE_HOUR"` | Macie finding frequency |
| `enable_access_analyzer` | bool | `false` | Enable Access Analyzer (production only) |
| `enable_backup_audit_manager` | bool | `false` | Enable Backup Audit Manager (production only) |
| `enable_hipaa_framework` | bool | `true` | Enable HIPAA backup framework |
| `enable_vpc_flow_logs` | bool | `true` | Enable VPC Flow Logs |
| `flow_logs_retention_days` | number | `90` | Flow logs retention days |
| `flow_logs_traffic_type` | string | `"ALL"` | Traffic type to log |

## Outputs

| Output | Description |
|--------|-------------|
| `config_recorder_id` | AWS Config recorder ID |
| `security_hub_account_id` | Security Hub account ID |
| `guardduty_detector_id` | GuardDuty detector ID |
| `macie_account_id` | Macie account ID (production only) |
| `access_analyzer_arn` | Access Analyzer ARN (production only) |
| `backup_framework_arn` | Backup framework ARN (production only) |
| `vpc_flow_log_id` | VPC Flow Log ID |

## Accessing Compliance Data

### AWS Console
1. **Security Hub**: AWS Console → Security Hub → Summary
2. **AWS Config**: AWS Console → Config → Dashboard
3. **GuardDuty**: AWS Console → GuardDuty → Findings
4. **Macie**: AWS Console → Macie → Findings
5. **Access Analyzer**: AWS Console → IAM → Access Analyzer

### CLI
```bash
# View Security Hub findings
aws securityhub get-findings --filters '{"SeverityLabel":[{"Value":"CRITICAL","Comparison":"EQUALS"}]}'

# View Config compliance
aws configservice describe-compliance-by-config-rule

# View GuardDuty findings
aws guardduty list-findings --detector-id <detector-id>

# View Macie findings
aws macie2 list-findings

# View Access Analyzer findings
aws accessanalyzer list-findings --analyzer-arn <analyzer-arn>
```

## Best Practices

1. **Email Notifications**: Always configure email notifications for production environments
2. **Regular Review**: Review compliance findings weekly
3. **Retention Policies**: Maintain VPC Flow Logs for at least 90 days
4. **Cost Optimization**: Use `SIX_HOURS` finding frequency in dev/staging environments
5. **Remediation**: Address critical and high findings within 24 hours
6. **Testing**: Test compliance configurations in staging before production
7. **Documentation**: Document any suppressed findings with justification

## Troubleshooting

### Email Subscriptions Not Confirming
- Check spam/junk folders
- Verify email addresses in variables
- Recreate subscriptions: `terraform taint module.compliance.aws_sns_topic_subscription.security_hub_email[0]`

### Config Rules Showing Non-Compliant
- Review the specific rule in AWS Config console
- Use remediation runbooks provided by AWS
- Document exceptions for audit purposes

### High GuardDuty Costs
- Reduce finding frequency to `ONE_HOUR` or `SIX_HOURS`
- Review and filter unnecessary data sources
- Consider disabling in non-production environments

### Macie Finding Too Many False Positives
- Adjust classification jobs to specific buckets
- Use custom data identifiers
- Suppress findings with justification

## Support

For issues or questions:
1. Check the AWS service documentation
2. Review CloudWatch Logs for service-specific errors
3. Consult AWS Support (if you have a support plan)
4. Review the Terraform AWS provider documentation

## References

- [AWS Config Documentation](https://docs.aws.amazon.com/config/)
- [AWS Security Hub Documentation](https://docs.aws.amazon.com/securityhub/)
- [AWS GuardDuty Documentation](https://docs.aws.amazon.com/guardduty/)
- [AWS Macie Documentation](https://docs.aws.amazon.com/macie/)
- [HIPAA on AWS](https://aws.amazon.com/compliance/hipaa-compliance/)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
