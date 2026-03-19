import type { ActionConfig } from "./types.js";

/**
 * Split a comma-separated string into trimmed, non-empty items.
 */
export function parseCSV(value: string): string[] {
	if (value.trim() === "") {
		return [];
	}
	return value.split(",").map((item) => item.trim());
}

/**
 * Return true if the string is a valid CSV list: no leading/trailing commas,
 * no double commas, and no empty items after trimming.
 */
function isValidCSV(value: string): boolean {
	if (value === "") {
		return true;
	}
	if (value.startsWith(",") || value.endsWith(",") || value.includes(",,")) {
		return false;
	}
	const items = value.split(",").map((s) => s.trim());
	return items.every((item) => item.length > 0);
}

/**
 * Parse and validate a non-negative integer from a string.
 * Returns 0 if the value is empty or undefined (treated as "no limit").
 * Throws if the value is present but invalid.
 */
function parseNonNegativeInt(value: string | undefined, name: string): number {
	if (value === undefined || value === "") {
		return 0;
	}
	if (!/^\d+$/.test(value) || parseInt(value, 10) < 0) {
		throw new Error(`'${name}' must be a non-negative integer (got: ${value})`);
	}
	return parseInt(value, 10);
}

/**
 * Parse environment variables into an ActionConfig.
 *
 * Throws a descriptive error for any invalid or missing required input.
 */
export function parseConfig(env: Record<string, string | undefined>): ActionConfig {
	const githubToken = env["GITHUB_TOKEN"] ?? env["GH_TOKEN"];
	if (!githubToken) {
		throw new Error("GITHUB_TOKEN is required but not set");
	}

	const repository = env["GITHUB_REPOSITORY"];
	if (!repository) {
		throw new Error("GITHUB_REPOSITORY is required but not set");
	}

	const prNumberRaw = env["PR_NUMBER"];
	if (!prNumberRaw) {
		throw new Error("PR_NUMBER is required but not set");
	}
	if (!/^[1-9]\d*$/.test(prNumberRaw)) {
		throw new Error(`PR_NUMBER must be a positive integer (got: ${prNumberRaw})`);
	}
	const prNumber = parseInt(prNumberRaw, 10);

	const allowedAuthorsRaw = env["ALLOWED_AUTHORS"] ?? "";
	if (!allowedAuthorsRaw) {
		throw new Error("ALLOWED_AUTHORS is required but not set");
	}
	if (!isValidCSV(allowedAuthorsRaw)) {
		throw new Error("ALLOWED_AUTHORS must be a valid comma-separated list of GitHub usernames");
	}
	const allowedAuthors = parseCSV(allowedAuthorsRaw);

	const requiredLabelsRaw = env["REQUIRED_LABELS"] ?? "";
	if (requiredLabelsRaw && !isValidCSV(requiredLabelsRaw)) {
		throw new Error("REQUIRED_LABELS must be a valid comma-separated list when provided");
	}
	const requiredLabels = parseCSV(requiredLabelsRaw);

	const labelMatchModeRaw = env["LABEL_MATCH_MODE"] ?? "all";
	if (labelMatchModeRaw !== "all" && labelMatchModeRaw !== "any" && labelMatchModeRaw !== "none") {
		throw new Error(`LABEL_MATCH_MODE must be one of: all, any, none (got: ${labelMatchModeRaw})`);
	}
	const labelMatchMode = labelMatchModeRaw as "all" | "any" | "none";

	if (labelMatchMode !== "none" && requiredLabels.length === 0) {
		throw new Error(
			`When LABEL_MATCH_MODE is '${labelMatchMode}', REQUIRED_LABELS must be provided`,
		);
	}

	const mergeMethodRaw = env["MERGE_METHOD"] ?? "merge";
	if (mergeMethodRaw !== "merge" && mergeMethodRaw !== "squash" && mergeMethodRaw !== "rebase") {
		throw new Error(
			`MERGE_METHOD must be one of: merge, squash, rebase (got: ${mergeMethodRaw})`,
		);
	}
	const mergeMethod = mergeMethodRaw as "merge" | "squash" | "rebase";

	const pathFiltersRaw = env["PATH_FILTERS"] ?? "";
	if (pathFiltersRaw && !isValidCSV(pathFiltersRaw)) {
		throw new Error("PATH_FILTERS must be a valid comma-separated list when provided");
	}
	const pathFilters = parseCSV(pathFiltersRaw);

	const maxFilesChanged = parseNonNegativeInt(env["MAX_FILES_CHANGED"], "MAX_FILES_CHANGED");
	const maxLinesAdded = parseNonNegativeInt(env["MAX_LINES_ADDED"], "MAX_LINES_ADDED");
	const maxLinesRemoved = parseNonNegativeInt(env["MAX_LINES_REMOVED"], "MAX_LINES_REMOVED");
	const maxTotalLines = parseNonNegativeInt(env["MAX_TOTAL_LINES"], "MAX_TOTAL_LINES");

	const sizeLimitMessage = env["SIZE_LIMIT_MESSAGE"] ?? "PR exceeds configured size limits";

	const silentRaw = env["SILENT"] ?? "false";
	if (silentRaw !== "true" && silentRaw !== "false") {
		throw new Error(`SILENT must be 'true' or 'false' (got: ${silentRaw})`);
	}
	const silent = silentRaw === "true";

	const dryRunRaw = env["DRY_RUN"] ?? "false";
	if (dryRunRaw !== "true" && dryRunRaw !== "false") {
		throw new Error(`DRY_RUN must be 'true' or 'false' (got: ${dryRunRaw})`);
	}
	const dryRun = dryRunRaw === "true";

	return {
		githubToken,
		repository,
		prNumber,
		allowedAuthors,
		requiredLabels,
		labelMatchMode,
		mergeMethod,
		pathFilters,
		maxFilesChanged,
		maxLinesAdded,
		maxLinesRemoved,
		maxTotalLines,
		sizeLimitMessage,
		silent,
		dryRun,
	};
}
