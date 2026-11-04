#!/usr/bin/env bash
set -euo pipefail

# PreToolUse(Bash) hook: denies git commands the skills forbid in prose
# (staging everything, force-pushing, skipping signing or hooks), so the rule
# holds even when the model slips. The checks are in git-guardrails.jq.
# Opt out per shell or project with ARTBERRI_GIT_GUARDRAILS=0.

[ "${ARTBERRI_GIT_GUARDRAILS:-1}" = "0" ] && exit 0
command -v jq >/dev/null || exit 0

jq -c -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/git-guardrails.jq"
