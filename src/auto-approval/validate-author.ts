import type { CheckResult } from "./types.js";

/**
 * Check whether the PR author is in the allowed authors list.
 * Comparison is exact and case-sensitive.
 */
export function validateAuthor(author: string, allowedAuthors: string[]): CheckResult {
	const allowed = allowedAuthors.includes(author);
	return {
		name: "Author",
		passed: allowed,
		message: allowed
			? `Author '${author}' is authorized for auto-approval`
			: `Author '${author}' is not in the allowed authors list`,
	};
}
