import { describe, it, expect } from "bun:test";
import { validateAuthor } from "../../src/auto-approval/index.js";

describe("validateAuthor", () => {
	it("passes when author is in the allowed list", () => {
		// Arrange
		const author = "alice";
		const allowedAuthors = ["alice", "bob"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.passed).toBe(true);
		expect(result.message).toContain("alice");
	});

	it("passes when author is a bot account", () => {
		// Arrange
		const author = "dependabot[bot]";
		const allowedAuthors = ["dependabot[bot]", "renovate[bot]"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.passed).toBe(true);
	});

	it("fails when author is not in the allowed list", () => {
		// Arrange
		const author = "mallory";
		const allowedAuthors = ["alice", "bob"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.passed).toBe(false);
		expect(result.message).toContain("mallory");
	});

	it("is case-sensitive — 'Author' does not match 'author'", () => {
		// Arrange
		const author = "Author";
		const allowedAuthors = ["author"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.passed).toBe(false);
	});

	it("handles author names that were trimmed during CSV parsing", () => {
		// Arrange — simulate the result of parseCsv(" alice , bob ")
		const author = "alice";
		const allowedAuthors = ["alice", "bob"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.passed).toBe(true);
	});

	it("works with a single allowed author", () => {
		// Arrange
		const author = "solo";
		const allowedAuthors = ["solo"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.passed).toBe(true);
	});

	it("works with multiple allowed authors", () => {
		// Arrange
		const author = "carol";
		const allowedAuthors = ["alice", "bob", "carol", "dave"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.passed).toBe(true);
	});

	it("fails when author list is empty", () => {
		// Arrange
		const author = "alice";
		const allowedAuthors: string[] = [];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.passed).toBe(false);
	});

	it("returns a check result with name 'Author'", () => {
		// Arrange
		const author = "alice";
		const allowedAuthors = ["alice"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.name).toBe("Author");
	});
});
