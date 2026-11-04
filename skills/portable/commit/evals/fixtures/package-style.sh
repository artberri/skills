#!/usr/bin/env bash
set -euo pipefail

# On main, everything pushed, in a project whose history uses Go-style
# subjects (`time: ...`) instead of Conventional Commits, with the timezone
# fix uncommitted.

# shellcheck source=skills/portable/commit/evals/fixtures/base.sh
. "$(dirname "$0")/base.sh"

commit_base "$1" package
commit_fix_timezone
