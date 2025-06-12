# Auto-Approve GitHub Action

Auto-Approve GitHub Action is a composite action that brings automated pull request approval to your GitHub workflow. Designed for development teams and DevOps engineers, this action enables you to automatically approve qualified PRs from trusted sources while maintaining lifecycle controls through validation. The project aims to accelerate development velocity, reduce manual approval bottlenecks, and maintain an audit trail for compliance requirements.

Key features include:

- **Workflow Validation** - Author allow lists, label requirements, and status check verification
- **Flexible Configuration** - Customizable approval criteria for different workflow scenarios
- **Audit Trails** - Detailed logging and approval decision documentation
- **Composite Action Architecture** - Reusable across multiple repositories and teams
- **GitHub App/PAT Support** - Secure token-based authentication with code owner privileges

## Usage

### Prerequisites:
- A GitHub Personal Access Token (PAT) or GitHub App token with `repo` and `pull_requests:write` permissions
- Code owner privileges or admin access for the token owner
- Existing CI/CD workflows for status check validation
- **Repository Settings**: If using auto-merge, ensure "Allow auto-merge" is enabled in your repository settings (Settings → General → Pull Requests)

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
```

**Path-Based Approval for Documentation:**
```yaml
allowed-authors: 'docs-team, contributors'
path-filters: 'docs/**/*.md,README.md,*.md'
label-match-mode: 'none'
```

**Security-Sensitive Path Exclusion:**
```yaml
allowed-authors: 'dependabot[bot]'
path-filters: '**/*,!.github/**/*,!scripts/**/*.sh,!**/security/**'
label-match-mode: 'none'
```

**PR Size Limits:**
```yaml
allowed-authors: 'dev-team, contributors'
max-files-changed: '20'
max-lines-added: '500'
max-lines-removed: '300'
max-total-lines: '800'
size-limit-message: 'This PR is too large for auto-approval. Please break it into smaller PRs.'
```

**Small Documentation Updates Only:**
```yaml
allowed-authors: 'docs-team'
path-filters: 'docs/**/*.md,*.md'
max-files-changed: '5'
max-total-lines: '100'
label-match-mode: 'none'
```

**Release Please Automation:**
```yaml
# .github/workflows/approve-release.yml
name: Auto Approve Release Please PR

permissions:
  contents: read
  pull-requests: write

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    # Only run for PRs from release-please branches
    if: startsWith(github.head_ref, 'release-please--')
    steps:
      - name: Auto Approve Release PR
        uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: 'app/release-please-bot'
          required-labels: 'autorelease: pending'
          label-match-mode: 'all'
          # Only allow changes to release files
          path-filters: '.github/release-manifest.json,**/CHANGELOG.md,CHANGELOG.md'
```

This configuration works best when combined with a CODEOWNERS file:
```
# .github/CODEOWNERS
# Default owner for all files
* @your-team

# Release files can be approved by the bot
/CHANGELOG.md @app/release-please-bot
/.github/release-manifest.json @app/release-please-bot
```

## Configuration Reference

### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `github-token` | ✅ | - | GitHub token with repo and PR write permissions |
| `allowed-authors` | ✅ | - | Comma-separated list of GitHub usernames allowed for auto-approval |
| `required-labels` | ❌ | `''` | Comma-separated list of required PR labels |
| `label-match-mode` | ❌ | `'all'` | How to match labels: `all`, `any`, or `none` |
| `silent` | ❌ | `'false'` | Suppress job summary output |
| `dry-run` | ❌ | `'false'` | Test mode - performs all checks but skips actual approval |
| `merge-method` | ❌ | `'merge'` | Auto-merge method: `merge`, `squash`, or `rebase` |
| `path-filters` | ❌ | `''` | File path patterns for conditional approval (supports glob patterns and ! for exclusion) |
| `max-files-changed` | ❌ | `'0'` | Maximum number of files that can be changed in the PR (0 = no limit) |
| `max-lines-added` | ❌ | `'0'` | Maximum number of lines that can be added in the PR (0 = no limit) |
| `max-lines-removed` | ❌ | `'0'` | Maximum number of lines that can be removed in the PR (0 = no limit) |
| `max-total-lines` | ❌ | `'0'` | Maximum total lines changed (added + removed) in the PR (0 = no limit) |
| `size-limit-message` | ❌ | `'PR exceeds configured size limits'` | Custom message to display when PR exceeds size limits |

### Outputs

| Output | Description |
|--------|-------------|
| `approved` | Whether the PR was successfully approved |
| `author-allowed` | Whether the PR author is in the allowed list |
| `labels-match` | Whether the PR labels meet requirements |
| `paths-match` | Whether the PR file paths meet requirements |

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
- **Configure repository settings** appropriately:
  - Enable "Allow auto-merge" to enable auto-approval for PRs
  - Set up branch protection rules to require status checks before merging
  - Consider requiring PR reviews from code owners for sensitive paths

### Compliance & Audit
- **Review audit logs** regularly for unauthorized approval attempts
- **Document approval policies** and ensure team understanding
- **Test security controls** periodically with security team
- **Maintain compliance** with organizational security policies

## Documentation

- **[Examples](docs/EXAMPLES.md)** - Comprehensive examples for various scenarios
- **[Use Cases](docs/USE_CASES.md)** - Common use cases and implementation strategies
- **[Contributing Guide](docs/CONTRIBUTING.md)** - How to contribute to the project
- **[Setup GitHub App](docs/SETUP_GITHUB_APP.md)** - Guide for setting up a GitHub App for authentication
- **[Changelog](https://github.com/lekman/auto-approve-action/blob/main/CHANGELOG.md)** - Detailed history of changes and releases

## Support

If you encounter any issues or have questions:

- **[Open an issue](https://github.com/lekman/auto-approve-action/issues/new?template=bug_report.md)** for bugs or problems
- **[Request a feature](https://github.com/lekman/auto-approve-action/issues/new?template=feature_request.md)** for enhancements
- **[Check existing issues](https://github.com/lekman/auto-approve-action/issues?q=is%3Aissue)** for known problems and solutions

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/lekman/auto-approve-action/blob/main/LICENSE) file for details.
