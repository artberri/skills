#!/usr/bin/env bash
set -euo pipefail

# On main, everything pushed, with the timezone fix uncommitted, in a project
# whose CONTRIBUTING.md says every change goes through a pull request.

# shellcheck source=skills/portable/commit/evals/fixtures/base.sh
. "$(dirname "$0")/base.sh"

commit_base "$1"
cat >CONTRIBUTING.md <<'MD'
# Contributing

Every change goes through a pull request against main. Don't commit to main
directly.
MD
eval_commit . "docs: describe how to contribute"
git push --quiet origin main
commit_fix_timezone
