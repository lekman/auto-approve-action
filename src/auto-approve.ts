import fs from "fs";
import {
	parseConfig,
	validateAuthor,
	validateLabels,
	validatePaths,
	validateSize,
	buildSummary,
} from "./auto-approval/index.js";
import type { ActionConfig, CheckResult, PrData, ValidationResult } from "./auto-approval/index.js";
import { GithubSystem } from "./github/index.js";

/** Write content to GITHUB_STEP_SUMMARY if the path is set. */
function appendSummary(content: string): void {
	const summaryPath = process.env["GITHUB_STEP_SUMMARY"];
	if (summaryPath) {
		fs.appendFileSync(summaryPath, content + "\n");
	}
}

/** Determine whether the current actor has already approved the PR at its latest commit. */
async function resolveApprovalStatus(
	config: ActionConfig,
	pr: PrData,
): Promise<"current" | "stale" | "none"> {
	const currentUser = await GithubSystem.getCurrentUser();
	const reviews = await GithubSystem.fetchReviews(config.prNumber, config.repository);

	const myApprovals = reviews.filter(
		(r) => r.userLogin === currentUser && r.state === "APPROVED",
	);

	if (myApprovals.length === 0) {
		return "none";
	}

	const atHead = myApprovals.find((r) => r.commitId === pr.headRefOid);
	return atHead !== undefined ? "current" : "stale";
}

/**
 * Run the full auto-approval workflow.
 * Throws on unrecoverable errors so the caller can decide how to exit.
 */
async function runWorkflow(): Promise<void> {
	// 1. Parse config
	const config = parseConfig(process.env as Record<string, string | undefined>);

	// 2. Fetch PR data
	const pr = await GithubSystem.fetchPr(config.prNumber, config.repository);

	// 3. Run validation checks
	const checks: CheckResult[] = [];

	checks.push(validateAuthor(pr.authorLogin, config.allowedAuthors));

	if (config.requiredLabels.length > 0 || config.labelMatchMode === "none") {
		checks.push(validateLabels(config.labelMatchMode, config.requiredLabels, pr.labels));
	}

	if (config.pathFilters.length > 0) {
		checks.push(validatePaths(pr.filePaths, config.pathFilters));
	}

	if (
		config.maxFilesChanged > 0 ||
		config.maxLinesAdded > 0 ||
		config.maxLinesRemoved > 0 ||
		config.maxTotalLines > 0
	) {
		checks.push(
			validateSize(
				{
					filesChanged: pr.changedFiles,
					linesAdded: pr.additions,
					linesRemoved: pr.deletions,
				},
				config,
			),
		);
	}

	// 4. Collect validation result
	const result: ValidationResult = {
		passed: checks.every((c) => c.passed),
		checks,
	};

	// 5. Handle failed validation
	if (!result.passed) {
		const failedChecks = checks.filter((c) => !c.passed);

		if (!config.silent) {
			const summary = buildSummary({
				prNumber: pr.number,
				author: pr.authorLogin,
				checks,
				autoMergeEnabled: false,
				dryRun: config.dryRun,
				reApproval: false,
				silent: config.silent,
			});
			appendSummary(summary);
		}

		process.stderr.write("Auto-approval failed. The following checks did not pass:\n");
		for (const check of failedChecks) {
			process.stderr.write(`  [${check.name}] ${check.message}\n`);
		}
		process.exit(1);
	}

	// 6. Check existing approval status
	let approvalStatus: "current" | "stale" | "none" = "none";
	try {
		approvalStatus = await resolveApprovalStatus(config, pr);
	} catch (err) {
		process.stderr.write(
			`Warning: could not determine approval status: ${(err as Error).message}\n`,
		);
	}

	// 7. Skip when approval is already current
	if (approvalStatus === "current") {
		process.stdout.write(`PR #${config.prNumber} is already approved at the latest commit.\n`);
		return;
	}

	const isReapproval = approvalStatus === "stale";

	// 8. Perform approval (unless dry-run)
	let autoMergeEnabled = false;

	if (config.dryRun) {
		process.stdout.write(
			`Dry run: would approve PR #${config.prNumber}${isReapproval ? " (re-approval)" : ""}.\n`,
		);
	} else {
		// Enable auto-merge (non-fatal on failure)
		try {
			autoMergeEnabled = await GithubSystem.enableAutoMerge(
				config.prNumber,
				config.repository,
				config.mergeMethod,
			);
		} catch (err) {
			process.stderr.write(
				`Warning: could not enable auto-merge: ${(err as Error).message}\n`,
			);
		}

		// Approve the PR using the summary markdown as the review body
		const reviewBody = buildSummary({
			prNumber: pr.number,
			author: pr.authorLogin,
			checks,
			autoMergeEnabled,
			dryRun: config.dryRun,
			reApproval: isReapproval,
			silent: false,
		});
		await GithubSystem.approvePr(config.prNumber, config.repository, reviewBody);
		process.stdout.write(
			`PR #${config.prNumber} approved${isReapproval ? " (re-approval)" : ""}.\n`,
		);

		// Retry auto-merge after re-approval when the first attempt failed
		if (isReapproval && !autoMergeEnabled) {
			try {
				autoMergeEnabled = await GithubSystem.enableAutoMerge(
					config.prNumber,
					config.repository,
					config.mergeMethod,
				);
			} catch (_err) {
				// Non-fatal — already warned earlier
			}
		}
	}

	// 9. Write step summary (unless silent)
	if (!config.silent) {
		const summary = buildSummary({
			prNumber: pr.number,
			author: pr.authorLogin,
			checks,
			autoMergeEnabled,
			dryRun: config.dryRun,
			reApproval: isReapproval,
			silent: config.silent,
		});
		appendSummary(summary);
	}
}

/**
 * Entry point for the Auto-Approve GitHub Action.
 *
 * Orchestrates config parsing, PR data fetching, validation, approval,
 * and summary writing.
 */
export class AutoApproveAction {
	/** Run the workflow, writing to stdout/stderr and exiting with 0 or 1. */
	static run(): void {
		runWorkflow().catch((err: unknown) => {
			process.stderr.write(`Error: ${(err as Error).message}\n`);
			process.exit(1);
		});
	}
}

AutoApproveAction.run();
