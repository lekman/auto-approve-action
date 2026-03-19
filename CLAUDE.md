# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A composite GitHub Action (TypeScript/Bun) that auto-approves and optionally auto-merges pull requests. Validation runs as a single `node dist/auto-approve.js` invocation with a pipeline: input parsing → author verification → label matching → path filtering → size checking → approval execution.

Two authentication modes (transparent to the action — both provide a token via `github-token` input):
1. **GITHUB_TOKEN** — repo settings allow Actions to approve PRs natively
2. **GitHub App** — caller generates token externally via `actions/create-github-app-token`

## Development Commands

```bash
bun install              # install dependencies
bun run test             # run unit tests
bun run test:coverage    # run tests with coverage (80% threshold)
bun run typecheck        # type check with tsc --noEmit
bun run verify           # typecheck + test:coverage
bun run build            # build dist/auto-approve.js (committed to repo)
```

## Architecture

### Clean Architecture Pattern

Source follows a strict separation:

- `src/auto-approval/` — Pure validation functions (no I/O, no fetch, no process.env). Fully testable without mocks.
- `src/github/github.system.ts` — GitHub REST/GraphQL API adapter. All I/O lives here. Excluded from coverage.
- `src/auto-approve.ts` — Entry point. Reads env vars, calls system layer, passes data to validators.

### Key Files

| File | Purpose |
|------|---------|
| `src/auto-approval/types.ts` | All shared interfaces |
| `src/auto-approval/validate-inputs.ts` | `parseConfig()` — env vars → typed ActionConfig |
| `src/auto-approval/validate-author.ts` | Author allowlist check |
| `src/auto-approval/validate-labels.ts` | Label matching (all/any/none modes) |
| `src/auto-approval/validate-paths.ts` | Glob pattern matching with `!` exclusions |
| `src/auto-approval/validate-size.ts` | PR size threshold checks |
| `src/auto-approval/summary.ts` | GITHUB_STEP_SUMMARY markdown generation |
| `src/github/github.system.ts` | GitHub API calls (fetch, native `fetch`) |
| `src/auto-approve.ts` | Entry point orchestrator |

### Conventions

- `*.system.ts` suffix = I/O wrapper, excluded from coverage via `bunfig.toml`
- `index.ts` = barrel exports only, no logic
- Static class namespaces group related pure functions (e.g., `AutoApproval.validate()`)
- Tests use `bun:test` with Arrange-Act-Assert pattern
- Build output `dist/auto-approve.js` is committed (GitHub Actions runs it via `node`)
- Commits must be signed (GPG or SSH)
- Releases managed by `release-please` bot (see `.github/workflows/cd.yml`)
