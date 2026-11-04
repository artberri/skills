#!/usr/bin/env bash
set -euo pipefail

# On main, everything pushed. src/time.js holds two changes in separate hunks:
# the timezone fix at the top and a new formatDuration helper at the end.

# shellcheck source=skills/portable/commit/evals/fixtures/base.sh
. "$(dirname "$0")/base.sh"

commit_base "$1"
commit_fix_timezone
commit_add_duration
