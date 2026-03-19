import type { CheckResult } from "./types.js";

export interface SummaryOptions {
	prNumber: number;
	author: string;
	checks: CheckResult[];
	autoMergeEnabled: boolean;
	dryRun: boolean;
	reApproval: boolean;
	silent: boolean;
}

/**
 * Build the markdown content for GITHUB_STEP_SUMMARY.
 *
 * Returns an empty string when silent is true.
 * Covers validation results, PR metadata, dry-run state, re-approval
 * context, and auto-merge status.
 */
export function buildSummary(opts: SummaryOptions): string {
	if (opts.silent) {
		return "";
	}

	const lines: string[] = [];

	if (opts.dryRun) {
		lines.push("## Auto-Approval Dry Run Completed");
	} else if (opts.reApproval) {
		lines.push("## Auto-Approval Completed (Re-approval after new commits)");
	} else {
		lines.push("## Auto-Approval Completed");
	}

	lines.push("");
	lines.push("### Pull Request Details");
	lines.push(`- **PR**: #${opts.prNumber}`);
	lines.push(`- **Author**: @${opts.author}`);
	if (opts.reApproval) {
		lines.push(
			"- **Type**: Re-approval (previous approval was stale due to new commits)",
		);
	}

	lines.push("");
	lines.push("### Validation Checks");
	for (const check of opts.checks) {
		const icon = check.passed ? "PASS" : "FAIL";
		lines.push(`- [${icon}] **${check.name}**: ${check.message}`);
	}

	if (!opts.dryRun) {
		lines.push("");
		lines.push("### Auto-Merge Status");
		lines.push(
			opts.autoMergeEnabled
				? "- Auto-merge enabled (PR will merge when all checks pass)"
				: "- Auto-merge not enabled (manual merge required)",
		);
	}

	if (opts.dryRun) {
		lines.push("");
		lines.push("*This was a dry run. No actual approval or merge was performed.*");
	}

	return lines.join("\n");
}
