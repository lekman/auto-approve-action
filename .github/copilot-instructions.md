# Copilot instructions

`lekman/auto-approve-action` is a composite GitHub Action that approves and
merges pull requests when the author, labels, changed paths and size all pass.
It is TypeScript, built with Bun, and `dist/auto-approve.js` is committed
because GitHub Actions runs it directly.

## Pull requests to skip

Stop and post no review for pull requests from these branches. They are
machine-generated, their contents are mechanical, and a review comment on them
is noise that trains people to skim the ones that matter.

- `release-please--*` — a version bump and a generated changelog. The content
  is produced from commit messages that were already reviewed when they landed.
- `dependabot/*` — a dependency or action version bump. What matters is whether
  the upgrade builds and passes, which continuous integration answers, not
  whether the diff reads well.

Exit early on those. Everything below applies to human pull requests.

## What to look at closely

- **This action grants merge rights.** A change that widens what it will
  approve deserves more scrutiny than a change that narrows it. Ask what a
  malicious pull request could get past the new logic.
- **Author matching has two spellings.** The API reports a GitHub App as
  `name[bot]`; `gh pr view --json author` prints `app/name`. Both must resolve
  to the same value, and a plain login must never gain a `[bot]` suffix.
- **`dist/` must be rebuilt when `src/` changes.** A pull request that edits
  source without a matching `dist` change ships nothing.
- **Validation belongs in `src/auto-approval/`**, which is pure and testable
  without mocks. Only `src/github/github.system.ts` performs I/O.

## What not to comment on

- Formatting and import order. Prettier and the typecheck settle those.

## A failure mode worth naming

`continue-on-error: true` on the approve step let a 401 from an expired token
report as success for three weeks. Treat any new `continue-on-error` as a
question: what would this hide, and how would anyone find out?
