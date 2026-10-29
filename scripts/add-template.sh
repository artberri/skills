#!/usr/bin/env bash
set -euo pipefail

# Copies a skill template into a project's .claude/skills/ folder, ready to be
# adapted with the adapt-skill skill.
#
# Usage: scripts/add-template.sh <skill> [project-dir]
# project-dir defaults to the current directory.

usage() {
	echo "usage: $0 <skill> [project-dir]" >&2
	exit 2
}

[ $# -ge 1 ] && [ $# -le 2 ] || usage

repo="$(cd "$(dirname "$0")/.." && pwd)"
skill="$1"
project="${2:-.}"
src="$repo/skills/templates/$skill"

if [ ! -f "$src/SKILL.md" ]; then
	echo "error: no template named '$skill'. Available:" >&2
	find "$repo/skills/templates" -mindepth 2 -maxdepth 2 -name SKILL.md -exec dirname {} \; |
		sed 's|.*/|  |' | sort >&2
	exit 1
fi

if [ ! -d "$project" ]; then
	echo "error: project directory '$project' does not exist" >&2
	exit 1
fi

dest="$(cd "$project" && pwd)/.claude/skills/$skill"
if [ -e "$dest" ]; then
	echo "error: $dest already exists; remove it first to replace it" >&2
	exit 1
fi

mkdir -p "$(dirname "$dest")"
cp -R "$src" "$dest"

echo "copied $skill to $dest"
echo "next: run '/adapt-skill $skill' in that project"
