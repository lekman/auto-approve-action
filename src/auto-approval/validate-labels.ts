import type { CheckResult } from "./types.js";

/**
 * Validate PR labels against the required labels configuration.
 *
 * Modes:
 * - `all`: every label in requiredLabels must be present on the PR
 * - `any`: at least one label in requiredLabels must be present on the PR
 * - `none`: none of the labels in requiredLabels may be present on the PR;
 *           if requiredLabels is empty, the check passes automatically
 */
export function validateLabels(
	mode: "all" | "any" | "none",
	requiredLabels: string[],
	prLabels: string[],
): CheckResult {
	if (mode === "none") {
		if (requiredLabels.length === 0) {
			return {
				name: "Labels",
				passed: true,
				message: "No label exclusions configured",
			};
		}
		const forbidden = requiredLabels.find((label) => prLabels.includes(label));
		if (forbidden !== undefined) {
			return {
				name: "Labels",
				passed: false,
				message: `Excluded label(s) found: ${requiredLabels.filter((l) => prLabels.includes(l)).join(", ")}`,
			};
		}
		return {
			name: "Labels",
			passed: true,
			message: "None of the excluded labels are present",
		};
	}

	if (mode === "all") {
		const missing = requiredLabels.filter((label) => !prLabels.includes(label));
		if (missing.length > 0) {
			return {
				name: "Labels",
				passed: false,
				message: `Missing required labels: ${missing.join(", ")}`,
			};
		}
		return {
			name: "Labels",
			passed: true,
			message: `All required labels are present: ${requiredLabels.join(", ")}`,
		};
	}

	// mode === "any"
	const found = requiredLabels.find((label) => prLabels.includes(label));
	if (found !== undefined) {
		return {
			name: "Labels",
			passed: true,
			message: `Found required label: '${found}'`,
		};
	}
	return {
		name: "Labels",
		passed: false,
		message: `None of the required labels are present: ${requiredLabels.join(", ")}`,
	};
}
