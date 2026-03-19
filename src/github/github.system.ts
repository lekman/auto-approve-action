import type { PrData, ReviewInfo } from "../auto-approval/types.js";

const BASE_URL = "https://api.github.com";

/** GitHub REST/GraphQL adapter. All methods are static. */
export class GithubSystem {
	/**
	 * Return common request headers using the token from the environment.
	 */
	private static headers(): Record<string, string> {
		const token = process.env["GITHUB_TOKEN"] ?? process.env["GH_TOKEN"];
		if (!token) {
			throw new Error("GITHUB_TOKEN or GH_TOKEN must be set");
		}
		return {
			"Authorization": `Bearer ${token}`,
			"Accept": "application/vnd.github+json",
			"X-GitHub-Api-Version": "2022-11-28",
			"Content-Type": "application/json",
		};
	}

	/**
	 * Fetch PR metadata and the list of changed files in parallel.
	 *
	 * The PR node_id (GraphQL global ID) is included for use with the
	 * enableAutoMerge mutation.
	 */
	static async fetchPr(prNumber: number, repo: string): Promise<PrData> {
		const [prRes, filesRes] = await Promise.all([
			fetch(`${BASE_URL}/repos/${repo}/pulls/${prNumber}`, {
				headers: GithubSystem.headers(),
			}),
			fetch(`${BASE_URL}/repos/${repo}/pulls/${prNumber}/files?per_page=100`, {
				headers: GithubSystem.headers(),
			}),
		]);

		if (!prRes.ok) {
			throw new Error(`Failed to fetch PR #${prNumber}: ${prRes.status} ${prRes.statusText}`);
		}
		if (!filesRes.ok) {
			throw new Error(
				`Failed to fetch files for PR #${prNumber}: ${filesRes.status} ${filesRes.statusText}`,
			);
		}

		const prJson = await prRes.json() as {
			number: number;
			node_id: string;
			user: { login: string };
			labels: { name: string }[];
			additions: number;
			deletions: number;
			changed_files: number;
			head: { sha: string };
		};

		const filesJson = await filesRes.json() as { filename: string }[];

		return {
			number: prJson.number,
			nodeId: prJson.node_id,
			authorLogin: prJson.user.login,
			labels: prJson.labels.map((l) => l.name),
			filePaths: filesJson.map((f) => f.filename),
			additions: prJson.additions,
			deletions: prJson.deletions,
			changedFiles: prJson.changed_files,
			headRefOid: prJson.head.sha,
		};
	}

	/**
	 * Submit an APPROVE review on the PR.
	 *
	 * A 422 response is treated as a non-fatal condition (the PR may be closed
	 * or the reviewer may not be allowed to approve their own PR).
	 */
	static async approvePr(prNumber: number, repo: string, body: string): Promise<void> {
		const res = await fetch(`${BASE_URL}/repos/${repo}/pulls/${prNumber}/reviews`, {
			method: "POST",
			headers: GithubSystem.headers(),
			body: JSON.stringify({ event: "APPROVE", body }),
		});

		if (res.status === 422) {
			const text = await res.text();
			process.stderr.write(
				`Warning: received 422 when approving PR #${prNumber} (PR may be closed or self-approval blocked): ${text}\n`,
			);
			return;
		}

		if (!res.ok) {
			const text = await res.text();
			throw new Error(
				`Failed to approve PR #${prNumber}: ${res.status} ${res.statusText} — ${text}`,
			);
		}
	}

	/**
	 * Retrieve all reviews for the PR.
	 */
	static async fetchReviews(prNumber: number, repo: string): Promise<ReviewInfo[]> {
		const res = await fetch(
			`${BASE_URL}/repos/${repo}/pulls/${prNumber}/reviews?per_page=100`,
			{ headers: GithubSystem.headers() },
		);

		if (!res.ok) {
			throw new Error(
				`Failed to fetch reviews for PR #${prNumber}: ${res.status} ${res.statusText}`,
			);
		}

		const json = await res.json() as {
			id: number;
			state: string;
			commit_id: string;
			user: { login: string };
		}[];

		return json.map((r) => ({
			id: r.id,
			state: r.state,
			commitId: r.commit_id,
			userLogin: r.user.login,
		}));
	}

	/**
	 * Enable auto-merge on the PR via the GraphQL API.
	 *
	 * Returns true when auto-merge was enabled successfully, false on error
	 * (non-fatal — caller decides whether to treat this as an error).
	 */
	static async enableAutoMerge(
		prNumber: number,
		repo: string,
		method: string,
	): Promise<boolean> {
		// First, fetch the PR node_id required by the GraphQL mutation
		const prRes = await fetch(`${BASE_URL}/repos/${repo}/pulls/${prNumber}`, {
			headers: GithubSystem.headers(),
		});

		if (!prRes.ok) {
			process.stderr.write(
				`Warning: could not fetch PR node_id to enable auto-merge: ${prRes.status}\n`,
			);
			return false;
		}

		const prJson = await prRes.json() as { node_id: string };
		const nodeId = prJson.node_id;

		const mergeMethodGql = method.toUpperCase() as "MERGE" | "SQUASH" | "REBASE";

		const mutation = `
			mutation EnableAutoMerge($pullRequestId: ID!, $mergeMethod: PullRequestMergeMethod!) {
				enablePullRequestAutoMerge(input: { pullRequestId: $pullRequestId, mergeMethod: $mergeMethod }) {
					pullRequest {
						autoMergeRequest {
							mergeMethod
						}
					}
				}
			}
		`;

		const res = await fetch(`${BASE_URL}/graphql`, {
			method: "POST",
			headers: GithubSystem.headers(),
			body: JSON.stringify({
				query: mutation,
				variables: { pullRequestId: nodeId, mergeMethod: mergeMethodGql },
			}),
		});

		if (!res.ok) {
			const text = await res.text();
			process.stderr.write(
				`Warning: GraphQL request to enable auto-merge failed: ${res.status} — ${text}\n`,
			);
			return false;
		}

		const json = await res.json() as {
			errors?: { message: string }[];
			data?: unknown;
		};

		if (json.errors && json.errors.length > 0) {
			const msg = json.errors.map((e) => e.message).join("; ");
			// "already enabled" is not an actual failure
			if (msg.toLowerCase().includes("already") || msg.toLowerCase().includes("queued")) {
				return true;
			}
			process.stderr.write(`Warning: could not enable auto-merge: ${msg}\n`);
			return false;
		}

		return true;
	}

	/**
	 * Determine the login of the actor that owns the current token.
	 *
	 * Strategy:
	 * 1. Try /user (works for PATs and classic tokens).
	 * 2. Try /app (works for GitHub App installation tokens).
	 * 3. Fall back to the GITHUB_ACTOR environment variable.
	 */
	static async getCurrentUser(): Promise<string> {
		const headers = GithubSystem.headers();

		const userRes = await fetch(`${BASE_URL}/user`, { headers });
		if (userRes.ok) {
			const json = await userRes.json() as { login: string };
			if (json.login) {
				return json.login;
			}
		}

		const appRes = await fetch(`${BASE_URL}/app`, { headers });
		if (appRes.ok) {
			const json = await appRes.json() as { slug: string };
			if (json.slug) {
				return `${json.slug}[bot]`;
			}
		}

		const actor = process.env["GITHUB_ACTOR"];
		if (actor) {
			return actor;
		}

		throw new Error("Unable to determine the current GitHub user from the token or environment");
	}
}
