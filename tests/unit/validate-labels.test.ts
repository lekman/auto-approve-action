import { describe, it, expect } from "bun:test";
import { validateLabels } from "../../src/auto-approval/index.js";

describe("validateLabels", () => {
	describe("mode 'all'", () => {
		it("passes when all required labels are present", () => {
			// Arrange
			const required = ["automerge", "safe"];
			const prLabels = ["automerge", "safe", "extra"];

			// Act
			const result = validateLabels("all", required, prLabels);

			// Assert
			expect(result.passed).toBe(true);
		});

		it("fails when one required label is missing", () => {
			// Arrange
			const required = ["automerge", "safe"];
			const prLabels = ["automerge"];

			// Act
			const result = validateLabels("all", required, prLabels);

			// Assert
			expect(result.passed).toBe(false);
			expect(result.message).toContain("safe");
		});

		it("fails when no required labels are present", () => {
			// Arrange
			const required = ["automerge", "safe"];
			const prLabels: string[] = [];

			// Act
			const result = validateLabels("all", required, prLabels);

			// Assert
			expect(result.passed).toBe(false);
		});
	});

	describe("mode 'any'", () => {
		it("passes when at least one required label is present", () => {
			// Arrange
			const required = ["automerge", "safe"];
			const prLabels = ["safe"];

			// Act
			const result = validateLabels("any", required, prLabels);

			// Assert
			expect(result.passed).toBe(true);
		});

		it("passes when all required labels are present", () => {
			// Arrange
			const required = ["automerge", "safe"];
			const prLabels = ["automerge", "safe"];

			// Act
			const result = validateLabels("any", required, prLabels);

			// Assert
			expect(result.passed).toBe(true);
		});

		it("fails when no required labels are present", () => {
			// Arrange
			const required = ["automerge", "safe"];
			const prLabels = ["unrelated"];

			// Act
			const result = validateLabels("any", required, prLabels);

			// Assert
			expect(result.passed).toBe(false);
		});
	});

	describe("mode 'none'", () => {
		it("passes when no excluded labels are present", () => {
			// Arrange — required list doubles as exclusion list in 'none' mode
			const excluded = ["do-not-merge", "wip"];
			const prLabels = ["safe", "automerge"];

			// Act
			const result = validateLabels("none", excluded, prLabels);

			// Assert
			expect(result.passed).toBe(true);
		});

		it("fails when an excluded label is present", () => {
			// Arrange
			const excluded = ["do-not-merge", "wip"];
			const prLabels = ["automerge", "do-not-merge"];

			// Act
			const result = validateLabels("none", excluded, prLabels);

			// Assert
			expect(result.passed).toBe(false);
			expect(result.message).toContain("do-not-merge");
		});

		it("passes when PR has labels but none match the exclusion list", () => {
			// Arrange
			const excluded = ["do-not-merge"];
			const prLabels = ["ready", "reviewed"];

			// Act
			const result = validateLabels("none", excluded, prLabels);

			// Assert
			expect(result.passed).toBe(true);
		});

		it("passes when the required labels list is empty (no exclusions to check)", () => {
			// Arrange
			const excluded: string[] = [];
			const prLabels = ["any-label"];

			// Act
			const result = validateLabels("none", excluded, prLabels);

			// Assert
			expect(result.passed).toBe(true);
		});

		it("passes when both excluded list and PR labels are empty", () => {
			// Arrange
			const excluded: string[] = [];
			const prLabels: string[] = [];

			// Act
			const result = validateLabels("none", excluded, prLabels);

			// Assert
			expect(result.passed).toBe(true);
		});
	});

	it("returns a check result with name 'Labels'", () => {
		// Arrange
		const required = ["safe"];
		const prLabels = ["safe"];

		// Act
		const result = validateLabels("all", required, prLabels);

		// Assert
		expect(result.name).toBe("Labels");
	});
});
