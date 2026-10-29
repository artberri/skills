#!/usr/bin/env bash
set -euo pipefail

# PostToolUse(Bash) hook: after `gh pr create`, or a `git push` to a PR the
# ocr-review skill already reviewed, tell Claude to run that review without
# asking, unless the change is too small to need one.
# Opt out per shell or project with OCR_REVIEW_OFFER=0.

[ "${OCR_REVIEW_OFFER:-1}" = "0" ] && exit 0
command -v jq >/dev/null || exit 0
command -v gh >/dev/null || exit 0

script="$(cd "$(dirname "$0")/.." && pwd)/scripts/ocr-review.ts"
input="$(cat)"

# Matching the command text can't tell a heredoc line from an invocation, so
# each trigger is confirmed by real state: the URL `gh pr create` prints, or
# the PR's head on GitHub having moved past the last OCR review (quiet pushes
# included).
invokes() {
	jq -e --arg program "$1" '.tool_input.command // "" | test("(\\A|[;&|(\\n])\\s*(\\w+=\\S*\\s+)*" + $program + "\\b")' <<<"$input" >/dev/null
}

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
if invokes "gh pr create"; then
	pr_number="$(jq -r '.tool_response.stdout // "" | capture("/pull/(?<number>\\d+)").number // empty' <<<"$input")"
	[ -n "$pr_number" ] || exit 0
	context="PR #$pr_number was just created. Run the OCR review on it now, without asking the user: invoke the ocr-review skill for PR #$pr_number. Skip it only when the PR is docs-only or a very small, obvious change (a typo, a one-line fix), and say that you skipped it."
elif invokes "git push"; then
	command -v node >/dev/null || exit 0
	pr_view="$(gh pr view --json number,headRefOid,baseRefName --jq '"\(.number) \(.headRefOid) \(.baseRefName)"' 2>/dev/null)" || exit 0
	read -r pr_number pr_head_sha base_ref <<<"$pr_view"
	[ -n "${pr_number:-}" ] || exit 0

	last_reviewed_sha="$(node "$script" last-reviewed-sha "$pr_number" 2>/dev/null | tail -1)" || exit 0
	[ -n "$last_reviewed_sha" ] || exit 0
	[ "$last_reviewed_sha" = "$pr_head_sha" ] && exit 0

	# Merges of the base branch bring none of the PR's own changes, so a push
	# of only those is skipped. A merge of any other branch, an own commit, or
	# a sha this checkout lacks still prompts. Conflict fixes inside a base
	# merge do not.
	if [ -n "${base_ref:-}" ] &&
		git rev-parse --verify --quiet "$last_reviewed_sha^{commit}" >/dev/null &&
		git rev-parse --verify --quiet "$pr_head_sha^{commit}" >/dev/null; then
		not_base_merges="$(git rev-list --first-parent "$last_reviewed_sha..$pr_head_sha" | while read -r commit; do
			git merge-base --is-ancestor "$commit^2" "origin/$base_ref" 2>/dev/null || echo "$commit"
		done)"
		[ -z "$not_base_merges" ] && exit 0
	fi

	# A heredoc line can still look like a push; prompting once per PR head
	# keeps a false match from re-running a review.
	offered_file="$(git rev-parse --git-dir)/ocr-review-offered"
	[ "$(cat "$offered_file" 2>/dev/null || true)" = "$pr_number $pr_head_sha" ] && exit 0
	echo "$pr_number $pr_head_sha" >"$offered_file"

	context="New commits were pushed to PR #$pr_number, which the OCR review last reviewed at ${last_reviewed_sha:0:10}. Review them now, without asking the user: invoke the ocr-review skill with --incremental for PR #$pr_number. Skip it only when the new commits are docs-only or very small, obvious changes (a lint fix, a one-line correction), and say that you skipped it."
else
	exit 0
fi

jq -n --arg context "$context" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $context}}'
