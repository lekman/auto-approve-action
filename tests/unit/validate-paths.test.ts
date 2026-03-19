import { describe, it, expect } from "bun:test";
import { matchesPattern, validatePaths } from "../../src/auto-approval/index.js";

describe("matchesPattern", () => {
	it("matches an exact file path", () => {
		// Arrange
		const file = "src/index.ts";
		const pattern = "src/index.ts";

		// Act
		const result = matchesPattern(file, pattern);

		// Assert
		expect(result).toBe(true);
	});

	it("single wildcard '*.ts' matches 'foo.ts'", () => {
		// Arrange
		const file = "foo.ts";
		const pattern = "*.ts";

		// Act
		const result = matchesPattern(file, pattern);

		// Assert
		expect(result).toBe(true);
	});

	it("single wildcard does not match across directory boundaries", () => {
		// Arrange — *.ts must not match src/foo.ts
		const file = "src/foo.ts";
		const pattern = "*.ts";

		// Act
		const result = matchesPattern(file, pattern);

		// Assert
		expect(result).toBe(false);
	});

	it("double wildcard '**/*.ts' matches nested files", () => {
		// Arrange
		const file = "src/utils/helpers.ts";
		const pattern = "**/*.ts";

		// Act
		const result = matchesPattern(file, pattern);

		// Assert
		expect(result).toBe(true);
	});

	it("double wildcard 'src/**' matches everything under src/", () => {
		// Arrange
		const file = "src/components/Button.tsx";
		const pattern = "src/**";

		// Act
		const result = matchesPattern(file, pattern);

		// Assert
		expect(result).toBe(true);
	});

	it("pattern '**/*' matches everything", () => {
		// Arrange
		const file = "deeply/nested/path/file.txt";
		const pattern = "**/*";

		// Act
		const result = matchesPattern(file, pattern);

		// Assert
		expect(result).toBe(true);
	});

	it("directory glob 'src/*.ts' matches files directly in src/", () => {
		// Arrange
		const file = "src/index.ts";
		const pattern = "src/*.ts";

		// Act
		const result = matchesPattern(file, pattern);

		// Assert
		expect(result).toBe(true);
	});

	it("directory glob 'src/*.ts' does not match files in subdirectories", () => {
		// Arrange
		const file = "src/utils/helper.ts";
		const pattern = "src/*.ts";

		// Act
		const result = matchesPattern(file, pattern);

		// Assert
		expect(result).toBe(false);
	});

	it("pattern with dots '*.config.js' matches 'eslint.config.js'", () => {
		// Arrange
		const file = "eslint.config.js";
		const pattern = "*.config.js";

		// Act
		const result = matchesPattern(file, pattern);

		// Assert
		expect(result).toBe(true);
	});
});

describe("validatePaths", () => {
	it("passes when files match include patterns", () => {
		// Arrange
		const files = ["src/index.ts", "src/utils.ts"];
		const filters = ["src/**/*.ts"];

		// Act
		const result = validatePaths(files, filters);

		// Assert
		expect(result.passed).toBe(true);
	});

	it("fails when no files match include patterns", () => {
		// Arrange
		const files = ["dist/index.js", "dist/utils.js"];
		const filters = ["src/**/*.ts"];

		// Act
		const result = validatePaths(files, filters);

		// Assert
		expect(result.passed).toBe(false);
	});

	it("exclusion patterns remove matching files before inclusion check", () => {
		// Arrange — only src/index.ts remains after exclusion of utils.ts
		const files = ["src/index.ts", "src/utils.ts"];
		const filters = ["src/**/*.ts", "!src/utils.ts"];

		// Act
		const result = validatePaths(files, filters);

		// Assert
		expect(result.passed).toBe(true);
	});

	it("fails when ALL files match exclusion patterns (only exclusions, no includes)", () => {
		// Arrange
		const files = ["dist/index.js", "dist/utils.js"];
		const filters = ["!dist/**"];

		// Act
		const result = validatePaths(files, filters);

		// Assert
		expect(result.passed).toBe(false);
		expect(result.message).toContain("exclusion");
	});

	it("mixed include and exclude: exclude takes priority over include", () => {
		// Arrange — dist/index.js matches both include '**/*.js' and exclude '!dist/**'
		// After exclusion all files are removed, so no files match the include pattern
		const files = ["dist/index.js"];
		const filters = ["**/*.js", "!dist/**"];

		// Act
		const result = validatePaths(files, filters);

		// Assert
		expect(result.passed).toBe(false);
	});

	it("passes when the path filters list is empty (no filtering)", () => {
		// Arrange
		const files = ["anything.txt"];
		const filters: string[] = [];

		// Act
		const result = validatePaths(files, filters);

		// Assert
		expect(result.passed).toBe(true);
	});

	it("returns a check result with name 'Paths'", () => {
		// Arrange
		const files = ["src/index.ts"];
		const filters = ["**/*.ts"];

		// Act
		const result = validatePaths(files, filters);

		// Assert
		expect(result.name).toBe("Paths");
	});
});
