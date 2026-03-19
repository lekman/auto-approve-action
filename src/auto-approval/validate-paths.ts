import type { CheckResult } from "./types.js";

/**
 * Convert a glob pattern to a regular expression string.
 *
 * Rules:
 * - `**` matches anything including path separators
 * - `*` matches any characters except `/`
 * - `.` and `+` are escaped as literals
 */
function globToRegex(pattern: string): RegExp {
	if (pattern === "**/*") {
		return /^.*$/;
	}

	// Escape regex-special chars (except * which is handled below)
	let re = pattern
		.replace(/\./g, "\\.")
		.replace(/\+/g, "\\+")
		.replace(/\?/g, "\\?");

	// Handle ** in various positions using a placeholder
	// /**/ in the middle — matches zero or more path segments
	re = re.replace(/\/\*\*\//g, "/(STARSTAR/)?");
	// /** at the end
	re = re.replace(/\/\*\*/g, "/STARSTAR");
	// **/ at the beginning
	re = re.replace(/\*\*\//g, "STARSTAR/");
	// standalone **
	re = re.replace(/\*\*/g, "STARSTAR");
	// single * — any chars except /
	re = re.replace(/\*/g, "[^/]*");
	// expand STARSTAR placeholder
	re = re.replace(/STARSTAR/g, ".*");

	return new RegExp(`^${re}$`);
}

/**
 * Return true if the file path matches the given glob pattern.
 * An exact string match is also accepted.
 */
export function matchesPattern(file: string, pattern: string): boolean {
	if (file === pattern) {
		return true;
	}
	return globToRegex(pattern).test(file);
}

/**
 * Validate changed file paths against a list of path filter patterns.
 *
 * Patterns prefixed with `!` are exclusion patterns; all others are inclusion
 * patterns. Exclusions are evaluated first and take priority.
 *
 * Logic:
 * - If only exclusion patterns exist: fail when all files match exclusions.
 * - If inclusion patterns exist: at least one file must match an inclusion
 *   pattern (after excluded files are removed).
 * - If no filters are provided: the check passes automatically.
 */
export function validatePaths(filePaths: string[], pathFilters: string[]): CheckResult {
	if (pathFilters.length === 0) {
		return {
			name: "Paths",
			passed: true,
			message: "No path filters configured",
		};
	}

	const includePatterns: string[] = [];
	const excludePatterns: string[] = [];

	for (const filter of pathFilters) {
		if (filter.startsWith("!")) {
			excludePatterns.push(filter.slice(1));
		} else {
			includePatterns.push(filter);
		}
	}

	if (filePaths.length === 0) {
		return {
			name: "Paths",
			passed: true,
			message: "No files changed",
		};
	}

	const matchedFiles: string[] = [];
	const excludedFiles: string[] = [];

	for (const file of filePaths) {
		const isExcluded = excludePatterns.some((pattern) => matchesPattern(file, pattern));
		if (isExcluded) {
			excludedFiles.push(file);
			continue;
		}

		if (includePatterns.length > 0) {
			const isIncluded = includePatterns.some((pattern) => matchesPattern(file, pattern));
			if (isIncluded) {
				matchedFiles.push(file);
			}
		} else {
			// No inclusion patterns — all non-excluded files count as matched
			matchedFiles.push(file);
		}
	}

	// Only-exclusion mode: fail when every file was excluded
	if (includePatterns.length === 0 && excludePatterns.length > 0) {
		const effectiveFiles = filePaths.length - excludedFiles.length;
		if (effectiveFiles === 0) {
			return {
				name: "Paths",
				passed: false,
				message: "All files in PR match exclusion patterns",
			};
		}
		return {
			name: "Paths",
			passed: true,
			message: `${matchedFiles.length} file(s) remain after applying exclusion patterns`,
		};
	}

	// Inclusion mode: at least one file must match
	if (matchedFiles.length === 0) {
		return {
			name: "Paths",
			passed: false,
			message: "No files match the required inclusion patterns",
		};
	}

	return {
		name: "Paths",
		passed: true,
		message: `${matchedFiles.length} file(s) match the required path patterns`,
	};
}
