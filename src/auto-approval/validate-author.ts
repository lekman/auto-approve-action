import type { CheckResult } from "./types.js";

/**
 * Normalise the two forms an App author is written in.
 *
 * The API reports a GitHub App's login as `name[bot]`, but `gh pr view
 * --json author` renders the same account as `app/name` — and that is where
 * people read it from when writing a workflow. This project's own docs and
 * workflow used the `app/` form against an exact comparison, so the check
 * could never pass for any App.
 *
 * Both forms now resolve to the same value. A human login is returned
 * unchanged, and `[bot]` is not appended to anything that lacks the `app/`
 * prefix, so `dependabot[bot]` still has to be written in full.
 */
const APP_PREFIX = "app/";

function normaliseAuthor(author: string): string {
	return author.startsWith(APP_PREFIX)
		? `${author.slice(APP_PREFIX.length)}[bot]`
		: author;
}

/**
 * Check whether the PR author is in the allowed authors list.
 *
 * Comparison is case-sensitive, on logins normalised as above.
 */
export function validateAuthor(author: string, allowedAuthors: string[]): CheckResult {
	const normalised = normaliseAuthor(author);
	const allowed = allowedAuthors.map(normaliseAuthor).includes(normalised);
	return {
		name: "Author",
		passed: allowed,
		message: allowed
			? `Author '${author}' is authorized for auto-approval`
			: `Author '${author}' is not in the allowed authors list`,
	};
}
