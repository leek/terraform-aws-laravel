#!/bin/bash
yum update -y

%{ if install_mysql_client ~}
# Install MySQL client
yum install -y mysql
%{ endif ~}

%{ if install_redis_client ~}
# Install Redis client
amazon-linux-extras install -y redis6
%{ endif ~}

# Install useful tools
yum install -y htop nano vim curl wget git unzip jq

# ========================================
# Install AWS CLI v2
# ========================================
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# ========================================
# Install Terraform
# ========================================
TERRAFORM_VERSION="1.10.5"
cd /tmp
wget "https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip"
unzip "terraform_$${TERRAFORM_VERSION}_linux_amd64.zip"
mv terraform /usr/local/bin/
rm "terraform_$${TERRAFORM_VERSION}_linux_amd64.zip"
chmod +x /usr/local/bin/terraform

# ========================================
# Install Docker
# ========================================
amazon-linux-extras install -y docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install Docker Compose
DOCKER_COMPOSE_VERSION="2.34.1"
curl -L "https://github.com/docker/compose/releases/download/v$${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Create a welcome message
cat > /etc/motd << 'EOF'
=================================
  Bastion Host
=================================
This server provides secure access to:
- RDS MySQL database (port 3306)
- ElastiCache Redis (port 6379)

Installed Tools:
- AWS CLI v2
- Terraform
- Docker & Docker Compose
- Git, jq, and other utilities

Use SSH tunneling to connect to private resources.
=================================
EOF

%{ if setup_mysql_user ~}
# ========================================
# Setup MySQL Application User
# ========================================
echo "Setting up MySQL application user..." >> /var/log/bastion-setup.log

# Wait for instance profile and AWS CLI to be ready
sleep 30

# Get the master password from Secrets Manager
MASTER_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "${rds_master_password_secret_arn}" \
  --region "${aws_region}" \
  --query 'SecretString' \
  --output text | jq -r '.password')

if [ -z "$MASTER_PASSWORD" ]; then
  echo "ERROR: Failed to retrieve master password from Secrets Manager" >> /var/log/bastion-setup.log
  exit 1
fi

# Wait for RDS to be available
echo "Waiting for RDS to be available..." >> /var/log/bastion-setup.log
for i in {1..30}; do
  if mysql -h "${rds_endpoint}" -u "${rds_master_username}" -p"$MASTER_PASSWORD" -e "SELECT 1;" 2>/dev/null; then
    echo "RDS is ready" >> /var/log/bastion-setup.log
    break
  fi
  echo "Waiting for RDS... attempt $i/30" >> /var/log/bastion-setup.log
  sleep 10
done

# Create application database user with limited privileges
echo "Creating application user '${app_db_username}'..." >> /var/log/bastion-setup.log

mysql -h "${rds_endpoint}" -u "${rds_master_username}" -p"$MASTER_PASSWORD" <<MYSQL_SCRIPT
-- Create the application user if it doesn't exist
CREATE USER IF NOT EXISTS '${app_db_username}'@'%' IDENTIFIED BY '${app_db_password}';

-- Grant necessary privileges for Laravel (migrations, CRUD operations)
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER,
      CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW,
      SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, TRIGGER, REFERENCES
ON \`${rds_database_name}\`.* TO '${app_db_username}'@'%';

-- Create read-only reporting user
CREATE USER IF NOT EXISTS 'reporting'@'%' IDENTIFIED BY '${db_reporting_password}';

-- Grant read-only privileges for reporting
GRANT SELECT, SHOW VIEW ON \`${rds_database_name}\`.* TO 'reporting'@'%';

-- Flush privileges
FLUSH PRIVILEGES;

-- Verify users were created
SELECT User, Host FROM mysql.user WHERE User IN ('${app_db_username}', 'reporting');
MYSQL_SCRIPT

if [ $? -eq 0 ]; then
  echo "MySQL application and reporting users created successfully" >> /var/log/bastion-setup.log
else
  echo "ERROR: Failed to create MySQL users" >> /var/log/bastion-setup.log
fi

# Clear the password from memory
unset MASTER_PASSWORD
%{ endif ~}

echo "Bastion host setup completed" > /var/log/bastion-setup.log
