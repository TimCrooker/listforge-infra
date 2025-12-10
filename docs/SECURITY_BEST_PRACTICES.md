# Security Best Practices - ListForge Infrastructure

**Last Updated**: December 10, 2025

---

## Secret Management

### ✅ DO

#### For Local Development/Operations

**1. Use terraform.tfvars (gitignored)**
```bash
cd environments/production
cat > terraform.tfvars << EOF
jwt_secret     = "your-jwt-secret"
openai_api_key = "sk-proj-your-key"
encryption_key = "your-hex-key"
EOF

terraform plan  # Automatically reads terraform.tfvars
```

**2. Use environment variables**
```bash
export TF_VAR_jwt_secret="your-jwt-secret"
export TF_VAR_openai_api_key="sk-proj-your-key"
export TF_VAR_encryption_key="your-hex-key"

terraform plan  # Reads from TF_VAR_* environment variables
```

**3. Use AWS Secrets Manager (recommended for production)**
```hcl
data "aws_secretsmanager_secret_version" "openai_key" {
  secret_id = "production/openai-api-key"
}

locals {
  openai_api_key = data.aws_secretsmanager_secret_version.openai_key.secret_string
}
```

#### For GitHub Actions

**1. Use GitHub Secrets (encrypted)**
```yaml
env:
  TF_VAR_openai_api_key: ${{ secrets.OPENAI_API_KEY }}
  TF_VAR_encryption_key: ${{ secrets.ENCRYPTION_KEY }}
  TF_VAR_jwt_secret: ${{ secrets.JWT_SECRET }}
```

**2. Set secrets via CLI**
```bash
# Prompts for value (not visible in terminal)
gh secret set OPENAI_API_KEY

# Or from file
echo "sk-proj-your-key" | gh secret set OPENAI_API_KEY
```

---

### ❌ DON'T

**1. Never pass secrets as command-line arguments**
```bash
# ❌ BAD - visible in shell history, process list, logs
terraform plan -var="openai_api_key=sk-proj-..."

# ❌ BAD - same issue
aws apprunner update-service --environment OPENAI_API_KEY=sk-...
```

**2. Never commit secrets to git**
```bash
# ❌ BAD
openai_api_key = "sk-proj-actual-key-here"

# ✅ GOOD
openai_api_key = "sk-proj-your-key-here"  # Placeholder only
```

**3. Never include secrets in documentation**
```markdown
# ❌ BAD
Here's my API key: sk-proj-ux4yvxn2...

# ✅ GOOD
Here's the format: sk-proj-your-key-here
```

**4. Never echo or log secrets**
```bash
# ❌ BAD
echo "API Key: $OPENAI_API_KEY"
terraform plan > plan.txt  # May contain secrets

# ✅ GOOD
echo "API Key: [REDACTED]"
terraform plan -compact-warnings  # Less verbose
```

---

## Secret Generation

### OPENAI_API_KEY
Generate from: https://platform.openai.com/api-keys
- Format: `sk-proj-...` (approximately 164 characters)
- Scope: Project-level key
- Rotation: Quarterly or when compromised

### ENCRYPTION_KEY
```bash
openssl rand -hex 32
```
- Format: 64 hexadecimal characters
- Use: Encrypting sensitive data (OAuth tokens, etc.)
- Rotation: When compromised or quarterly

### JWT_SECRET
```bash
openssl rand -base64 32
```
- Format: 44 base64 characters
- Use: Signing JWT tokens
- Rotation: Annually or when compromised
- **Note**: Rotating invalidates all existing JWT tokens

---

## Secret Storage Locations

### ✅ Secure

1. **AWS Secrets Manager** (recommended)
   - Encrypted at rest
   - Automatic rotation support
   - Access logging
   - Fine-grained IAM permissions

2. **GitHub Secrets** (for CI/CD)
   - Encrypted at rest
   - Not accessible in logs
   - Scoped to repository

3. **Local terraform.tfvars** (gitignored)
   - Not committed to git
   - Encrypted disk (FileVault/BitLocker)
   - File permissions: `chmod 600`

4. **Environment variables** (temporary)
   - Not in shell history (use `export` not CLI args)
   - Cleared after session

### ❌ Insecure

1. **Git repositories** (public or private)
   - History is permanent
   - Visible to all collaborators
   - Can be scraped by automated tools

2. **Shell history**
   - Stored in plaintext
   - Often synced to cloud
   - Visible to anyone with system access

3. **Process arguments**
   - Visible in `ps aux`
   - Logged by monitoring tools
   - Visible to all users on system

4. **Documentation/Wikis**
   - Searchable
   - Copied frequently
   - Easy to accidentally share

5. **Slack/Chat messages**
   - Logged indefinitely
   - Searchable by organization
   - May be backed up to third parties

---

## Secret Rotation Procedures

