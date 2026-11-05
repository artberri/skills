#!/usr/bin/env bash
set -euo pipefail

# On main, everything pushed, with real tests: `npm test` runs node --test.
# One test already fails on main: parsePort in src/config.js returns a string
# where its test expects a number. The uncommitted change is the timezone
# fix, which touches neither.

# shellcheck source=skills/templates/ship/evals/fixtures/base.sh
. "$(dirname "$0")/base.sh"

ship_base "$1"
ship_node_tests
cat >src/config.js <<'EOF'
export function parsePort(value) {
	return value.trim();
}
EOF
cat >test/config.test.js <<'EOF'
import { test } from "node:test";
import assert from "node:assert/strict";
import { parsePort } from "../src/config.js";

test("parsePort reads the port as a number", () => {
	assert.equal(parsePort(" 8080 "), 8080);
});
EOF
eval_commit . "feat(config): read the port from the environment"
git push --quiet origin main

ship_fix_timezone
