#!/usr/bin/env bash
set -euo pipefail

# Copies a skill template into a project's skills folder, ready to be adapted
# with the adapt-skill skill or by hand. Template agents it uses go into
# .claude/agents/ when the skill goes into .claude/skills/: they are Claude
# Code subagents.
#
# Usage: scripts/add-template.sh [--dir <skills-folder>] <skill> [project-dir]
#
# project-dir defaults to the current directory. --dir is the skills folder,
# relative to the project (for example .agents/skills). Without it, the
# script picks the folder the way adapt-skill does: the one the project
# already keeps skills in, otherwise .agents/skills/ when the project has an
# AGENTS.md but no CLAUDE.md, otherwise .claude/skills/.

# The folders agents read project skills from, in the order adapt-skill
# lists them.
skill_dirs=".claude/skills .agents/skills .github/skills .gemini/skills"

usage() {
	echo "usage: $0 [--dir <skills-folder>] <skill> [project-dir]" >&2
	exit 2
}

dir=""
args=()
while [ $# -gt 0 ]; do
	case "$1" in
	--dir)
		[ $# -ge 2 ] || usage
		dir="$2"
		shift 2
		;;
	--dir=*)
		dir="${1#--dir=}"
		shift
		;;
	-h | --help) usage ;;
	-*)
		echo "error: unknown option $1" >&2
		usage
		;;
	*)
		args+=("$1")
		shift
		;;
	esac
done
[ "${#args[@]}" -ge 1 ] && [ "${#args[@]}" -le 2 ] || usage

repo="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "$repo/scripts/lib.sh"
skill="${args[0]}"
project="${args[1]:-.}"
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

# count_skills <folder>: how many skills (folders with a SKILL.md) it holds.
count_skills() {
	find "$1" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | grep -c . || true
}

if [ -n "$dir" ]; then
	case "$dir" in
	/* | *..*)
		echo "error: --dir must be a folder inside the project, like .agents/skills" >&2
		exit 1
		;;
	esac
	dir="${dir%/}"
else
	used=""
	for candidate in $skill_dirs; do
		n="$(count_skills "$project/$candidate")"
		[ "$n" -gt 0 ] && used="$used$candidate ($n skills)
"
	done
	if [ "$(printf '%s' "$used" | grep -c .)" -gt 1 ]; then
		echo "error: the project keeps skills in more than one folder; choose one with --dir:" >&2
		printf '%s' "$used" | sed 's/^/  /' >&2
		exit 1
	elif [ -n "$used" ]; then
		dir="${used%% (*}"
	elif [ -f "$project/AGENTS.md" ] && [ ! -e "$project/CLAUDE.md" ]; then
		dir=".agents/skills"
	else
		dir=".claude/skills"
	fi
fi

dest="$project/$dir/$skill"
if [ -e "$dest" ]; then
	echo "error: $dest already exists; remove it first to replace it" >&2
	exit 1
fi

mkdir -p "$(dirname "$dest")"
cp -R "$src" "$dest"
# The template's evals test the template, not the project's adapted copy, and
# SETUP.md only guides adapt-skill.
rm -rf "$dest/evals" "$dest/SETUP.md"
echo "copied $skill to $dest"

for agent in $(skill_agents "$src/SKILL.md"); do
	if [ ! -f "$repo/agents/templates/$agent.md" ]; then
		echo "note: $skill uses the portable agent '$agent'; make sure it is installed"
	elif [ "$dir" != ".claude/skills" ]; then
		echo "note: $skill uses the Claude Code agent '$agent', which $dir/ doesn't take; your agent may not support it"
	else
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
	fi
done

echo "next: run '/adapt-skill $skill' in that project, or fill in its CUSTOMIZE markers by hand"
