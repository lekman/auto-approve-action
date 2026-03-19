import { describe, it, expect } from "bun:test";
import { parseConfig } from "../../src/auto-approval/index.js";

// ---------------------------------------------------------------------------
// Minimal valid env that satisfies all required fields.
// LABEL_MATCH_MODE is set to "none" so REQUIRED_LABELS can be omitted.
// ---------------------------------------------------------------------------
const minimalEnv = {
	GITHUB_TOKEN: "ghp_token",
	GITHUB_REPOSITORY: "owner/repo",
	PR_NUMBER: "42",
	ALLOWED_AUTHORS: "alice",
	LABEL_MATCH_MODE: "none",
};

describe("parseConfig", () => {
	describe("valid configurations", () => {
		it("parses a complete valid configuration with all fields", () => {
			// Arrange
			const env = {
				GITHUB_TOKEN: "ghp_token",
				GITHUB_REPOSITORY: "owner/repo",
				PR_NUMBER: "7",
				ALLOWED_AUTHORS: "alice, bob",
				REQUIRED_LABELS: "automerge, safe",
				LABEL_MATCH_MODE: "all",
				MERGE_METHOD: "squash",
				PATH_FILTERS: "src/**/*.ts, !dist/**",
				MAX_FILES_CHANGED: "10",
				MAX_LINES_ADDED: "500",
				MAX_LINES_REMOVED: "200",
				MAX_TOTAL_LINES: "600",
				SIZE_LIMIT_MESSAGE: "Too large",
				SILENT: "true",
				DRY_RUN: "true",
			};

			// Act
			const config = parseConfig(env);

			// Assert
			expect(config.githubToken).toBe("ghp_token");
			expect(config.repository).toBe("owner/repo");
			expect(config.prNumber).toBe(7);
			expect(config.allowedAuthors).toEqual(["alice", "bob"]);
			expect(config.requiredLabels).toEqual(["automerge", "safe"]);
			expect(config.labelMatchMode).toBe("all");
			expect(config.mergeMethod).toBe("squash");
			expect(config.pathFilters).toEqual(["src/**/*.ts", "!dist/**"]);
			expect(config.maxFilesChanged).toBe(10);
			expect(config.maxLinesAdded).toBe(500);
			expect(config.maxLinesRemoved).toBe(200);
			expect(config.maxTotalLines).toBe(600);
			expect(config.sizeLimitMessage).toBe("Too large");
			expect(config.silent).toBe(true);
			expect(config.dryRun).toBe(true);
		});

		it("parses minimal required config (only required fields, LABEL_MATCH_MODE=none)", () => {
			// Arrange
			const env = { ...minimalEnv };

			// Act
			const config = parseConfig(env);

			// Assert
			expect(config.githubToken).toBe("ghp_token");
			expect(config.repository).toBe("owner/repo");
			expect(config.prNumber).toBe(42);
			expect(config.allowedAuthors).toEqual(["alice"]);
		});

		it("trims whitespace from CSV list items", () => {
			// Arrange
			const env = {
				...minimalEnv,
				ALLOWED_AUTHORS: " alice , bob , carol ",
			};

			// Act
			const config = parseConfig(env);

			// Assert
			expect(config.allowedAuthors).toEqual(["alice", "bob", "carol"]);
		});

		it("defaults LABEL_MATCH_MODE to 'all' when omitted", () => {
			// Arrange — REQUIRED_LABELS must be set when mode defaults to 'all'
			const env = {
				...minimalEnv,
				LABEL_MATCH_MODE: undefined,
				REQUIRED_LABELS: "safe",
			};

			// Act
			const config = parseConfig(env);

			// Assert
			expect(config.labelMatchMode).toBe("all");
		});

		it("defaults MERGE_METHOD to 'merge' when omitted", () => {
			// Arrange
			const env = { ...minimalEnv, MERGE_METHOD: undefined };

			// Act
			const config = parseConfig(env);

			// Assert
			expect(config.mergeMethod).toBe("merge");
		});

		it("defaults SILENT to false when omitted", () => {
			// Arrange
			const env = { ...minimalEnv, SILENT: undefined };

			// Act
			const config = parseConfig(env);

			// Assert
			expect(config.silent).toBe(false);
		});

		it("defaults DRY_RUN to false when omitted", () => {
			// Arrange
			const env = { ...minimalEnv, DRY_RUN: undefined };

			// Act
			const config = parseConfig(env);

			// Assert
			expect(config.dryRun).toBe(false);
		});

		it("defaults all size limits to 0 when omitted", () => {
			// Arrange
			const env = {
				...minimalEnv,
				MAX_FILES_CHANGED: undefined,
				MAX_LINES_ADDED: undefined,
				MAX_LINES_REMOVED: undefined,
				MAX_TOTAL_LINES: undefined,
			};

			// Act
			const config = parseConfig(env);

			// Assert
			expect(config.maxFilesChanged).toBe(0);
			expect(config.maxLinesAdded).toBe(0);
			expect(config.maxLinesRemoved).toBe(0);
			expect(config.maxTotalLines).toBe(0);
		});
	});

	describe("invalid configurations", () => {
		it("throws when GITHUB_TOKEN is missing", () => {
			// Arrange
			const env = { ...minimalEnv, GITHUB_TOKEN: undefined };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("GITHUB_TOKEN is required");
		});

		it("throws when GITHUB_REPOSITORY is missing", () => {
			// Arrange
			const env = { ...minimalEnv, GITHUB_REPOSITORY: undefined };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("GITHUB_REPOSITORY is required");
		});

		it("throws when PR_NUMBER is missing", () => {
			// Arrange
			const env = { ...minimalEnv, PR_NUMBER: undefined };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("PR_NUMBER is required");
		});

		it("throws when ALLOWED_AUTHORS is missing", () => {
			// Arrange
			const env = { ...minimalEnv, ALLOWED_AUTHORS: undefined };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("ALLOWED_AUTHORS is required");
		});

		it("throws when ALLOWED_AUTHORS has a leading comma", () => {
			// Arrange
			const env = { ...minimalEnv, ALLOWED_AUTHORS: ",alice" };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("ALLOWED_AUTHORS");
		});

		it("throws when ALLOWED_AUTHORS has a trailing comma", () => {
			// Arrange
			const env = { ...minimalEnv, ALLOWED_AUTHORS: "alice," };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("ALLOWED_AUTHORS");
		});

		it("throws when ALLOWED_AUTHORS has a double comma (empty item)", () => {
			// Arrange
			const env = { ...minimalEnv, ALLOWED_AUTHORS: "alice,,bob" };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("ALLOWED_AUTHORS");
		});

		it("throws when LABEL_MATCH_MODE is an invalid value", () => {
			// Arrange
			const env = { ...minimalEnv, LABEL_MATCH_MODE: "maybe" };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("LABEL_MATCH_MODE");
		});

		it("throws when LABEL_MATCH_MODE is 'all' but REQUIRED_LABELS is empty", () => {
			// Arrange
			const env = {
				...minimalEnv,
				LABEL_MATCH_MODE: "all",
				REQUIRED_LABELS: "",
			};

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("REQUIRED_LABELS");
		});

		it("throws when LABEL_MATCH_MODE is 'any' but REQUIRED_LABELS is empty", () => {
			// Arrange
			const env = {
				...minimalEnv,
				LABEL_MATCH_MODE: "any",
				REQUIRED_LABELS: undefined,
			};

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("REQUIRED_LABELS");
		});

		it("throws when MERGE_METHOD is an invalid value", () => {
			// Arrange
			const env = { ...minimalEnv, MERGE_METHOD: "fast-forward" };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("MERGE_METHOD");
		});

		it("throws when MAX_FILES_CHANGED is negative", () => {
			// Arrange
			const env = { ...minimalEnv, MAX_FILES_CHANGED: "-1" };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("MAX_FILES_CHANGED");
		});

		it("throws when MAX_FILES_CHANGED is non-numeric", () => {
			// Arrange
			const env = { ...minimalEnv, MAX_FILES_CHANGED: "ten" };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("MAX_FILES_CHANGED");
		});

		it("throws when SILENT is not 'true' or 'false'", () => {
			// Arrange
			const env = { ...minimalEnv, SILENT: "yes" };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("SILENT");
		});

		it("throws when PR_NUMBER is not a positive integer", () => {
			// Arrange
			const env = { ...minimalEnv, PR_NUMBER: "0" };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("PR_NUMBER");
		});

		it("throws when PR_NUMBER is a negative number", () => {
			// Arrange
			const env = { ...minimalEnv, PR_NUMBER: "-5" };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("PR_NUMBER");
		});

		it("throws when PR_NUMBER is a non-numeric string", () => {
			// Arrange
			const env = { ...minimalEnv, PR_NUMBER: "abc" };

			// Act & Assert
			expect(() => parseConfig(env)).toThrow("PR_NUMBER");
		});
	});
});
