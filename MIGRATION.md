# Migration Guide

## Upgrading to Multi-Database Support

This guide covers migrating from the MySQL-only version to the multi-database support version.

### Overview

The database module has been enhanced to support multiple database engines (MySQL, MariaDB, PostgreSQL, Aurora MySQL, Aurora PostgreSQL). This enhancement required restructuring the module to use conditional logic, which changes Terraform resource addresses.

### Impact

**Existing MySQL deployments** require Terraform state migration to avoid database recreation.  
**New deployments** are not affected - no migration needed.

### Migration Steps

#### Prerequisites

1. **Backup your database** before starting migration
2. Ensure you have the latest Terraform state
3. Have access to run Terraform commands on your infrastructure

#### Step 1: Verify Current State

```bash
# Navigate to your Terraform directory
cd terraform

# Check current state
terraform state list | grep database
```

You should see resources like:
- `module.database.module.rds`
- `module.database.module.rds_read_replica` (if using read replica)

#### Step 2: Update Terraform Configuration

Pull the latest changes that include multi-database support:

```bash
git pull origin main  # or your branch name
```

**Do not run `terraform apply` yet!**

#### Step 3: Migrate Terraform State

Run the following commands to update the state:

```bash
# Migrate main RDS instance
terraform state mv \
  'module.database.module.rds' \
  'module.database.module.rds[0]'

# Migrate read replica (only if you have one)
terraform state mv \
  'module.database.module.rds_read_replica' \
  'module.database.module.rds_read_replica[0]'
```

#### Step 4: Verify Migration

```bash
# Run plan to verify no changes to database
terraform plan -var-file="environments/production.tfvars"
```

Expected output: Should show **no changes** to database resources. You may see changes to other resources (security groups, bastion), but the RDS instance itself should be unchanged.

If Terraform wants to destroy and recreate your database, **STOP** and verify the state migration was successful.

#### Step 5: Apply Changes

Once verified, apply the changes:

```bash
terraform apply -var-file="environments/production.tfvars"
```

This will update security groups and other resources to support the new multi-database configuration, but will not modify your existing database.

### Rollback

If you need to rollback:

```bash
# Revert state changes
terraform state mv \
  'module.database.module.rds[0]' \
  'module.database.module.rds'

terraform state mv \
  'module.database.module.rds_read_replica[0]' \
  'module.database.module.rds_read_replica'

# Checkout previous version
git checkout <previous-version>

# Apply old configuration
terraform apply -var-file="environments/production.tfvars"
```

### Troubleshooting

#### "Resource not found in state"

If you get an error that the resource doesn't exist:
1. Run `terraform state list` to see exact resource names
2. Adjust the `state mv` commands to match your actual resource names
3. Your environment name or app name might be different

#### "Plan shows database will be destroyed"

If `terraform plan` shows your database will be destroyed:
1. **DO NOT APPLY** - this would cause data loss
2. Double-check the state migration commands
3. Verify resource names with `terraform state list`
4. Contact support if you need assistance

#### Read Replica Not Found

If you don't have a read replica, you'll get an error when trying to migrate it. This is expected - just skip that migration command.

### Getting Help

If you encounter issues during migration:

1. Check existing GitHub issues for similar problems
2. Open a new issue with:
   - Your Terraform version
   - Output of `terraform state list | grep database`
   - The exact error message
   - Whether this is a production or staging environment

### FAQ

**Q: Can I skip migration and just recreate the database?**  
A: For non-production environments with no critical data, yes. For production, **always migrate** to avoid data loss.

**Q: Will this affect my application during migration?**  
A: No. The state migration is a Terraform-only operation that doesn't touch AWS resources. Your application continues running normally.

**Q: What if I use multiple environments (staging, production)?**  
A: Perform migration for each environment separately. Start with staging to validate the process.

**Q: Do I need to migrate if I'm using Aurora?**  
A: No, this only affects existing RDS MySQL deployments. Aurora is new functionality.

**Q: My state is stored remotely (S3). Does that change anything?**  
A: No, `terraform state mv` works the same way with remote state. Just ensure you have exclusive access (no other team members running Terraform) during migration.
