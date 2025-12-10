# Secret Rotation Procedure - URGENT

**Date**: December 10, 2025
**Reason**: ENCRYPTION_KEY was committed to documentation; OPENAI_API_KEY exposed in terminal commands

---

## 🚨 Secrets to Rotate Immediately

1. **OPENAI_API_KEY** - Already disabled by OpenAI ✓
2. **ENCRYPTION_KEY** - Committed to git history
3. **JWT_SECRET** - Rotate as precaution

---

## Step 1: Generate New Secrets

### 1.1 New OpenAI API Key

Go to: https://platform.openai.com/api-keys

1. Create new API key named "ListForge Production"
2. Copy the key (starts with `sk-proj-`)
3. **NEVER paste it in terminal commands or commit it to files**

### 1.2 New Encryption Key

```bash
# Generate new 32-byte hex encryption key
openssl rand -hex 32
```

Example output: `a1b2c3d4e5f6...` (64 characters)

### 1.3 New JWT Secret

```bash
# Generate new JWT secret
openssl rand -base64 32
```

Example output: `Xa3F2k9P...` (44 characters)

---

## Step 2: Update GitHub Secrets

**IMPORTANT**: Use GitHub web UI or `gh secret set` - never commit actual values!

```bash
# Set secrets via GitHub CLI (paste when prompted, don't use --body)
gh secret set OPENAI_API_KEY
gh secret set ENCRYPTION_KEY
gh secret set JWT_SECRET
```

Or via GitHub web UI:
1. Go to: https://github.com/TimCrooker/listforge-infra/settings/secrets/actions
2. Click "Update" for each secret
3. Paste new value
4. Click "Update secret"

---

## Step 3: Update AWS App Runner Environment Variables

### 3.1 Update API Service

```bash
# Get current env vars
aws apprunner describe-service \
  --service-arn arn:aws:apprunner:us-east-1:058264088602:service/listforge-api/REPLACE_WITH_SERVICE_ID \
  --region us-east-1 \
  --query 'Service.SourceConfiguration.ImageRepository.ImageConfiguration.RuntimeEnvironmentVariables'

# Update with new secrets (use placeholder pattern below)
aws apprunner update-service \
  --service-arn arn:aws:apprunner:us-east-1:058264088602:service/listforge-api/REPLACE_WITH_SERVICE_ID \
  --region us-east-1 \
  --source-configuration '{
    "ImageRepository": {
      "ImageConfiguration": {
        "RuntimeEnvironmentVariables": {
          "OPENAI_API_KEY": "PASTE_NEW_KEY_HERE",
          "ENCRYPTION_KEY": "PASTE_NEW_KEY_HERE",
          "JWT_SECRET": "PASTE_NEW_KEY_HERE",
          ... (other env vars)
        }
      }
    }
  }'
```

**SAFER APPROACH**: Use AWS Console:
1. Go to: https://console.aws.amazon.com/apprunner
2. Select `listforge-api` service
3. Configuration → Edit
4. Update environment variables
5. Save and deploy

---

## Step 4: Update Terraform Secrets (Local Only)

Create `environments/production/terraform.tfvars` (NEVER COMMIT THIS FILE):

```hcl
jwt_secret      = "paste-new-jwt-secret-here"
openai_api_key  = "paste-new-openai-key-here"
encryption_key  = "paste-new-encryption-key-here"
```

This file is in `.gitignore` - verify:
```bash
cd /Users/timothycrooker/listforge-infra
git check-ignore environments/production/terraform.tfvars
# Should output: environments/production/terraform.tfvars
```

---

## Step 5: Rotate Database Encryption Key (If Sensitive Data Exists)

Since `ENCRYPTION_KEY` was leaked and is used to encrypt OAuth tokens:

1. **Check what's encrypted**:
   - Marketplace OAuth tokens (eBay, Amazon)
   - Any sensitive user data

2. **Rotation procedure**:
   ```sql
   -- Connect to database
   -- Re-encrypt all tokens with new key
   -- This requires application-level migration
   ```

