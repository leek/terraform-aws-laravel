#!/bin/bash
set -euo pipefail

BOOTSTRAP_SCRIPT="/usr/local/bin/bastion-bootstrap.sh"
LOG_FILE="/var/log/bastion-bootstrap.log"

cat > "$BOOTSTRAP_SCRIPT" <<'SCRIPT'
#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/bastion-bootstrap.log"
exec > >(tee -a "$LOG_FILE") 2>&1

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log() {
  echo "[$(timestamp)] $*"
}

retry() {
  local attempts="$1"
  local delay="$2"
  shift 2

  local n=1
  until "$@"; do
    if [ "$n" -ge "$attempts" ]; then
      log "Command failed after $attempts attempts: $*"
      return 1
    fi
    log "Command failed (attempt $n/$attempts): $*; retrying in $${delay}s"
    n=$((n + 1))
    sleep "$delay"
  done
}

if [ -f /var/log/bastion-bootstrap.done ]; then
  log "Bootstrap already completed; exiting"
  exit 0
fi

log "Starting bastion bootstrap"

retry 5 30 yum update -y

%{ if install_mysql_client ~}
log "Installing MySQL client"
retry 5 30 yum install -y mysql
%{ endif ~}

%{ if install_redis_client ~}
log "Installing Redis client"
retry 5 30 amazon-linux-extras install -y redis6
%{ endif ~}

log "Installing base utilities"
retry 5 30 yum install -y htop nano vim curl wget git unzip jq

log "Installing AWS CLI v2"
retry 5 30 bash -c 'cd /tmp && curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip'
retry 5 30 bash -c 'cd /tmp && unzip -o awscliv2.zip'
retry 5 30 bash -c 'cd /tmp && ./aws/install'
rm -rf /tmp/aws /tmp/awscliv2.zip

log "Installing Terraform"
TERRAFORM_VERSION="1.10.5"
retry 5 30 bash -c "cd /tmp && wget -q \"https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip\""
retry 5 30 bash -c "cd /tmp && unzip -o \"terraform_$${TERRAFORM_VERSION}_linux_amd64.zip\""
mv /tmp/terraform /usr/local/bin/
rm -f /tmp/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip
chmod +x /usr/local/bin/terraform

log "Installing Docker engine"
retry 5 30 amazon-linux-extras install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

log "Installing Docker Compose"
DOCKER_COMPOSE_VERSION="2.34.1"
retry 5 30 curl -sSL "https://github.com/docker/compose/releases/download/v$${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

cat > /etc/motd <<'MOTD'
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
MOTD

%{ if setup_mysql_user ~}
log "Configuring MySQL users"
sleep 30

MASTER_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "${rds_master_password_secret_arn}" \
  --region "${aws_region}" \
  --query 'SecretString' \
  --output text | jq -r '.password')

if [ -z "$MASTER_PASSWORD" ]; then
  log "ERROR: Failed to retrieve master password from Secrets Manager"
  exit 1
fi

for i in $(seq 1 30); do
  if mysql -h "${rds_endpoint}" -u "${rds_master_username}" -p"$MASTER_PASSWORD" -e "SELECT 1;" 2>/dev/null; then
    log "RDS is ready"
    break
  fi
  log "Waiting for RDS... attempt $i/30"
  sleep 10
done

mysql -h "${rds_endpoint}" -u "${rds_master_username}" -p"$MASTER_PASSWORD" <<MYSQL_SCRIPT
CREATE USER IF NOT EXISTS '${app_db_username}'@'%' IDENTIFIED BY '${app_db_password}';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER,
      CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW,
      SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, TRIGGER, REFERENCES
ON \`${rds_database_name}\`.* TO '${app_db_username}'@'%';
CREATE USER IF NOT EXISTS 'reporting'@'%' IDENTIFIED BY '${db_reporting_password}';
GRANT SELECT, SHOW VIEW ON \`${rds_database_name}\`.* TO 'reporting'@'%';
FLUSH PRIVILEGES;
SELECT User, Host FROM mysql.user WHERE User IN ('${app_db_username}', 'reporting');
MYSQL_SCRIPT

MYSQL_EXIT_CODE=$?
unset MASTER_PASSWORD

if [ "$MYSQL_EXIT_CODE" -eq 0 ]; then
  log "MySQL application and reporting users created successfully"
else
  log "ERROR: Failed to create MySQL users"
fi
%{ endif ~}

touch /var/log/bastion-bootstrap.done
log "Bastion bootstrap completed"
SCRIPT

chmod +x "$BOOTSTRAP_SCRIPT"
nohup "$BOOTSTRAP_SCRIPT" >/dev/null 2>&1 &
