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

describe("validateAuthor with GitHub App logins", () => {
	it("matches an app/ allow-list entry against the API's [bot] login", () => {
		// The bug this normalisation exists for: `gh pr view --json author`
		// prints `app/name`, the API reports `name[bot]`, and an exact
		// comparison of the two can never pass. This repository's own workflow
		// and docs both used the `app/` form.
		// Arrange
		const author = "lekman-release-please-bot[bot]";
		const allowedAuthors = ["app/lekman-release-please-bot"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.passed).toBe(true);
	});

	it("matches when the allow-list uses the [bot] form and the author does too", () => {
		// Arrange
		const author = "lekman-release-please-bot[bot]";
		const allowedAuthors = ["lekman-release-please-bot[bot]"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.passed).toBe(true);
	});

	it("matches when the author itself arrives in the app/ form", () => {
		// Arrange
		const author = "app/lekman-release-please-bot";
		const allowedAuthors = ["lekman-release-please-bot[bot]"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.passed).toBe(true);
	});

	it("does not append [bot] to a plain login, so a human is not turned into a bot", () => {
		// Arrange
		const author = "lekman-release-please-bot";
		const allowedAuthors = ["lekman-release-please-bot[bot]"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.passed).toBe(false);
	});

	it("still refuses a different app", () => {
		// Arrange
		const author = "some-other-bot[bot]";
		const allowedAuthors = ["app/lekman-release-please-bot"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.passed).toBe(false);
		expect(result.message).toContain("some-other-bot[bot]");
	});

	it("reports the author as written, not as normalised", () => {
		// The message is what a maintainer reads in the log. Showing a
		// rewritten login would send them looking for a string that is not in
		// their workflow.
		// Arrange
		const author = "app/lekman-release-please-bot";
		const allowedAuthors = ["nobody"];

		// Act
		const result = validateAuthor(author, allowedAuthors);

		// Assert
		expect(result.message).toContain("app/lekman-release-please-bot");
	});
});
