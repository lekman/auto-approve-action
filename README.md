# Auto-Approve GitHub Action

Auto-Approve GitHub Action is a composite action that brings automated pull request approval to your GitHub workflow. Designed for development teams and DevOps engineers, this action enables you to automatically approve qualified PRs from trusted sources while maintaining lifecycle controls through validation. The project aims to accelerate development velocity, reduce manual approval bottlenecks, and maintain an audit trail for compliance requirements.

Key features include:

- **Workflow Validation** - Author allow lists, label requirements, and status check verification
- **Flexible Configuration** - Customizable approval criteria for different workflow scenarios
- **Audit Trails** - Detailed logging and approval decision documentation
- **Composite Action Architecture** - Reusable across multiple repositories and teams
- **Smart Check Monitoring** - Intelligent waiting for CI/CD pipeline completion with configurable timeouts
- **GitHub App/PAT Support** - Secure token-based authentication with code owner privileges

## Usage

### Prerequisites:
- A GitHub Personal Access Token (PAT) or GitHub App token with `repo` and `pull_requests:write` permissions
- Code owner privileges or admin access for the token owner
- Existing CI/CD workflows for status check validation

### Basic Setup:

1. **Create repository secret** for your GitHub token:
   - Go to Repository Settings > Secrets and variables > Actions
   - Add `CODE_OWNER_TOKEN` with your PAT or App token

2. **Add workflow file** (`.github/workflows/auto-approve.yml`):
   ```yaml
   name: Auto Approve PR
   
   on:
     pull_request:
       types: [opened, synchronize, reopened]
   
   jobs:
     auto-approve:
       runs-on: ubuntu-latest
       steps:
         - name: Checkout
           uses: actions/checkout@v4
   
         - name: Auto Approve PR
           uses: lekman/auto-approve-action@v1
           with:
             github-token: ${{ secrets.CODE_OWNER_TOKEN }}
             allowed-authors: "dependabot[bot], renovate[bot], trusted-dev"
             required-labels: "auto-approve, dependencies"
             label-match-mode: "any"
             wait-for-checks: true
             max-wait-time: 30
   ```

3. **Configure your approval criteria**:
   - Set `allowed-authors` to trusted GitHub usernames
   - Define `required-labels` for additional security (optional)
   - Choose `label-match-mode`: `all`, `any`, or `none`

### Advanced Configuration Examples:

**Dependabot with Safety Labels:**
```yaml
allowed-authors: "dependabot[bot]"
required-labels: "dependencies, minor-update"
label-match-mode: "all"
```

**Documentation Team Workflow:**
```yaml
allowed-authors: 'docs-team, technical-writers'
required-labels: 'documentation'
label-match-mode: 'any'
```

**Emergency Hotfix Process:**
```yaml
allowed-authors: 'senior-dev-1, on-call-engineer'
required-labels: 'hotfix, emergency'
label-match-mode: 'any'
max-wait-time: '10'
```

## Configuration Reference

### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `github-token` | ✅ | - | GitHub token with repo and PR write permissions |
| `allowed-authors` | ✅ | - | Comma-separated list of GitHub usernames allowed for auto-approval |
| `required-labels` | ❌ | `''` | Comma-separated list of required PR labels |
| `label-match-mode` | ❌ | `'all'` | How to match labels: `all`, `any`, or `none` |
| `wait-for-checks` | ❌ | `'true'` | Whether to wait for status checks to complete |
| `required-checks` | ❌ | `''` | Specific check names to wait for (optional) |
| `max-wait-time` | ❌ | `'30'` | Maximum wait time for checks in minutes |
| `approval-message` | ❌ | `'Auto-approved after all checks passed ✅'` | Custom approval message |

### Outputs

| Output | Description |
|--------|-------------|
| `approved` | Whether the PR was successfully approved |
| `author-allowed` | Whether the PR author is in the allowed list |
| `labels-match` | Whether the PR labels meet requirements |
| `checks-status` | Final status of the required checks |

## Security Considerations

### Token Security
- **Use GitHub Apps** instead of Personal Access Tokens when possible
- **Rotate tokens regularly** and monitor for unauthorized usage
- **Limit token scope** to minimum required permissions
- **Store tokens securely** in GitHub Secrets, never in code

### Access Control
- **Restrict allowed authors** to trusted users and verified bots only
- **Use label requirements** for additional manual control gates
- **Enable branch protection** rules to enforce review requirements
- **Monitor approval patterns** for unusual or suspicious activity

### Compliance & Audit
- **Review audit logs** regularly for unauthorized approval attempts
- **Document approval policies** and ensure team understanding
- **Test security controls** periodically with security team
- **Maintain compliance** with organizational security policies

## Support

If you encounter any issues or have questions:

- **[Open an issue](https://github.com/lekman/auto-approve-action/issues/new?template=bug_report.md)** for bugs or problems
- **[Request a feature](https://github.com/lekman/auto-approve-action/issues/new?template=feature_request.md)** for enhancements
- **[Check existing issues](https://github.com/lekman/auto-approve-action/issues)** for known problems and solutions

## Contributors

We welcome contributions from the community! If you would like to contribute to this project:

- **See our [Contributing Guide](https://github.com/lekman/auto-approve-action/blob/main/docs/CONTRIBUTING.md)** for development setup and pull request instructions
- **Review our [Code of Conduct](https://github.com/lekman/auto-approve-action/blob/main/docs/CODE_OF_CONDUCT.md)** for community guidelines

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/lekman/auto-approve-action/blob/main/LICENSE) file for details.

## Changelog

See [CHANGELOG.md](https://github.com/lekman/auto-approve-action/blob/main/CHANGELOG.md) for a detailed history of changes and releases.