#!/usr/bin/env bash
set -euo pipefail

# The timezone fix is already committed on a feature branch, pushed, and has
# an open pull request (#7). The working tree is clean.

# shellcheck source=skills/templates/ship/evals/fixtures/base.sh
. "$(dirname "$0")/base.sh"

ship_base "$1"
git switch --quiet -c fix-timezone-logging
ship_fix_timezone
eval_commit . "fix(log): log timestamps in UTC"
git push --quiet -u origin fix-timezone-logging
eval_fake_pr 7 fix-timezone-logging "fix(log): log timestamps in UTC"
