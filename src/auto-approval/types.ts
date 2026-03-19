export interface ActionConfig {
	githubToken: string;
	repository: string;
	prNumber: number;
	allowedAuthors: string[];
	requiredLabels: string[];
	labelMatchMode: "all" | "any" | "none";
	mergeMethod: "merge" | "squash" | "rebase";
	pathFilters: string[];
	maxFilesChanged: number;
	maxLinesAdded: number;
	maxLinesRemoved: number;
	maxTotalLines: number;
	sizeLimitMessage: string;
	silent: boolean;
	dryRun: boolean;
}

export interface PrData {
	number: number;
	nodeId: string;
	authorLogin: string;
	labels: string[];
	filePaths: string[];
	additions: number;
	deletions: number;
	changedFiles: number;
	headRefOid: string;
}

export interface CheckResult {
	name: string;
	passed: boolean;
	message: string;
}

export interface ValidationResult {
	passed: boolean;
	checks: CheckResult[];
}

export interface ReviewInfo {
	id: number;
	state: string;
	commitId: string;
	userLogin: string;
}

export type ApprovalStatus = "current" | "stale" | "none";
