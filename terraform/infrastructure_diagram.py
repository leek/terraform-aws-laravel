#!/usr/bin/env python3
"""
Infrastructure Diagram
Generated from Terraform configuration

Prerequisites:
    pip install diagrams
    brew install graphviz  # macOS

Usage:
    python infrastructure_diagram.py
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import ECS, ECR, EC2, Fargate
from diagrams.aws.database import RDS, ElastiCache
from diagrams.aws.network import ELB, Route53, VPC, PrivateSubnet, PublicSubnet, ClientVpn
from diagrams.aws.storage import S3
from diagrams.aws.integration import SQS
from diagrams.aws.security import Macie, SecurityHub, IAMAccessAnalyzer, Guardduty, CertificateManager
from diagrams.aws.management import Cloudwatch, CloudwatchEventTimeBased, Cloudtrail, Config
from diagrams.aws.general import Users, InternetGateway
from diagrams.aws.engagement import SimpleEmailServiceSes as SES
from diagrams.onprem.client import Client
from diagrams.onprem.ci import GithubActions

# Diagram configuration
graph_attr = {
    "fontsize": "16",
    "bgcolor": "white",
    "pad": "0.5",
}

with Diagram(
    "Infrastructure - Production",
    filename="infrastructure",
    show=False,
    direction="TB",
    graph_attr=graph_attr,
    outformat="png"
):

    # External entities
    users = Users("End Users")
    github = GithubActions("GitHub Actions\nCI/CD")

    # DNS
    with Cluster("DNS & SSL"):
        route53 = Route53("Route53\nDomain")
        acm = CertificateManager("ACM\nSSL Certificates")

    users >> route53

    # Networking
    with Cluster("VPC Network"):
        igw = InternetGateway("Internet\nGateway")

        with Cluster("Public Subnets"):
            public_subnet_1 = PublicSubnet("Public 1a")
            public_subnet_2 = PublicSubnet("Public 1b")
            public_subnets = [public_subnet_1, public_subnet_2]

        with Cluster("Private Subnets"):
            private_subnet_1 = PrivateSubnet("Private 1a")
            private_subnet_2 = PrivateSubnet("Private 1b")
            private_subnets = [private_subnet_1, private_subnet_2]

        # Bastion
        bastion = EC2("Bastion Host")

    # Load Balancer
    with Cluster("Load Balancing"):
        alb = ELB("Application\nLoad Balancer")

    route53 >> Edge(label="HTTPS") >> alb
    igw >> public_subnets

    # Container Registry
    with Cluster("Container Registry"):
        ecr = ECR("ECR\nDocker Images")

    github >> Edge(label="push images") >> ecr

    # ECS Compute
    with Cluster("ECS Fargate Compute"):
        ecs_cluster = ECS("ECS Cluster")

        with Cluster("Web Service"):
            web_service = Fargate("Web\nLaravel App\nAuto-scaling")

        with Cluster("Queue Workers"):
            queue_worker = Fargate("Queue Worker\nAsync Jobs")

        with Cluster("Scheduler"):
            scheduler = Fargate("Scheduler\nCron Jobs")

        with Cluster("Search"):
            meilisearch = Fargate("Meilisearch\nFull-text Search")

    alb >> Edge(label="HTTP") >> web_service
    ecr >> Edge(label="pull") >> [web_service, queue_worker, scheduler, meilisearch]

    # Data Layer
    with Cluster("Database & Cache"):
        with Cluster("RDS MySQL"):
            rds_primary = RDS("Primary DB\nMulti-AZ")
            rds_replica = RDS("Read Replica")
            rds_primary - Edge(label="replication", style="dashed") - rds_replica

        redis = ElastiCache("Redis\nCache & Sessions")

    web_service >> Edge(label="read/write") >> rds_primary
    web_service >> Edge(label="read") >> rds_replica
    web_service >> Edge(label="cache") >> redis
    queue_worker >> rds_primary
    scheduler >> rds_primary

    # Messaging
    with Cluster("Message Queues"):
        sqs_main = SQS("Main Queue")
        sqs_dlq = SQS("Dead Letter\nQueue")
        sqs_main >> Edge(label="failed", style="dashed") >> sqs_dlq

    web_service >> Edge(label="enqueue") >> sqs_main
    queue_worker >> Edge(label="process") >> sqs_main

    # Storage
    with Cluster("S3 Storage"):
        s3_app = S3("Application\nFilesystem\n(KMS encrypted)")
        s3_logs = S3("ALB Logs")
        s3_cloudtrail = S3("CloudTrail\nAudit Logs")
        s3_config = S3("AWS Config\nCompliance")
        s3_vpc_flow = S3("VPC Flow\nLogs")
        s3_macie = S3("Macie\nFindings")

    web_service >> Edge(label="read/write") >> s3_app
    alb >> Edge(label="logs") >> s3_logs

    # Monitoring & Logging
    with Cluster("Monitoring & Observability"):
        cloudwatch = Cloudwatch("CloudWatch\nLogs & Metrics")
        cloudtrail_svc = Cloudtrail("CloudTrail\nAPI Audit")

        with Cluster("Alarms"):
            cw_alarm = CloudwatchEventTimeBased("Health Check\nAlarms")

    web_service >> Edge(label="logs") >> cloudwatch
    queue_worker >> cloudwatch
    scheduler >> cloudwatch
    meilisearch >> cloudwatch
    cloudtrail_svc >> s3_cloudtrail

    # Compliance & Security Services
    with Cluster("Compliance & Security (Production)"):
        with Cluster("Threat Detection"):
            macie_svc = Macie("Macie\nPHI/PII Detection")
            guardduty = Guardduty("GuardDuty\nThreat Detection")

        with Cluster("Compliance Monitoring"):
            security_hub = SecurityHub("Security Hub\nCIS, HIPAA")
            config = Config("AWS Config\nCompliance Rules")
            access_analyzer = IAMAccessAnalyzer("IAM Access\nAnalyzer")

        with Cluster("Backup & DR"):
            backup_vault = S3("Backup Vault\n(KMS encrypted)")
            backup_plan = CloudwatchEventTimeBased("Backup Plan\nDaily @ 5AM UTC")
            restore_test = CloudwatchEventTimeBased("Restore Test\nWeekly Sundays")

    # Macie scanning S3 buckets
    macie_svc >> Edge(label="scan", style="dashed") >> s3_app
    macie_svc >> Edge(label="scan", style="dashed") >> s3_logs
    macie_svc >> Edge(label="findings") >> s3_macie

    # Backup relationships
    backup_plan >> Edge(label="backup") >> rds_primary
    backup_plan >> Edge(label="store") >> backup_vault
    restore_test >> Edge(label="test restore", style="dashed") >> backup_vault

    # Config monitoring
    config >> Edge(label="compliance data") >> s3_config

    # VPC Flow Logs
    private_subnets >> Edge(label="flow logs") >> s3_vpc_flow

    # Email Service
    ses = SES("SES\nEmail Service")
    web_service >> Edge(label="send email") >> ses

    # VPN Access
    vpn = ClientVpn("Client VPN\nSecure Access")
    vpn >> Edge(label="secure access") >> private_subnets

print("✅ Diagram generated: infrastructure.png")
print("\nInfrastructure Overview:")
print("• Networking: VPC with public/private subnets across 2 AZs")
print("• Compute: ECS Fargate (web, queue workers, scheduler, search)")
print("• Database: RDS MySQL Multi-AZ with read replica")
print("• Cache: ElastiCache Redis")
print("• Storage: 6 S3 buckets (app data, logs, compliance)")
print("• Security: Bastion host, Client VPN for secure access")
print("• Email: SES for transactional emails")
print("• Compliance: Macie, GuardDuty, Security Hub, AWS Config")
print("• Backup: Daily backups with weekly restore testing")
