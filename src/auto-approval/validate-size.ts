import type { ActionConfig, CheckResult } from "./types.js";

interface SizeMetrics {
	filesChanged: number;
	linesAdded: number;
	linesRemoved: number;
}

/**
 * Validate PR size metrics against the limits in the action config.
 *
 * A limit value of 0 means no limit for that metric.
 * All failing thresholds are collected and reported together.
 */
export function validateSize(metrics: SizeMetrics, config: ActionConfig): CheckResult {
	const total = metrics.linesAdded + metrics.linesRemoved;
	const failures: string[] = [];

	if (config.maxFilesChanged > 0 && metrics.filesChanged > config.maxFilesChanged) {
		failures.push(
			`Files changed (${metrics.filesChanged}) exceeds limit (${config.maxFilesChanged})`,
		);
	}

	if (config.maxLinesAdded > 0 && metrics.linesAdded > config.maxLinesAdded) {
		failures.push(
			`Lines added (${metrics.linesAdded}) exceeds limit (${config.maxLinesAdded})`,
		);
	}

	if (config.maxLinesRemoved > 0 && metrics.linesRemoved > config.maxLinesRemoved) {
		failures.push(
			`Lines removed (${metrics.linesRemoved}) exceeds limit (${config.maxLinesRemoved})`,
		);
	}

	if (config.maxTotalLines > 0 && total > config.maxTotalLines) {
		failures.push(
			`Total lines changed (${total}) exceeds limit (${config.maxTotalLines})`,
		);
	}

	if (failures.length > 0) {
		return {
			name: "Size",
			passed: false,
			message: `${config.sizeLimitMessage}: ${failures.join("; ")}`,
		};
	}

	return {
		name: "Size",
		passed: true,
		message: "PR size is within configured limits",
	};
}
