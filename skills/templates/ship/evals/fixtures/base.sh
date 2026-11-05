# shellcheck shell=bash
# Shared by the ship fixtures; sourced, not run. Builds a small Node project
# that matches the template's example content: it ships through pull requests
# against main, uses Conventional Commits, and has `npm run format`, `npm run
# lint` and `npm test` (the checks before pushing), plus the review docs the
# self-review paragraph links to. All of it committed on main and pushed.
# Leaves the current folder at the repository.

# shellcheck source=scripts/evals/fixture-lib.sh
. "$EVAL_LIB"

ship_base() {
	local root="$1"
	eval_repo "$root"
	cd "$root/repo" || return

	cat >package.json <<'EOF'
{
	"name": "app",
	"version": "1.0.0",
	"type": "module",
	"scripts": {
		"format": "true",
		"lint": "true",
		"test": "true"
	}
}
EOF
	mkdir -p src docs .github/workflows
	cat >README.md <<'EOF'
# app

Logs user activity.
EOF
	cat >.github/workflows/ci.yml <<'EOF'
name: ci
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm test
EOF
	eval_commit . "chore: set up the project"

	cat >src/time.js <<'EOF'
export function formatTimestamp(date) {
	return date.toLocaleString();
}
EOF
	cat >src/log.js <<'EOF'
import { formatTimestamp } from "./time.js";

export function logActivity(user, action, date = new Date()) {
	return `${formatTimestamp(date)} ${user} ${action}`;
}
EOF
	eval_commit . "feat(log): log user activity with a timestamp"

	cat >docs/PRE_PR_REVIEW.md <<'EOF'
# Pre-PR review

## Always

- No `console.log` left behind.
- Timestamps in logs are UTC, in ISO 8601.
EOF
	cat >docs/KNOWN_NON_ISSUES.md <<'EOF'
# Known non-issues

- `npm run format`, `npm run lint` and `npm test` are no-ops for now.
EOF
	eval_commit . "docs: add the pre-PR review checklist"

	git push --quiet -u origin main
}

# Makes `npm test` run Node's test runner over test/, and drops it from the
# known non-issues. The caller writes the tests and commits.
ship_node_tests() {
	sed 's/"test": "true"/"test": "node --test"/' package.json >package.json.new
	mv package.json.new package.json
	cat >docs/KNOWN_NON_ISSUES.md <<'EOF'
# Known non-issues

- `npm run format` and `npm run lint` are no-ops for now.
EOF
	mkdir -p test
	cat >test/log.test.js <<'EOF'
import { test } from "node:test";
import assert from "node:assert/strict";
import { logActivity } from "../src/log.js";

test("logActivity puts the user and the action after the timestamp", () => {
	assert.match(logActivity("ana", "login", new Date(0)), / ana login$/);
});
EOF
}

# The fix the evals ship: log timestamps in UTC instead of local time.
ship_fix_timezone() {
	cat >src/time.js <<'EOF'
export function formatTimestamp(date) {
	return date.toISOString();
}
EOF
}