**IMPORTANT**: You may need to ask users to re-authorize marketplace connections after key rotation.

---

## Step 6: Clean Up Leaked Secrets

### 6.1 Git History

The ENCRYPTION_KEY is in git history but has been removed from latest commit.

**Option A**: Rewrite history (breaks anyone who has pulled):
```bash
cd /Users/timothycrooker/listforge-infra
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch docs/TERRAFORM_STATE_SYNC_COMPLETE.md" \
  --prune-empty --tag-name-filter cat -- --all
git push --force --all
```

**Option B**: Accept it's in history, rotate the key (recommended for active repos)

### 6.2 Terminal History

```bash
# Clear terminal history entries containing secrets
history | grep -i "openai\|encryption"
# Note the line numbers, then:
history -d LINE_NUMBER

# Or clear all history:
history -c
rm ~/.zsh_history
```

### 6.3 Cursor Transcript

Transcripts are saved at:
```
/Users/timothycrooker/.cursor/projects/Users-timothycrooker-list-forge-monorepo/agent-transcripts/
```

Consider deleting transcripts containing the leaked keys.

---

## Step 7: Test After Rotation

### 7.1 Test Terraform

```bash
cd /Users/timothycrooker/listforge-infra/environments/production
terraform plan
# Should work with new secrets from tfvars file or env vars
```

### 7.2 Test API

```bash
curl https://api.list-forge.ai/api/health
# Should return: {"status": "ok", ...}
```

### 7.3 Test AI Features

Try using chat or research features in the application to confirm OpenAI integration works.

---

## Best Practices Going Forward

### ✅ DO:

1. **Use environment variables or secret management**:
   ```bash
   export OPENAI_API_KEY="..."
   terraform plan  # Reads from TF_VAR_openai_api_key env var
   ```

2. **Use `terraform.tfvars` (gitignored)**:
   ```bash
   terraform plan  # Automatically reads terraform.tfvars
   ```

3. **Use AWS Secrets Manager for runtime secrets** (future improvement)

### ❌ DON'T:

1. **Never pass secrets as command-line arguments**:
   ```bash
   # ❌ BAD - visible in shell history and process list
   terraform plan -var="openai_api_key=sk-proj-..."
   ```

2. **Never commit actual secrets to git**, even in example files:
   ```bash
   # ✅ GOOD
   openai_api_key = "sk-proj-your-key-here"

   # ❌ BAD
   openai_api_key = "sk-proj-ux4yvxn2jcvSuhxa..."
   ```

3. **Never include secrets in documentation or runbooks**

---

## Verification Checklist

- [ ] New OpenAI API key created
- [ ] New ENCRYPTION_KEY generated
- [ ] New JWT_SECRET generated
- [ ] All 3 secrets updated in GitHub
- [ ] API service env vars updated in AWS
- [ ] Terraform tfvars file created (local only)
- [ ] `terraform plan` works with new secrets
- [ ] API health check passes
- [ ] AI features work (OpenAI connection)
- [ ] Terminal history cleaned
- [ ] Old secrets documented as rotated
- [ ] Users notified if marketplace re-auth needed

---

## Emergency Contacts

- **OpenAI Support**: https://help.openai.com/
- **AWS Support**: Your support plan level
- **Team Lead**: Notify of secret rotation

---

## Post-Incident Review

### What Went Wrong:
1. ENCRYPTION_KEY committed to documentation file
2. OPENAI_API_KEY passed as CLI argument (visible in logs/history)

### What Went Right:
1. OpenAI detected and disabled the key automatically
2. Keys not committed to git repositories
3. Rapid detection and response

### Improvements Needed:
1. Migrate to AWS Secrets Manager for runtime secrets
2. Use terraform.tfvars file for local operations
3. Never pass secrets as CLI arguments
4. Add pre-commit hooks to detect secrets
5. Regular secret rotation schedule

---

**Status**: Ready to execute rotation procedure
**Priority**: HIGH - Execute within 24 hours
