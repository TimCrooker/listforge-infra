# Terraform State Management Runbook

**Last Updated**: December 10, 2025  
**Owner**: DevOps Team

---

## Overview

This runbook covers common Terraform state management operations for the ListForge infrastructure, including handling state locks, resolving drift, and emergency procedures.

---

## State Configuration

### Backend Configuration

```hcl
backend "s3" {
  bucket         = "listforge-terraform-state"
  key            = "production/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-locks"
  encrypt        = true
}
```

**Resources**:
- **S3 Bucket**: `listforge-terraform-state` (encrypted, versioned)
- **DynamoDB Table**: `terraform-locks` (for state locking)
- **Region**: `us-east-1`

---

## Common Operations

### Check State Sync

Verify infrastructure matches Terraform configuration:

```bash
cd environments/production

# With tfvars file
terraform plan

# With inline variables
terraform plan \
  -var="jwt_secret=$JWT_SECRET" \
  -var="openai_api_key=$OPENAI_API_KEY" \
  -var="encryption_key=$ENCRYPTION_KEY"
```

**Expected Output**: `No changes. Your infrastructure matches the configuration.`

### View Current State

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show module.api.aws_apprunner_service.main

# Pull state file
terraform state pull > state_backup.json
```

### Import Existing Resources

If resources were created manually:

```bash
# Example: Import App Runner service
terraform import module.api.aws_apprunner_service.main \
  arn:aws:apprunner:us-east-1:058264088602:service/listforge-api/SERVICE_ID

# Example: Import Route53 record
terraform import module.api.aws_route53_record.custom_domain[0] \
  Z09864832NWGQZ2GSWPCQ_api.list-forge.ai_CNAME
```

---

## Troubleshooting

### Issue 1: Stuck State Lock

**Symptoms**:
```
Error: Error acquiring the state lock
Lock Info:
  ID:        a0abc5df-6560-ee5b-53f0-b419517bb47e
  Who:       runner@runnervmoqczp
  Created:   2025-12-10 17:11:42 UTC
```

**Causes**:
- Cancelled/interrupted Terraform operation
- CI/CD workflow failure
- Network interruption during apply

**Solution**:

1. **Verify the operation is truly stuck** (not just slow):
   ```bash
   aws dynamodb get-item \
     --table-name terraform-locks \
     --key '{"LockID": {"S": "listforge-terraform-state/production/terraform.tfstate"}}' \
     --region us-east-1
   ```

2. **Check lock age**:
   - If < 10 minutes: Wait for operation to complete
   - If > 10 minutes: Likely stuck, proceed to force unlock

3. **Force unlock** (⚠️ dangerous - ensure no other operations running):
   ```bash
   # Via DynamoDB (immediate)
   aws dynamodb delete-item \
     --table-name terraform-locks \
     --key '{"LockID": {"S": "listforge-terraform-state/production/terraform.tfstate"}}' \
     --region us-east-1

   # Or via Terraform (requires confirmation)
   terraform force-unlock LOCK_ID
   ```

4. **Verify unlock**:
   ```bash
   aws dynamodb scan --table-name terraform-locks --region us-east-1
   ```

---

### Issue 2: State Drift

**Symptoms**:
```
Terraform will perform the following actions:
  ~ update in-place
  + create
