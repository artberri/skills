#!/usr/bin/env bash
set -euo pipefail

# Copies a skill template into a project's .claude/skills/ folder, plus the
# template agents it uses into .claude/agents/, ready to be adapted with the
# adapt-skill skill.
#
# Usage: scripts/add-template.sh <skill> [project-dir]
# project-dir defaults to the current directory.

usage() {
	echo "usage: $0 <skill> [project-dir]" >&2
	exit 2
}

[ $# -ge 1 ] && [ $# -le 2 ] || usage

repo="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "$repo/scripts/lib.sh"
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

project="$(cd "$project" && pwd)"
dest="$project/.claude/skills/$skill"
if [ -e "$dest" ]; then
	echo "error: $dest already exists; remove it first to replace it" >&2
	exit 1
fi

mkdir -p "$(dirname "$dest")"
cp -R "$src" "$dest"
# The template's evals test the template, not the project's adapted copy.
rm -rf "$dest/evals"
echo "copied $skill to $dest"

for agent in $(skill_agents "$src/SKILL.md"); do
	if [ -f "$repo/agents/templates/$agent.md" ]; then
		agent_dest="$project/.claude/agents/$agent.md"
		# Another template may have brought it in already, and it may be
		# adapted by now.
		if [ -e "$agent_dest" ]; then
			echo "kept existing agent $agent_dest"
		else
			mkdir -p "$(dirname "$agent_dest")"
			cp "$repo/agents/templates/$agent.md" "$agent_dest"
			echo "copied agent $agent to $agent_dest"
		fi
	else
		echo "note: $skill uses the portable agent '$agent'; make sure it is installed"
	fi
done

echo "next: run '/adapt-skill $skill' in that project"
