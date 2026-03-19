# Contributor Guide

Thank you for your interest in contributing to the Auto-Approve GitHub Action!

## Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/lekman/auto-approve-action.git
   cd auto-approve-action
   ```

2. **Install dependencies (requires [Bun](https://bun.sh)):**
   ```bash
   bun install
   ```

3. **Run tests:**
   ```bash
   bun run test             # unit tests
   bun run test:coverage    # with coverage (80% threshold)
   bun run verify           # typecheck + test:coverage
   ```

4. **Build:**
   ```bash
   bun run build            # generates dist/auto-approve.js
   ```
   The compiled `dist/auto-approve.js` must be committed — GitHub Actions runs it directly via `node`.

5. **Test the action end-to-end:**
   Reference your branch in a test workflow, or use [`nektos/act`](https://github.com/nektos/act) to run workflows locally.

## Project Structure

```
src/
  auto-approval/          # Pure validation logic (no I/O)
    types.ts              # Shared interfaces
    validate-inputs.ts    # Env var parsing
    validate-author.ts    # Author allowlist
    validate-labels.ts    # Label matching (all/any/none)
    validate-paths.ts     # Glob pattern matching
    validate-size.ts      # PR size thresholds
    summary.ts            # Markdown summary generation
    index.ts              # Barrel exports
  github/
    github.system.ts      # GitHub REST/GraphQL API adapter
    index.ts              # Barrel export
  auto-approve.ts         # Entry point
tests/unit/               # Unit tests (bun:test)
dist/auto-approve.js      # Compiled output (committed)
```

## Commit Signing Requirement

All commits must be [signed and verified](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits). You can use GPG, SSH, or S/MIME keys.

## Pull Request Process

1. Fork the repository and create a feature branch
2. Make changes, run `bun run verify` to confirm tests pass
3. Run `bun run build` and commit the updated `dist/auto-approve.js`
4. Open a pull request — all CI checks must pass
5. At least one code owner must approve the merge

## CI/CD

[![CI](https://github.com/lekman/auto-approve-action/actions/workflows/ci.yml/badge.svg)](https://github.com/lekman/auto-approve-action/actions/workflows/ci.yml)

- Unit tests run via `bun run verify` (typecheck + test with coverage)
- Integration tests run the action via `uses: ./` in PR context
- Releases managed by `release-please` bot

## Security

[![Security](https://github.com/lekman/auto-approve-action/actions/workflows/security.yml/badge.svg)](https://github.com/lekman/auto-approve-action/actions/workflows/security.yml)

- CodeQL scans on every push/PR and daily schedule
- Dependabot monitors npm and GitHub Actions dependencies

## Secrets Required (for maintainers)

- `APP_ID` and `APP_PRIVATE_KEY` for GitHub App token generation in CI
- `CODE_OWNER_TOKEN` for approving release PRs
