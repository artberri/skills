#!/usr/bin/env bash
set -euo pipefail

# Validates every skill against the rules in AGENTS.md. Prints one line per
# problem and exits non-zero if there are any.

repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"

errors=0
fail() {
	echo "error: $*" >&2
	errors=$((errors + 1))
}

# Prints the value of a top-level frontmatter field from a SKILL.md.
frontmatter_field() {
	awk -v key="$2" '
		NR == 1 && $0 != "---" { exit }
		NR > 1 && $0 == "---" { exit }
		NR > 1 && index($0, key ":") == 1 {
			sub("^" key ":[ \t]*", "")
			print
			exit
		}
	' "$1"
}

names=""

for bucket in portable templates drafts; do
	dir="skills/$bucket"
	readme="$dir/README.md"
	[ -f "$readme" ] || fail "$readme is missing"

	for skill_dir in "$dir"/*/; do
		[ -d "$skill_dir" ] || continue
		skill_dir="${skill_dir%/}"
		name="$(basename "$skill_dir")"
		skill_md="$skill_dir/SKILL.md"

		if [ ! -f "$skill_md" ]; then
			fail "$skill_dir has no SKILL.md"
			continue
		fi

		if ! printf '%s\n' "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
			fail "$skill_dir: folder name must be lowercase letters, digits and hyphens"
		fi

		fm_name="$(frontmatter_field "$skill_md" name)"
		[ "$fm_name" = "$name" ] || fail "$skill_md: frontmatter name '$fm_name' does not match folder '$name'"

		[ -n "$(frontmatter_field "$skill_md" description)" ] || fail "$skill_md: missing description"

		case " $names " in
		*" $name "*) fail "$skill_dir: skill name '$name' is used in more than one bucket" ;;
		esac
		names="$names $name"

		has_markers=0
		# Only a marker at the start of a line counts, so skills can quote the
		# syntax inline (as adapt-skill does).
		if grep -rqE '^[[:space:]]*<!-- CUSTOMIZE:' "$skill_dir"; then
			has_markers=1
		fi
		if [ "$bucket" = portable ] && [ "$has_markers" -eq 1 ]; then
			fail "$skill_dir: portable skills must not contain CUSTOMIZE markers"
		fi
		if [ "$bucket" = templates ] && [ "$has_markers" -eq 0 ]; then
			fail "$skill_dir: templates need at least one CUSTOMIZE marker"
		fi

		if [ -f "$readme" ] && ! grep -qF "](./$name/SKILL.md)" "$readme"; then
			fail "$readme does not list $name"
		fi
	done
done

if [ "$errors" -gt 0 ]; then
	echo "$errors problem(s) found" >&2
	exit 1
fi
echo "all skills ok"
