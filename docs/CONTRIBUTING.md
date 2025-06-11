# Contributor Guide

Thank you for your interest in contributing to the Auto-Approve GitHub Action! We welcome contributions from the community to improve features, fix bugs, and enhance documentation.

## Commit Signing Requirement

**All commits to this repository must be [signed and verified](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits).**

### Why are signed commits required?
- Signed commits help ensure the authenticity and integrity of code contributions.
- They protect the project from unauthorized or malicious changes by verifying the identity of contributors.
- This is an important security and compliance measure for open source and collaborative projects.

### How to set up commit signing
- Follow GitHub's official guide: [Signing commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits)
- You can use GPG, SSH, or S/MIME keys to sign your commits.
- After setup, make sure your commits show as "Verified" on GitHub.

## Feature Requests

If you have an idea for a new feature, please [submit a feature request](https://github.com/lekman/auto-approve-action/issues/new?template=feature_request.md) using our GitHub issue template.

## Getting Started with Development

1. **Clone the repository:**
   ```bash
   git clone https://github.com/lekman/auto-approve-action.git
   cd auto-approve-action
   ```

2. **Open the project in your editor:**
   ```bash
   code .
   ```

3. **Make changes:**
   - Edit the shell scripts (`/scripts/`), or the composite action files (see `action.yml`).
   - This repository does not require dependency installation; it is a pure GitHub Action repo.

4. **Test your changes:**
   - The recommended way to test changes is to reference your local or branch version of the action in a test repository's workflow, or use a tool like [`nektos/act`](https://github.com/nektos/act) to run workflows locally.

## Pull Request Process

1. **Fork the repository**
   - Click the "Fork" button on the [GitHub repo](https://github.com/lekman/auto-approve-action) page.

2. **Clone your fork and create a new branch**
   - Make your changes in a feature branch.

3. **Push your changes to your fork**

4. **Open a pull request**
   - Go to your fork on GitHub and click "Compare & pull request".
   - Fill in a clear description of your changes.

5. **Requirements for merging**
   - All CI checks must pass.
   - At least one code owner must approve the merge. See the [CODEOWNERS file](../.github/CODEOWNERS) for details.

## Continuous Integration (CI)
- Every pull request and push runs bash-based test scripts via GitHub Actions workflows.
- See `.github/workflows/` for workflow definitions and `/scripts` for the test scripts themselves.
- If you add a new test script, please document its purpose and usage in the script file and/or in the repository documentation.
- All checks must pass before merging.

## Release Process
- Releases are managed by the `release-please` bot, which creates release PRs and tags.
- The `auto-approve-action` is used in workflows to automate PR approvals for trusted authors and labels.
- When a release is created, the action is published and the major version tag is updated automatically.

## Security Analysis
- Code is regularly scanned for vulnerabilities using GitHub CodeQL (`.github/workflows/codeql.yml`).
- Security analysis runs on every push/PR to `main` and on a daily schedule.

## Requirements for Merging
- All CI checks must pass.
- Code must be reviewed and approved by a code owner.

## Secrets Required (for maintainers)
- `CODE_OWNER_TOKEN` for approving PRs in workflows.
- `NPM_TOKEN` for publishing packages (if applicable).

## Local Settings
- Shared settings for the project are stored in the [.vscode](../.vscode) folder.

## Additional Resources
- See the [README.md](../README.md) for usage and configuration details.
- Review the [Code of Conduct](https://github.com/lekman/auto-approve-action/blob/main/docs/CODE_OF_CONDUCT.md) for community guidelines.

Thank you for helping make Auto-Approve GitHub Action better!
