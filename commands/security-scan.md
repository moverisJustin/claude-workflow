---
description: Run comprehensive security scan - SAST, dependency vulnerabilities, secrets detection, OWASP checks
---

# Security Scan

## Scanning...

### Dependency Vulnerabilities
!`npm audit --json 2>/dev/null | jq -r '.metadata.vulnerabilities | to_entries | map(select(.value > 0)) | .[] | "\(.key): \(.value)"' 2>/dev/null || npm audit 2>/dev/null | head -30 || echo "Run npm install first"`

### Outdated Packages
!`npm outdated 2>/dev/null | head -15 || echo ""`

### Hardcoded Secrets Check
!`grep -rn --include="*.ts" --include="*.js" --include="*.tsx" --include="*.jsx" -E "(password|secret|api_key|apikey|token)['\"]?\s*[:=]\s*['\"][a-zA-Z0-9+/=]{8,}" src/ 2>/dev/null | head -10 || echo "No obvious secrets found in src/"`

### AWS Credentials
!`grep -rn "AKIA[0-9A-Z]{16}" . 2>/dev/null | head -5 || echo "No AWS keys found"`

### Private Keys
!`find . -name "*.pem" -o -name "*.key" 2>/dev/null | grep -v node_modules | head -5 || echo "No private key files found"`

### SQL Injection Patterns
!`grep -rn --include="*.ts" --include="*.js" -E "query\s*\(\s*['\"\`].*\\\$\{" src/ 2>/dev/null | head -5 || echo "No obvious SQL injection patterns"`

### Dangerous Functions
!`grep -rn --include="*.ts" --include="*.js" -E "\beval\s*\(|new Function\s*\(" src/ 2>/dev/null | head -5 || echo "No eval/Function found"`

### XSS Vulnerabilities
!`grep -rn --include="*.tsx" --include="*.jsx" "dangerouslySetInnerHTML" src/ 2>/dev/null | head -5 || echo "No dangerouslySetInnerHTML found"`

### CORS Configuration
!`grep -rn --include="*.ts" --include="*.js" -E "cors.*['\"]\\*['\"]|Access-Control-Allow-Origin.*\\*" src/ 2>/dev/null | head -3 || echo "No wildcard CORS found"`

---

## Security Analysis

### Invoke Security Auditor

For a complete analysis, invoke the security-auditor agent:

```
Use Task tool with subagent_type: security-auditor
```

The security auditor will:
1. Run comprehensive SAST scans
2. Check all OWASP Top 10 categories
3. Analyze authentication flows
4. Review authorization patterns
5. Generate detailed report

---

## Quick Fixes

### High-Priority Actions

If vulnerabilities found:

```bash
# Fix npm audit issues
npm audit fix

# For breaking changes
npm audit fix --force  # Use with caution
```

### Secrets Found

If secrets detected:
1. **Immediately** rotate the exposed credential
2. Remove from code
3. Use environment variables
4. Add to `.gitignore` if file-based
5. Check git history: `git filter-branch` or BFG

### OWASP Issues

For each finding, consult:
- A01: Implement proper access control
- A02: Use strong cryptography
- A03: Parameterize all queries
- A04: Review architecture design
- A05: Check all configurations
- A06: Update vulnerable components
- A07: Verify authentication logic
- A08: Check software integrity
- A09: Enable security logging
- A10: Validate all server-side requests

---

## Output Format

```markdown
## 🔒 Security Scan Report

### Summary
| Category | Status | Count |
|----------|--------|-------|
| Dependencies | ⚠️ | 3 high |
| Secrets | ✅ | 0 found |
| SAST | ⚠️ | 2 issues |
| Configuration | ✅ | Clean |

### Critical Issues
🔴 **[Issue Title]**
- Location: `file:line`
- Risk: [Description]
- Fix: [How to fix]

### High Severity
🟠 **[Issue Title]**
- Location: `file:line`
- Risk: [Description]
- Fix: [How to fix]

### Recommendations
1. [Priority action]
2. [Secondary action]

### Verdict
[ ] ✅ No issues found
[ ] ⚠️ Issues found - review recommended
[ ] 🛑 Critical issues - fix before deploy
```

---

## When to Run

- Before every deployment
- After adding dependencies
- When handling user input
- During code review
- Periodically (weekly)
