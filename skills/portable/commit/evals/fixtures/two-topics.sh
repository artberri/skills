#!/usr/bin/env bash
set -euo pipefail

# On main, everything pushed, with two uncommitted changes that don't belong
# together: the timezone fix in src/time.js and a Node bump in the CI workflow.

# shellcheck source=skills/portable/commit/evals/fixtures/base.sh
. "$(dirname "$0")/base.sh"

commit_base "$1"
commit_fix_timezone
commit_bump_node