### Regular Schedule

| Secret | Rotation Frequency | Priority |
|--------|-------------------|----------|
| OPENAI_API_KEY | Quarterly | Medium |
| ENCRYPTION_KEY | Quarterly | High |
| JWT_SECRET | Annually | Low |
| Database passwords | Annually | High |
| OAuth client secrets | As needed | Medium |

### Emergency Rotation

Follow: `docs/SECRET_ROTATION_PROCEDURE.md`

**Triggers**:
- Secret appears in logs/commits
- Third-party reports leak
- Employee offboarding
- Security audit finding
- Suspicious API usage

---

## Pre-commit Hooks

### Install git-secrets

```bash
brew install git-secrets

# For infrastructure repo
cd /Users/timothycrooker/listforge-infra
git secrets --install
git secrets --register-aws
git secrets --add 'sk-[a-zA-Z0-9]{20,}'
git secrets --add '[a-f0-9]{64}'  # 32-byte hex keys

# For application repo
cd /Users/timothycrooker/list-forge-monorepo
git secrets --install
git secrets --register-aws
git secrets --add 'sk-[a-zA-Z0-9]{20,}'
```

### Test

```bash
# This should fail:
echo "openai_api_key = sk-proj-test" > test.txt
git add test.txt
git commit -m "test"
# Error: secret detected
```

---

## Access Controls

### AWS IAM

**Principle of Least Privilege**:
```hcl
# ✅ GOOD - Scoped to specific secret
resource "aws_iam_role_policy" "api_secrets" {
  policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = [
        "arn:aws:secretsmanager:*:*:secret:production/openai-*"
      ]
    }]
  })
}

# ❌ BAD - Too broad
resource "aws_iam_role_policy" "api_secrets" {
  policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:*"]
      Resource = "*"
    }]
  })
}
```

### GitHub Repository Settings

1. **Protected branches**: Require PR reviews
2. **Branch protection**: Prevent force pushes
3. **Code scanning**: Enable Dependabot
4. **Secret scanning**: Enable (catches leaked secrets)

---

## Monitoring & Alerting

### CloudWatch Alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "openai_errors" {
  alarm_name          = "openai-api-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  threshold           = "10"
  alarm_description   = "Alert on OpenAI API authentication errors"
}
```

### OpenAI Usage Monitoring

1. Set up usage alerts in OpenAI dashboard
2. Monitor for unusual patterns:
   - Sudden spike in API calls
   - Requests from unknown IPs
   - Excessive token usage

---

## Incident Response

### If a Secret is Leaked

1. **Immediate** (< 5 minutes):
   - Disable/revoke the secret
   - Document what was leaked

2. **Short-term** (< 1 hour):
   - Generate new secret
   - Update all systems
   - Remove from git history if applicable

3. **Follow-up** (< 24 hours):
   - Review logs for unauthorized usage
   - Document root cause
   - Implement preventive measures

4. **Long-term**:
   - Update procedures
   - Add monitoring/alerting
   - Train team on best practices

See: `docs/SECRET_ROTATION_PROCEDURE.md`

---

## Audit Trail

### Required Logging

1. **Secret access**:
   - AWS CloudTrail for Secrets Manager
   - App logs for secret usage
   - Failed authentication attempts

2. **Secret changes**:
   - Who rotated (IAM user/role)
   - When (timestamp)
   - Why (ticket/incident number)

3. **Git commits**:
   - Who committed
   - What was changed
   - When (timestamp)

---

## Team Practices

### Onboarding

- [ ] Install git-secrets
- [ ] Configure local terraform.tfvars
- [ ] Never commit secrets training
- [ ] Emergency procedures review

### Offboarding

- [ ] Revoke AWS access
- [ ] Rotate shared secrets
- [ ] Remove from GitHub org
- [ ] Audit recent commits

---

## Compliance

### SOC 2 / ISO 27001

- **Secret rotation**: Documented schedule
- **Access controls**: Principle of least privilege
- **Audit logging**: All secret access logged
- **Encryption**: All secrets encrypted at rest

### GDPR / Data Protection

- **Encryption keys**: Rotated quarterly
- **Access logs**: Retained for 90 days
- **Breach notification**: Within 72 hours

---

## Tools & Resources

### Secret Scanning

- [git-secrets](https://github.com/awslabs/git-secrets)
- [truffleHog](https://github.com/trufflesecurity/trufflehog)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)

### Secret Management

- [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [1Password Secrets Automation](https://1password.com/products/secrets/)

### Documentation

- [OWASP Secret Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)

---

## Review Schedule

- **Weekly**: Review CloudWatch alerts
- **Monthly**: Audit secret access logs
- **Quarterly**: Rotate high-priority secrets
- **Annually**: Review and update this document

---

**Next Review**: March 10, 2026
**Document Owner**: DevOps Team