```

**Common Causes**:
- Manual changes via AWS Console
- Changes via AWS CLI
- Missing environment variables in Terraform config

**Resolution**:

1. **Review the drift**:
   ```bash
   terraform plan -detailed-exitcode
   # Exit code 0: No changes
   # Exit code 1: Error
   # Exit code 2: Changes detected
   ```

2. **Decide on action**:
   - **Accept drift**: Update Terraform config to match reality
   - **Revert drift**: Run `terraform apply` to restore Terraform state

3. **For environment variable drift**:
   ```bash
   # Get current App Runner env vars
   aws apprunner describe-service \
     --service-arn SERVICE_ARN \
     --query 'Service.SourceConfiguration.ImageRepository.ImageConfiguration.RuntimeEnvironmentVariables'

   # Update Terraform config to match
   # Then run: terraform apply
   ```

---

### Issue 3: Missing GitHub Secrets

**Symptoms**:
```
Error: No value for required variable
  on variables.tf line 55:
  55: variable "openai_api_key" {
```

**Solution**:

1. **List current secrets**:
   ```bash
   gh secret list
   ```

2. **Add missing secrets**:
   ```bash
   gh secret set OPENAI_API_KEY --body "sk-proj-..."
   gh secret set ENCRYPTION_KEY --body "b343b7ce..."
   ```

3. **Required secrets**:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `JWT_SECRET`
   - `OPENAI_API_KEY`
   - `ENCRYPTION_KEY`

---

### Issue 4: CI/CD Pipeline Failures

**Check logs**:
```bash
# View latest run
gh run list --limit 5

# View specific run
gh run view RUN_ID

# View failed logs
gh run view RUN_ID --log-failed
```

**Common Failures**:

1. **State lock**: See "Issue 1: Stuck State Lock"
2. **Missing secrets**: See "Issue 3: Missing GitHub Secrets"
3. **Permission errors**: Check AWS IAM roles
4. **Plan changes**: Unexpected drift detected

---

## Emergency Procedures

### Complete State Recovery

If state is corrupted or lost:

1. **Restore from S3 versioning**:
   ```bash
   aws s3api list-object-versions \
     --bucket listforge-terraform-state \
     --prefix production/terraform.tfstate

   aws s3api get-object \
     --bucket listforge-terraform-state \
     --key production/terraform.tfstate \
     --version-id VERSION_ID \
     state_backup.tfstate
   ```

2. **Rebuild state from scratch** (last resort):
   ```bash
   # Import each resource manually
   terraform import module.api.aws_apprunner_service.main ARN
   terraform import module.database.aws_db_instance.main ID
   # ... for all resources
   ```

### Rollback Infrastructure Changes

If a Terraform apply causes issues:

1. **Check previous state version in S3**
2. **Revert Terraform config** to previous commit
3. **Run** `terraform plan` to see revert changes
4. **Apply** to rollback

---

## Scheduled Maintenance

### Weekly

- [ ] Review state lock table for stale locks (> 24 hours old)
- [ ] Verify all GitHub secrets are not expiring
- [ ] Check Terraform version in CI/CD matches local

### Monthly

- [ ] Audit state file for orphaned resources
- [ ] Review IAM roles and permissions
- [ ] Test disaster recovery procedure
- [ ] Update Terraform provider versions

---

## State Inspection Commands

```bash
# List all resources in state
terraform state list

# Show details of specific resource
terraform state show module.api.aws_apprunner_service.main

# Search for resources by type
terraform state list | grep aws_apprunner_service

# Show outputs
terraform output

# Show sensitive outputs
terraform output -json
```

---

## Configuration Drift Prevention

### Best Practices

1. **Never make manual changes** in AWS Console for Terraform-managed resources
2. **Always** use Terraform for infrastructure changes
3. **Review plans carefully** before applying
4. **Use** `terraform plan` before manual operations
5. **Document** any emergency manual changes immediately

### Monitoring

Set up CloudWatch alarms for:
- Terraform state lock age > 15 minutes
- Failed CI/CD runs
- Unexpected resource modifications

---

## CI/CD Pipeline Details

### Workflows

1. **Terraform Plan** (`.github/workflows/plan.yml`)
   - Trigger: Pull requests to main
   - Actions: Format check, validate, plan
   - Output: Plan comment on PR

2. **Terraform Apply** (`.github/workflows/apply.yml`)
   - Trigger: Push to main
   - Actions: Init, apply with auto-approve
   - Output: Summary with outputs

### Required Secrets

All secrets must be set in GitHub repository settings:

```bash
# Set secrets via CLI
gh secret set JWT_SECRET --body "..."
gh secret set OPENAI_API_KEY --body "sk-proj-..."
gh secret set ENCRYPTION_KEY --body "..."
gh secret set AWS_ACCESS_KEY_ID --body "..."
gh secret set AWS_SECRET_ACCESS_KEY --body "..."
```

### Debugging Failed Runs

```bash
# List recent runs
gh run list --limit 10

# View specific run
gh run view RUN_ID

# View failed steps only
gh run view RUN_ID --log-failed

# Cancel stuck run
gh run cancel RUN_ID

# Re-run failed run
gh run rerun RUN_ID
```

---

## State Lock Table Schema

**DynamoDB Table**: `terraform-locks`

**Schema**:
```json
{
  "LockID": "listforge-terraform-state/production/terraform.tfstate",
  "Info": {
    "ID": "a0abc5df-6560-ee5b-53f0-b419517bb47e",
    "Operation": "OperationTypeApply",
    "Who": "runner@hostname",
    "Version": "1.6.0",
    "Created": "2025-12-10T17:11:42.803916491Z"
  }
}
```

**Query locks**:
```bash
# Scan all locks
aws dynamodb scan --table-name terraform-locks --region us-east-1

# Get specific lock
aws dynamodb get-item \
  --table-name terraform-locks \
  --key '{"LockID": {"S": "listforge-terraform-state/production/terraform.tfstate"}}' \
  --region us-east-1
```

---

## Contact & Escalation

**Primary**: DevOps team  
**Secondary**: Infrastructure lead  
**Emergency**: AWS Support (for AWS API issues)

---

## Change History

| Date | Change | Author |
|------|--------|--------|
| 2025-12-10 | Initial runbook created after state lock incident | System |
| 2025-12-10 | Added emergency procedures and CI/CD debugging | System |

---

## Related Documentation

- `CLAUDE.md` - Infrastructure overview
- `.github/workflows/plan.yml` - Plan workflow
- `.github/workflows/apply.yml` - Apply workflow
- `environments/production/main.tf` - Production configuration
