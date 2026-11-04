#!/usr/bin/env bash
set -euo pipefail

# Runs add-template.sh on throwaway projects and checks where it puts the
# template. Set TEST_SHELL to another shell (for example /bin/bash on macOS, which
# is 3.2) to run the script with it.

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/add-template.sh"
shell="${TEST_SHELL:-bash}"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
failures=0
n=0

# project: makes a new empty project folder and sets p to it. Not called in
# $(...), so the counter survives.
project() {
	n=$((n + 1))
	p="$root/p$n"
	mkdir -p "$p"
}

# expect <name> <expected exit> <path that must exist, or -> <project> [args...]
expect() {
	local name="$1" code="$2" path="$3" dir="$4" actual=0
	shift 4
	"$shell" "$script" "$@" "$dir" >"$root/out" 2>&1 || actual=$?
	if [ "$actual" != "$code" ]; then
		printf 'FAIL: %s: exit %s, expected %s\n' "$name" "$actual" "$code" >&2
		sed 's/^/  /' "$root/out" >&2
		failures=$((failures + 1))
	elif [ "$path" != - ] && [ ! -e "$dir/$path" ]; then
		printf 'FAIL: %s: %s was not created\n' "$name" "$path" >&2
		failures=$((failures + 1))
	fi
}

project
expect "empty project goes to .claude/skills" 0 .claude/skills/ship/SKILL.md "$p" ship
for gone in SETUP.md evals; do
	if [ -e "$p/.claude/skills/ship/$gone" ]; then
		echo "FAIL: $gone was copied into the project" >&2
		failures=$((failures + 1))
	fi
done
expect "an existing copy is not replaced" 1 - "$p" ship

project
touch "$p/AGENTS.md"
expect "AGENTS.md only goes to .agents/skills" 0 .agents/skills/ship/SKILL.md "$p" ship

project
touch "$p/AGENTS.md" "$p/CLAUDE.md"
expect "CLAUDE.md goes to .claude/skills" 0 .claude/skills/ship/SKILL.md "$p" ship

project
mkdir -p "$p/.github/skills/review" && touch "$p/.github/skills/review/SKILL.md" "$p/CLAUDE.md"
expect "the folder with skills wins over CLAUDE.md" 0 .github/skills/ship/SKILL.md "$p" ship

project
mkdir -p "$p/.github/skills/a" "$p/.agents/skills/b"
touch "$p/.github/skills/a/SKILL.md" "$p/.agents/skills/b/SKILL.md"
expect "skills in two folders needs --dir" 1 - "$p" ship
expect "--dir picks the folder" 0 .agents/skills/ship/SKILL.md "$p" --dir .agents/skills ship
expect "--dir= works too" 0 .github/skills/create-plan/SKILL.md "$p" --dir=.github/skills/ create-plan

project
expect "--dir outside the project is refused" 1 - "$p" --dir ../elsewhere ship
expect "--dir absolute is refused" 1 - "$p" --dir /tmp/skills ship
expect "unknown template" 1 - "$p" no-such-template

if [ "$failures" -gt 0 ]; then
	echo "$failures failure(s)" >&2
	exit 1
fi
# shellcheck disable=SC2016 # expanded by the shell under test, not this one
echo "add-template.sh: all cases passed with bash $("$shell" -c 'echo "$BASH_VERSION"')"
