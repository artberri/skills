#!/usr/bin/env bash
set -euo pipefail

# Runs git-guardrails.sh on a table of commands and checks which it denies.

hook="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/git-guardrails.sh"
failures=0

check() {
	local expected="$1" command="$2" output actual
	output="$(jq -n --arg command "$command" '{tool_name: "Bash", tool_input: {command: $command}}' | ARTBERRI_GIT_GUARDRAILS=1 "$hook")"
	if [ -n "$output" ]; then actual=deny; else actual=allow; fi
	if [ "$actual" != "$expected" ]; then
		printf 'FAIL: expected %s, got %s: %s\n' "$expected" "$actual" "$command" >&2
		failures=$((failures + 1))
	fi
}

nl='
'

# Staging everything.
check deny 'git add -A'
check deny 'git add --all'
check deny 'git add -vA'
check deny 'git add .'
check deny 'git add -- :/'
check deny 'cd sub && git add .'
check deny 'git -C repo add -A'
check deny 'GIT_DIR=.git git add -A'
check allow 'git add src/a.ts README.md'
check allow 'git add -p src/a.ts'
check allow 'git add -u'

# Force-pushing.
check deny 'git push --force'
check deny 'git push -f origin main'
check deny 'git push -uf origin feature'
check deny 'git push origin +main'
check allow 'git push --force-with-lease'
check allow 'git push --force-with-lease=main:abc123 origin main'
check allow 'git push --force-if-includes --force-with-lease'
check allow 'git push -u origin feature'
check allow 'git push -o ci.skip origin feature'

# Signing.
check deny 'git commit --no-gpg-sign -m "fix: thing"'
check deny 'git -c commit.gpgsign=false commit -m "fix: thing"'
check deny 'git -c "commit.gpgSign=false" commit -m x'
check deny 'git config commit.gpgsign false'
check deny 'git config --local --unset commit.gpgsign'
check deny 'git rebase --no-gpg-sign main'
check allow 'git config commit.gpgsign'
check allow 'git config commit.gpgsign true'
check allow 'git -c commit.gpgsign=true commit -m x'

# Skipping hooks.
check deny 'git commit --no-verify -m "fix: thing"'
check deny 'git commit -n -m x'
check deny 'git commit -anm x'
check deny 'git push --no-verify'
check allow 'git commit -m "fix: thing"'
check allow 'git commit -mn'
check allow 'git push -n origin feature'

# Mentions in messages, heredocs, comments and other programs.
check allow 'git commit -m "docs: never use git add -A or --no-verify"'
check allow "git commit -m 'never git push --force'"
check allow "git commit -F - <<'EOF'${nl}docs: say never git push --force${nl}${nl}Or git add -A, or --no-gpg-sign.${nl}EOF"
check allow "cat <<EOF >notes.md${nl}git add -A${nl}EOF${nl}git add notes.md"
check allow 'git status # then never git add -A'
check allow 'echo git add -A'
check allow 'grep -- --no-verify skills/commit/SKILL.md'
check allow 'git log --oneline -5'
check deny "git add a.txt${nl}git push --force"
check deny "git commit -F - <<'EOF'${nl}msg${nl}EOF${nl}git push -f"

# Opting out.
output="$(jq -n '{tool_input: {command: "git add -A"}}' | ARTBERRI_GIT_GUARDRAILS=0 "$hook")"
if [ -n "$output" ]; then
	echo 'FAIL: ARTBERRI_GIT_GUARDRAILS=0 should turn the hook off' >&2
	failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
	echo "$failures failed" >&2
	exit 1
fi
echo 'all passed'
