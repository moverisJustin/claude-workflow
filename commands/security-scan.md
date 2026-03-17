---
description: Run comprehensive security scan - SAST, dependency vulnerabilities, secrets detection, OWASP checks
---

# Security Scan

## Scanning...

### Dependency Vulnerabilities
!`npm audit`

### Outdated Packages
!`npm outdated`

Run the security analysis steps below:

### Hardcoded Secrets Check
Search for hardcoded secrets (passwords, API keys, tokens) in source files.

### AWS Credentials
Search for AWS access key patterns (AKIA...) in the repository.

### Private Keys
Check for .pem and .key files in the repository.

### SQL Injection Patterns
Search for string interpolation inside query calls in source files.

### Dangerous Functions
Search for eval() and new Function() usage in source files.

### XSS Vulnerabilities
Search for dangerouslySetInnerHTML usage in JSX/TSX files.

### CORS Configuration
Search for wildcard CORS configurations in source files.

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
