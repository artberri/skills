#!/usr/bin/env bash
set -euo pipefail

# On main, everything pushed, with real tests: `npm test` runs node --test.
# The uncommitted change is the timezone fix, which looks right in the diff.
# But src/audit.js, which the change doesn't touch, passes formatTimestamp a
# number of milliseconds: a number has toLocaleString() but no toISOString(),
# so the audit test passes on main and throws with the change. Only the test
# shows the number, so running it, not reading the code, is what finds this.

# shellcheck source=skills/templates/ship/evals/fixtures/base.sh
. "$(dirname "$0")/base.sh"

ship_base "$1"
cat >src/audit.js <<'EOF'
import { formatTimestamp } from "./time.js";

export function auditLine(entry) {
	return `${formatTimestamp(entry.at)} ${entry.actor} ${entry.verb} ${entry.target}`;
}
EOF
eval_commit . "feat(audit): add audit lines"
ship_node_tests
cat >test/audit.test.js <<'EOF'
import { test } from "node:test";
import assert from "node:assert/strict";
import { auditLine } from "../src/audit.js";

test("auditLine names the actor, the verb and the target", () => {
	const entry = { at: 0, actor: "ana", verb: "deleted", target: "invoice 7" };
	assert.match(auditLine(entry), / ana deleted invoice 7$/);
});
EOF
eval_commit . "test: run the tests with node --test"
git push --quiet origin main

ship_fix_timezone
