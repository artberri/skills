#!/usr/bin/env bash
set -euo pipefail

# On main, everything pushed, with two uncommitted changes that don't belong
# together: the timezone fix in src/time.js and an unrelated Node bump in the
# CI workflow.

# shellcheck source=skills/templates/ship/evals/fixtures/base.sh
. "$(dirname "$0")/base.sh"

ship_base "$1"
ship_fix_timezone
sed 's/node-version: 20/node-version: 22/' .github/workflows/ci.yml >ci.yml.new
mv ci.yml.new .github/workflows/ci.yml
