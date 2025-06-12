# Auto-Approve Action Examples

This document provides comprehensive examples and use cases for the Auto-Approve GitHub Action. Each example includes a complete workflow configuration and explanation of when to use it.

## Table of Contents

- [Basic Examples](#basic-examples)
  - [Minimal Configuration](#minimal-configuration)
  - [Single Author Approval](#single-author-approval)
  - [Multiple Authors](#multiple-authors)
- [Bot Integration](#bot-integration)
  - [Dependabot](#dependabot)
  - [Renovate](#renovate)
  - [Release Please](#release-please)
  - [Custom Bots](#custom-bots)
- [Label-Based Workflows](#label-based-workflows)
  - [Require All Labels](#require-all-labels)
  - [Require Any Label](#require-any-label)
  - [Exclude Labeled PRs](#exclude-labeled-prs)
- [Path-Based Approvals](#path-based-approvals)
  - [Documentation Only](#documentation-only)
  - [Configuration Files](#configuration-files)
  - [Exclude Sensitive Paths](#exclude-sensitive-paths)
  - [Multiple Path Patterns](#multiple-path-patterns)
- [Status Check Integration](#status-check-integration)
  - [Wait for All Checks](#wait-for-all-checks)
  - [Specific Check Requirements](#specific-check-requirements)
  - [Quick Approval with Timeout](#quick-approval-with-timeout)
- [Advanced Patterns](#advanced-patterns)
  - [Team-Based Workflows](#team-based-workflows)
  - [Emergency Hotfix Process](#emergency-hotfix-process)
  - [Scheduled Maintenance](#scheduled-maintenance)
  - [Monorepo Patterns](#monorepo-patterns)
- [Size and Complexity Limits](#size-and-complexity-limits)
  - [Small PRs Only](#small-prs-only)
  - [Different Limits by Type](#different-limits-by-type)
  - [Progressive Size Limits](#progressive-size-limits)
- [Security Patterns](#security-patterns)
  - [Restricted Approval Hours](#restricted-approval-hours)
  - [Multi-Stage Approval](#multi-stage-approval)
  - [Audit Trail Enhancement](#audit-trail-enhancement)

## Basic Examples

### Minimal Configuration

The simplest possible configuration that auto-approves PRs from a specific user.

```yaml
name: Auto Approve
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "trusted-developer"
```

### Single Author Approval

Auto-approve PRs from a single trusted contributor with basic settings.

```yaml
name: Auto Approve Trusted Contributor
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "john-doe"
          wait-for-checks: true
          max-wait-time: 30
```

### Multiple Authors

Auto-approve PRs from a team of trusted developers.

```yaml
name: Auto Approve Team PRs
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "alice,bob,charlie,dana"
          wait-for-checks: true
          required-checks: "CI / Test,CI / Lint"
```

## Bot Integration

### Dependabot

Auto-approve Dependabot PRs for minor and patch updates only.

```yaml
name: Auto Approve Dependabot
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    if: github.actor == 'dependabot[bot]'
    steps:
      - uses: actions/checkout@v4
      
      - name: Check for major update
        id: check-update
        uses: actions/github-script@v7
        with:
          script: |
            const pr = context.payload.pull_request;
            const isMajor = pr.title.includes('major');
            return !isMajor;
      
      - uses: lekman/auto-approve-action@v1
        if: steps.check-update.outputs.result == 'true'
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "dependabot[bot]"
          required-labels: "dependencies"
          wait-for-checks: true
          max-wait-time: 45
```

### Renovate

Auto-approve Renovate bot PRs with specific update types.

```yaml
name: Auto Approve Renovate
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    if: github.actor == 'renovate[bot]'
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "renovate[bot]"
          required-labels: "renovate,automerge"
          label-match-mode: "all"
          wait-for-checks: true
          merge-method: "squash"
```

### Release Please

Auto-approve Release Please PRs for automated releases.

```yaml
name: Auto Approve Release
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    # Only run for PRs from release-please branches
    if: startsWith(github.head_ref, 'release-please--')
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "app/release-please-bot"
          required-labels: "autorelease: pending"
          label-match-mode: "all"
          wait-for-checks: true
          max-wait-time: 10
          path-filters: ".github/release-manifest.json,**/CHANGELOG.md,**/package.json,**/package-lock.json"
          merge-method: "merge"
```

### Custom Bots

Auto-approve PRs from custom GitHub Apps or bots.

```yaml
name: Auto Approve Bot PRs
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "app/my-custom-bot,app/automation-bot"
          required-labels: "bot-pr"
          wait-for-checks: true
          path-filters: "config/**/*,!config/security/**"
```

## Label-Based Workflows

### Require All Labels

Auto-approve only when ALL specified labels are present.

```yaml
name: Auto Approve with All Labels
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "trusted-team"
          required-labels: "reviewed,tested,documented"
          label-match-mode: "all"
          wait-for-checks: true
```

### Require Any Label

Auto-approve when ANY of the specified labels is present.

```yaml
name: Auto Approve with Any Label
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "docs-team,content-team"
          required-labels: "documentation,typo-fix,content-update"
          label-match-mode: "any"
```

### Exclude Labeled PRs

Auto-approve only when certain labels are NOT present.

```yaml
name: Auto Approve Without Blocking Labels
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "dependabot[bot]"
          required-labels: "do-not-merge,work-in-progress,needs-review"
          label-match-mode: "none"
          wait-for-checks: true
```

## Path-Based Approvals

### Documentation Only

Auto-approve PRs that only change documentation files.

```yaml
name: Auto Approve Docs
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "docs-team,contributors"
          path-filters: "docs/**/*.md,README.md,*.md,LICENSE,CONTRIBUTING.md"
          wait-for-checks: false
```

### Configuration Files

Auto-approve configuration file updates from trusted sources.

```yaml
name: Auto Approve Config Updates
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "ops-team,platform-team"
          path-filters: |
            .github/**/*.yml,
            .github/**/*.yaml,
            config/**/*.json,
            config/**/*.yml,
            !config/secrets/**,
            !.github/workflows/security-*.yml
          wait-for-checks: true
          required-checks: "Config Validation"
```

### Exclude Sensitive Paths

Auto-approve all changes except those touching sensitive files.

```yaml
name: Auto Approve Non-Sensitive Changes
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "dependabot[bot],renovate[bot]"
          path-filters: |
            **/*,
            !.github/workflows/**,
            !**/security/**,
            !**/auth/**,
            !**/*secret*,
            !**/*token*,
            !**/*key*,
            !**/*.pem,
            !**/*.key
          wait-for-checks: true
```

### Multiple Path Patterns

Complex path patterns for specific project structures.

```yaml
name: Auto Approve Frontend Changes
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "frontend-team"
          path-filters: |
            src/components/**/*.tsx,
            src/components/**/*.ts,
            src/styles/**/*.css,
            src/styles/**/*.scss,
            public/**/*,
            !src/components/auth/**,
            !src/api/**
          required-labels: "frontend"
          wait-for-checks: true
          required-checks: "UI Tests,Lint"
```

## Status Check Integration

### Wait for All Checks

Wait for all status checks to complete before approving.

```yaml
name: Auto Approve After All Checks
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "trusted-bot"
          wait-for-checks: true
          max-wait-time: 60
```

### Specific Check Requirements

Wait for specific critical checks only.

```yaml
name: Auto Approve with Critical Checks
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "deployment-bot"
          wait-for-checks: true
          required-checks: |
            CI / Unit Tests,
            CI / Integration Tests,
            Security Scan,
            Code Coverage
          max-wait-time: 45
```

### Quick Approval with Timeout

Fast approval for time-sensitive updates with short timeout.

```yaml
name: Quick Auto Approve
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "hotfix-team"
          required-labels: "urgent,hotfix"
          label-match-mode: "all"
          wait-for-checks: true
          max-wait-time: 5
          merge-method: "merge"
```

## Advanced Patterns

### Team-Based Workflows

Different approval rules for different teams.

```yaml
name: Team-Based Auto Approval
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  frontend-approval:
    runs-on: ubuntu-latest
    if: contains(github.event.pull_request.labels.*.name, 'frontend')
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "frontend-team-1,frontend-team-2"
          path-filters: "src/frontend/**/*,public/**/*"
          required-checks: "Frontend Tests"
          wait-for-checks: true

  backend-approval:
    runs-on: ubuntu-latest
    if: contains(github.event.pull_request.labels.*.name, 'backend')
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "backend-team-1,backend-team-2"
          path-filters: "src/api/**/*,src/services/**/*"
          required-checks: "Backend Tests,API Tests"
          wait-for-checks: true

  infra-approval:
    runs-on: ubuntu-latest
    if: contains(github.event.pull_request.labels.*.name, 'infrastructure')
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "infra-team,platform-team"
          path-filters: "terraform/**/*,k8s/**/*,.github/workflows/**"
          required-checks: "Terraform Plan,Security Scan"
          wait-for-checks: true
          max-wait-time: 60
```

### Emergency Hotfix Process

Expedited approval for emergency fixes.

```yaml
name: Emergency Hotfix Approval
on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches:
      - main
      - 'release-*'

jobs:
  emergency-approve:
    runs-on: ubuntu-latest
    if: |
      contains(github.event.pull_request.labels.*.name, 'emergency') &&
      contains(github.event.pull_request.labels.*.name, 'hotfix')
    steps:
      - uses: actions/checkout@v4
      
      - name: Validate emergency PR
        uses: actions/github-script@v7
        with:
          script: |
            const pr = context.payload.pull_request;
            const files = await github.rest.pulls.listFiles({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: pr.number
            });
            
            // Ensure PR is small (emergency fixes should be focused)
            if (files.data.length > 5) {
              core.setFailed('Emergency PRs should contain 5 or fewer files');
            }
      
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "senior-dev-1,senior-dev-2,on-call-lead"
          required-labels: "emergency,hotfix,approved-by-lead"
          label-match-mode: "all"
          wait-for-checks: true
          max-wait-time: 10
          merge-method: "merge"
```

### Scheduled Maintenance

Auto-approve scheduled maintenance PRs during maintenance windows.

```yaml
name: Scheduled Maintenance Approval
on:
  pull_request:
    types: [opened, synchronize, reopened]
  schedule:
    # Run during maintenance window (Sundays 2-6 AM UTC)
    - cron: '0 2-6 * * 0'

jobs:
  maintenance-approve:
    runs-on: ubuntu-latest
    if: contains(github.event.pull_request.labels.*.name, 'scheduled-maintenance')
    steps:
      - uses: actions/checkout@v4
      
      - name: Check maintenance window
        id: check-window
        run: |
          hour=$(date -u +%H)
          day=$(date -u +%u)
          if [[ $day -eq 7 && $hour -ge 2 && $hour -lt 6 ]]; then
            echo "in-window=true" >> $GITHUB_OUTPUT
          else
            echo "in-window=false" >> $GITHUB_OUTPUT
          fi
      
      - uses: lekman/auto-approve-action@v1
        if: steps.check-window.outputs.in-window == 'true'
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "maintenance-bot,ops-team"
          required-labels: "scheduled-maintenance"
          path-filters: |
            scripts/maintenance/**/*,
            config/maintenance/**/*,
            .github/workflows/maintenance-*.yml
          wait-for-checks: true
```

### Monorepo Patterns

Auto-approve based on monorepo package ownership.

```yaml
name: Monorepo Package Approval
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  detect-packages:
    runs-on: ubuntu-latest
    outputs:
      packages: ${{ steps.detect.outputs.packages }}
    steps:
      - uses: actions/checkout@v4
      - id: detect
        run: |
          # Detect which packages changed
          packages=$(git diff --name-only origin/main...HEAD | grep -E '^packages/[^/]+/' | cut -d'/' -f2 | sort -u | jq -R -s -c 'split("\n")[:-1]')
          echo "packages=$packages" >> $GITHUB_OUTPUT

  package-approval:
    needs: detect-packages
    runs-on: ubuntu-latest
    strategy:
      matrix:
        package: ${{ fromJson(needs.detect-packages.outputs.packages) }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Get package owners
        id: owners
        run: |
          # Read CODEOWNERS for this package
          owners=$(grep "packages/${{ matrix.package }}" .github/CODEOWNERS | awk '{print $2}' | tr '\n' ',')
          echo "owners=$owners" >> $GITHUB_OUTPUT
      
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: ${{ steps.owners.outputs.owners }}
          path-filters: "packages/${{ matrix.package }}/**/*"
          required-labels: "package:${{ matrix.package }}"
          wait-for-checks: true
          required-checks: "${{ matrix.package }} Tests"
```

## Size and Complexity Limits

### Small PRs Only

Enforce small, focused PRs for better reviewability.

```yaml
name: Auto Approve Small PRs
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "trusted-team"
          max-files-changed: 10
          max-lines-added: 200
          max-lines-removed: 100
          max-total-lines: 300
          size-limit-message: "PR is too large. Please break it into smaller, focused changes."
          wait-for-checks: true
```

### Different Limits by Type

Apply different size limits based on PR type or labels.

```yaml
name: Auto Approve with Variable Size Limits
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  documentation-approval:
    runs-on: ubuntu-latest
    if: contains(github.event.pull_request.labels.*.name, 'documentation')
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "docs-team"
          path-filters: "docs/**/*,*.md"
          max-files-changed: 20
          max-total-lines: 500
          wait-for-checks: false

  feature-approval:
    runs-on: ubuntu-latest
    if: contains(github.event.pull_request.labels.*.name, 'feature')
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "dev-team"
          max-files-changed: 30
          max-lines-added: 1000
          max-lines-removed: 500
          max-total-lines: 1500
          wait-for-checks: true

  refactor-approval:
    runs-on: ubuntu-latest
    if: contains(github.event.pull_request.labels.*.name, 'refactor')
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "senior-devs"
          max-files-changed: 50
          max-lines-added: 2000
          max-lines-removed: 2000
          max-total-lines: 4000
          size-limit-message: "Large refactoring PRs require manual review."
          wait-for-checks: true
```

### Progressive Size Limits

Different size limits for different team members based on experience.

```yaml
name: Progressive Size Limits
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  junior-dev-approval:
    runs-on: ubuntu-latest
    if: contains(fromJson('["junior-dev-1", "junior-dev-2"]'), github.actor)
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "junior-dev-1,junior-dev-2"
          max-files-changed: 5
          max-lines-added: 100
          max-lines-removed: 50
          max-total-lines: 150
          size-limit-message: "Junior developer PRs exceeding size limits require senior review."
          required-labels: "junior-pr"
          wait-for-checks: true

  mid-level-approval:
    runs-on: ubuntu-latest
    if: contains(fromJson('["mid-dev-1", "mid-dev-2", "mid-dev-3"]'), github.actor)
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "mid-dev-1,mid-dev-2,mid-dev-3"
          max-files-changed: 20
          max-lines-added: 500
          max-lines-removed: 300
          max-total-lines: 800
          wait-for-checks: true

  senior-dev-approval:
    runs-on: ubuntu-latest
    if: contains(fromJson('["senior-dev-1", "senior-dev-2"]'), github.actor)
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "senior-dev-1,senior-dev-2"
          max-files-changed: 50
          max-lines-added: 2000
          max-lines-removed: 1500
          max-total-lines: 3500
          wait-for-checks: true
```

### Dependency Update Size Limits

Restrict size of dependency updates to avoid large, risky changes.

```yaml
name: Auto Approve Limited Dependency Updates
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    if: github.actor == 'dependabot[bot]'
    steps:
      - uses: actions/checkout@v4
      
      - name: Check update size
        id: check-size
        uses: actions/github-script@v7
        with:
          script: |
            const pr = context.payload.pull_request;
            
            // Check if it's a major update by title
            const isMajor = pr.title.toLowerCase().includes('major');
            
            // Get file list to check for lock file changes
            const files = await github.rest.pulls.listFiles({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: pr.number
            });
            
            const lockFileChanged = files.data.some(f => 
              f.filename.includes('package-lock.json') || 
              f.filename.includes('yarn.lock')
            );
            
            return { isMajor, lockFileChanged };
      
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "dependabot[bot]"
          required-labels: "dependencies"
          # Stricter limits for major updates
          max-files-changed: ${{ fromJson(steps.check-size.outputs.result).isMajor && '5' || '20' }}
          max-lines-added: ${{ fromJson(steps.check-size.outputs.result).isMajor && '1000' || '5000' }}
          max-lines-removed: ${{ fromJson(steps.check-size.outputs.result).isMajor && '500' || '2000' }}
          size-limit-message: "Dependency update is too large. Manual review required for security."
          wait-for-checks: true
```

### Combined Path and Size Restrictions

Use both path filters and size limits for fine-grained control.

```yaml
name: Auto Approve with Path and Size Limits
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  config-changes:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "config-team"
          path-filters: |
            config/**/*.yml,
            config/**/*.json,
            .github/workflows/*.yml,
            !config/security/**,
            !.github/workflows/deploy-*.yml
          max-files-changed: 10
          max-total-lines: 200
          size-limit-message: "Configuration changes exceeding size limits require security review."
          wait-for-checks: true

  test-updates:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "qa-team,dev-team"
          path-filters: |
            tests/**/*,
            **/*.test.js,
            **/*.spec.ts,
            !tests/e2e/**
          max-files-changed: 30
          max-lines-added: 1500
          max-lines-removed: 1000
          size-limit-message: "Test changes are too large. Consider splitting into multiple PRs."
          required-labels: "tests"
          wait-for-checks: true
```

### Zero-Tolerance Size Limits

Enforce strict size limits for critical paths.

```yaml
name: Strict Size Limits for Critical Code
on:
  pull_request:
    types: [opened, synchronize, reopened]
    paths:
      - 'src/auth/**'
      - 'src/payments/**'
      - 'src/security/**'

jobs:
  critical-path-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Check critical paths
        uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "security-team-lead"
          path-filters: |
            src/auth/**/*,
            src/payments/**/*,
            src/security/**/*
          # Very restrictive limits for critical code
          max-files-changed: 3
          max-lines-added: 50
          max-lines-removed: 30
          max-total-lines: 80
          size-limit-message: |
            Critical security paths require careful review.
            PRs must be small and focused.
            Consider breaking this into smaller changes.
          required-labels: "security-review,approved-by-lead"
          label-match-mode: "all"
          wait-for-checks: true
          required-checks: "Security Scan,Vulnerability Check,Code Quality"
```

## Security Patterns

### Restricted Approval Hours

Only auto-approve during business hours to ensure oversight.

```yaml
name: Business Hours Auto Approval
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Check business hours
        id: check-hours
        run: |
          hour=$(date -u +%H)
          day=$(date -u +%u)
          # Monday-Friday, 9 AM - 5 PM UTC
          if [[ $day -ge 1 && $day -le 5 && $hour -ge 9 && $hour -lt 17 ]]; then
            echo "business-hours=true" >> $GITHUB_OUTPUT
          else
            echo "business-hours=false" >> $GITHUB_OUTPUT
          fi
      
      - uses: lekman/auto-approve-action@v1
        if: steps.check-hours.outputs.business-hours == 'true'
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "trusted-team"
          wait-for-checks: true
          dry-run: ${{ steps.check-hours.outputs.business-hours != 'true' }}
```

### Multi-Stage Approval

Require multiple approval stages for sensitive changes.

```yaml
name: Multi-Stage Approval
on:
  pull_request:
    types: [opened, synchronize, reopened, labeled]

jobs:
  stage-1-technical:
    runs-on: ubuntu-latest
    if: contains(github.event.pull_request.labels.*.name, 'needs-approval')
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.TECH_LEAD_TOKEN }}
          allowed-authors: "dev-team"
          required-labels: "tech-reviewed"
          wait-for-checks: true
          dry-run: true
      
      - name: Add stage 2 label
        if: success()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              labels: ['stage-2-ready']
            });

  stage-2-security:
    runs-on: ubuntu-latest
    needs: stage-1-technical
    if: contains(github.event.pull_request.labels.*.name, 'stage-2-ready')
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.SECURITY_TEAM_TOKEN }}
          allowed-authors: "security-team"
          required-labels: "security-reviewed"
          wait-for-checks: true
          required-checks: "Security Scan,Vulnerability Check"

  final-approval:
    runs-on: ubuntu-latest
    needs: stage-2-security
    steps:
      - uses: actions/checkout@v4
      - uses: lekman/auto-approve-action@v1
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "release-manager"
          required-labels: "tech-reviewed,security-reviewed,ready-to-merge"
          label-match-mode: "all"
          wait-for-checks: true
          merge-method: "squash"
```

### Audit Trail Enhancement

Enhanced audit trail with external logging.

```yaml
name: Auto Approve with Audit
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  auto-approve:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Pre-approval audit
        uses: actions/github-script@v7
        with:
          script: |
            const pr = context.payload.pull_request;
            const auditData = {
              timestamp: new Date().toISOString(),
              pr_number: pr.number,
              pr_title: pr.title,
              author: pr.user.login,
              branch: pr.head.ref,
              files_changed: pr.changed_files,
              additions: pr.additions,
              deletions: pr.deletions
            };
            
            // Log to workflow
            console.log('Pre-approval audit:', JSON.stringify(auditData, null, 2));
            
            // Could also send to external logging service
            // await fetch('https://audit-api.example.com/log', {
            //   method: 'POST',
            //   body: JSON.stringify(auditData)
            // });
      
      - uses: lekman/auto-approve-action@v1
        id: approve
        with:
          github-token: ${{ secrets.CODE_OWNER_TOKEN }}
          allowed-authors: "trusted-bot"
          wait-for-checks: true
      
      - name: Post-approval audit
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const auditData = {
              timestamp: new Date().toISOString(),
              pr_number: context.payload.pull_request.number,
              approval_status: '${{ steps.approve.outputs.approved }}',
              author_allowed: '${{ steps.approve.outputs.author-allowed }}',
              labels_match: '${{ steps.approve.outputs.labels-match }}',
              checks_status: '${{ steps.approve.outputs.checks-status }}'
            };
            
            // Create audit issue
            if ('${{ steps.approve.outputs.approved }}' === 'true') {
              await github.rest.issues.create({
                owner: context.repo.owner,
                repo: context.repo.repo,
                title: `Audit: PR #${context.payload.pull_request.number} auto-approved`,
                body: `## Auto-Approval Audit Record\n\n\`\`\`json\n${JSON.stringify(auditData, null, 2)}\n\`\`\``,
                labels: ['audit', 'auto-approved']
              });
            }
```

## Best Practices

1. **Always use specific version tags** (`@v1`) instead of `@main` for production workflows
2. **Store tokens securely** in GitHub Secrets, never hardcode them
3. **Use descriptive allowed-authors lists** and document why each author is trusted
4. **Implement appropriate wait times** based on your typical CI/CD duration
5. **Use path filters** to limit the scope of auto-approval
6. **Combine with branch protection rules** for additional security
7. **Regular audit** approved PRs to ensure the system isn't being abused
8. **Use dry-run mode** to test new configurations before enabling auto-approval
9. **Monitor for suspicious patterns** in auto-approved PRs
10. **Document your auto-approval policies** so team members understand the rules

## Troubleshooting

### Common Issues

1. **Action fails with "Author not allowed"**
   - Verify the PR author is in the `allowed-authors` list
   - Check for typos in usernames
   - For bots, ensure you're using the correct format (e.g., `dependabot[bot]` or `app/my-bot`)

2. **Timeout waiting for checks**
   - Increase `max-wait-time` if your CI takes longer
   - Use `required-checks` to wait only for specific checks
   - Check if the checks are actually running

3. **Path filters not working**
   - Verify glob patterns are correct
   - Use `**` for recursive directory matching
   - Test patterns with the dry-run mode first

4. **Token permission errors**
   - Ensure the token has `repo` and `pull_request:write` permissions
   - For GitHub Apps, verify the app has the necessary permissions
   - Check if branch protection rules are blocking the approval

For more help, please [open an issue](https://github.com/lekman/auto-approve-action/issues/new).