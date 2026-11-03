#!/usr/bin/env bash
set -euo pipefail

# The repository the trigger queries run in: on main, everything pushed, with
# the timezone fix finished but uncommitted, so "ship it" has something to
# ship.

# shellcheck source=skills/templates/ship/evals/fixtures/base.sh
. "$(dirname "$0")/base.sh"

ship_base "$1"
ship_fix_timezone
