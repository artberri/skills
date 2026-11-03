#!/usr/bin/env bash
set -euo pipefail

# On main, everything pushed, with the timezone fix uncommitted and an
# untracked .env file next to it. The value is plainly fake, so no secret
# scanner mistakes it for a real one.

# shellcheck source=skills/templates/ship/evals/fixtures/base.sh
. "$(dirname "$0")/base.sh"

ship_base "$1"
ship_fix_timezone
printf 'API_TOKEN=not-a-real-token-for-evals\n' >.env
