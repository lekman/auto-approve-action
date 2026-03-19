import { describe, it, expect } from "bun:test";
import { validateSize } from "../../src/auto-approval/index.js";
import type { ActionConfig } from "../../src/auto-approval/index.js";

// ---------------------------------------------------------------------------
// Factory helpers
// ---------------------------------------------------------------------------

function makeConfig(overrides: Partial<ActionConfig> = {}): ActionConfig {
	return {
		githubToken: "token",
		repository: "owner/repo",
		prNumber: 1,
		allowedAuthors: ["alice"],
		requiredLabels: [],
		labelMatchMode: "none",
		mergeMethod: "merge",
		pathFilters: [],
		maxFilesChanged: 0,
		maxLinesAdded: 0,
		maxLinesRemoved: 0,
		maxTotalLines: 0,
		sizeLimitMessage: "PR exceeds configured size limits",
		silent: false,
		dryRun: false,
		...overrides,
	};
}

describe("validateSize", () => {
	it("passes when all metrics are within limits", () => {
		// Arrange
		const metrics = { filesChanged: 3, linesAdded: 50, linesRemoved: 10 };
		const config = makeConfig({
			maxFilesChanged: 10,
			maxLinesAdded: 100,
			maxLinesRemoved: 50,
			maxTotalLines: 200,
		});

		// Act
		const result = validateSize(metrics, config);

		// Assert
		expect(result.passed).toBe(true);
	});

	it("fails when files changed exceeds the limit", () => {
		// Arrange
		const metrics = { filesChanged: 15, linesAdded: 10, linesRemoved: 5 };
		const config = makeConfig({ maxFilesChanged: 10 });

		// Act
		const result = validateSize(metrics, config);

		// Assert
		expect(result.passed).toBe(false);
		expect(result.message).toContain("Files changed");
	});

	it("fails when lines added exceeds the limit", () => {
		// Arrange
		const metrics = { filesChanged: 1, linesAdded: 200, linesRemoved: 5 };
		const config = makeConfig({ maxLinesAdded: 100 });

		// Act
		const result = validateSize(metrics, config);

		// Assert
		expect(result.passed).toBe(false);
		expect(result.message).toContain("Lines added");
	});

	it("fails when lines removed exceeds the limit", () => {
		// Arrange
		const metrics = { filesChanged: 1, linesAdded: 10, linesRemoved: 60 };
		const config = makeConfig({ maxLinesRemoved: 50 });

		// Act
		const result = validateSize(metrics, config);

		// Assert
		expect(result.passed).toBe(false);
		expect(result.message).toContain("Lines removed");
	});

	it("fails when total lines (added + removed) exceeds the limit", () => {
		// Arrange
		const metrics = { filesChanged: 1, linesAdded: 100, linesRemoved: 100 };
		const config = makeConfig({ maxTotalLines: 150 });

		// Act
		const result = validateSize(metrics, config);

		// Assert
		expect(result.passed).toBe(false);
		expect(result.message).toContain("Total lines");
	});

	it("a limit of zero means no limit — always passes for that metric", () => {
		// Arrange — all limits are 0, metrics are huge
		const metrics = { filesChanged: 9999, linesAdded: 9999, linesRemoved: 9999 };
		const config = makeConfig({
			maxFilesChanged: 0,
			maxLinesAdded: 0,
			maxLinesRemoved: 0,
			maxTotalLines: 0,
		});

		// Act
		const result = validateSize(metrics, config);

		// Assert
		expect(result.passed).toBe(true);
	});

	it("reports all exceeded limits in the message, not just the first one", () => {
		// Arrange
		const metrics = { filesChanged: 20, linesAdded: 300, linesRemoved: 5 };
		const config = makeConfig({ maxFilesChanged: 10, maxLinesAdded: 100 });

		// Act
		const result = validateSize(metrics, config);

		// Assert
		expect(result.passed).toBe(false);
		expect(result.message).toContain("Files changed");
		expect(result.message).toContain("Lines added");
	});

	it("all limits zero passes regardless of PR size", () => {
		// Arrange
		const metrics = { filesChanged: 500, linesAdded: 10000, linesRemoved: 5000 };
		const config = makeConfig();

		// Act
		const result = validateSize(metrics, config);

		// Assert
		expect(result.passed).toBe(true);
	});

	it("includes the custom sizeLimitMessage in the failure result", () => {
		// Arrange
		const metrics = { filesChanged: 20, linesAdded: 10, linesRemoved: 5 };
		const config = makeConfig({
			maxFilesChanged: 5,
			sizeLimitMessage: "This PR is too large for auto-approval",
		});

		// Act
		const result = validateSize(metrics, config);

		// Assert
		expect(result.passed).toBe(false);
		expect(result.message).toContain("This PR is too large for auto-approval");
	});

	it("returns a check result with name 'Size'", () => {
		// Arrange
		const metrics = { filesChanged: 1, linesAdded: 1, linesRemoved: 1 };
		const config = makeConfig();

		// Act
		const result = validateSize(metrics, config);

		// Assert
		expect(result.name).toBe("Size");
	});
});
