import { describe, it, expect } from "bun:test";
import { buildSummary } from "../../src/auto-approval/index.js";
import type { CheckResult } from "../../src/auto-approval/index.js";

// ---------------------------------------------------------------------------
// Factory helpers
// ---------------------------------------------------------------------------

function makeChecks(overrides: Partial<CheckResult>[] = []): CheckResult[] {
	const defaults: CheckResult[] = [
		{ name: "Author", passed: true, message: "Author 'alice' is authorized" },
		{ name: "Labels", passed: true, message: "All required labels are present" },
		{ name: "Paths", passed: true, message: "Files match required patterns" },
		{ name: "Size", passed: true, message: "PR size is within configured limits" },
	];
	return defaults.map((d, i) => ({ ...d, ...(overrides[i] ?? {}) }));
}

interface SummaryOptions {
	prNumber: number;
	author: string;
	checks: CheckResult[];
	autoMergeEnabled: boolean;
	dryRun: boolean;
	reApproval: boolean;
	silent: boolean;
}

function makeOpts(overrides: Partial<SummaryOptions> = {}): SummaryOptions {
	return {
		prNumber: 42,
		author: "alice",
		checks: makeChecks(),
		autoMergeEnabled: true,
		dryRun: false,
		reApproval: false,
		silent: false,
		...overrides,
	};
}

describe("buildSummary", () => {
	it("includes the PR number and author in the output", () => {
		// Arrange
		const opts = makeOpts({ prNumber: 99, author: "bob" });

		// Act
		const summary = buildSummary(opts);

		// Assert
		expect(summary).toContain("#99");
		expect(summary).toContain("@bob");
	});

	it("includes validation check results", () => {
		// Arrange
		const checks: CheckResult[] = [
			{ name: "Author", passed: true, message: "Authorized" },
			{ name: "Labels", passed: false, message: "Missing label: safe" },
		];
		const opts = makeOpts({ checks });

		// Act
		const summary = buildSummary(opts);

		// Assert
		expect(summary).toContain("Author");
		expect(summary).toContain("Authorized");
		expect(summary).toContain("Labels");
		expect(summary).toContain("Missing label: safe");
	});

	it("includes auto-merge status when not in dry-run mode", () => {
		// Arrange
		const opts = makeOpts({ autoMergeEnabled: true, dryRun: false });

		// Act
		const summary = buildSummary(opts);

		// Assert
		expect(summary).toContain("Auto-Merge");
		expect(summary).toContain("Auto-merge enabled");
	});

	it("shows auto-merge not enabled when autoMergeEnabled is false", () => {
		// Arrange
		const opts = makeOpts({ autoMergeEnabled: false, dryRun: false });

		// Act
		const summary = buildSummary(opts);

		// Assert
		expect(summary).toContain("not enabled");
	});

	it("shows dry-run heading and note when dryRun is true", () => {
		// Arrange
		const opts = makeOpts({ dryRun: true });

		// Act
		const summary = buildSummary(opts);

		// Assert
		expect(summary).toContain("Dry Run");
		expect(summary).toContain("dry run");
	});

	it("does not include auto-merge section in dry-run mode", () => {
		// Arrange
		const opts = makeOpts({ dryRun: true });

		// Act
		const summary = buildSummary(opts);

		// Assert
		expect(summary).not.toContain("Auto-Merge Status");
	});

	it("shows re-approval heading and note when reApproval is true", () => {
		// Arrange
		const opts = makeOpts({ reApproval: true });

		// Act
		const summary = buildSummary(opts);

		// Assert
		expect(summary).toContain("Re-approval");
	});

	it("returns an empty string when silent is true", () => {
		// Arrange
		const opts = makeOpts({ silent: true });

		// Act
		const summary = buildSummary(opts);

		// Assert
		expect(summary).toBe("");
	});
});
