#!/usr/bin/env bash
set -euo pipefail

# The repository the trigger queries run in: on main, everything pushed, with
# the timezone fix finished but uncommitted.

# shellcheck source=skills/portable/commit/evals/fixtures/base.sh
. "$(dirname "$0")/base.sh"

commit_base "$1"
commit_fix_timezone
