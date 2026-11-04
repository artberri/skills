#!/usr/bin/env bash
set -euo pipefail

# Validates every skill and agent against the rules in AGENTS.md. Prints one
# line per problem and exits non-zero if there are any.

repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

errors=0
fail() {
	echo "error: $*" >&2
	errors=$((errors + 1))
}

warnings=0
warn() {
	echo "warning: $*" >&2
	warnings=$((warnings + 1))
}

valid_name() {
	printf '%s\n' "$1" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'
}

# Checks a skill's evals/ folder against the format scripts/evals/run.sh
# reads. A missing evals.json is only a warning for now, while the existing
# skills get their evals.
check_evals() {
	local skill_dir="$1" name="$2" evals triggers fixture
	evals="$skill_dir/evals/evals.json"
	triggers="$skill_dir/evals/triggers.json"

	if [ -f "$triggers" ] && ! jq -e '
		type == "array" and length > 0
		and all(.[]; (.query | type == "string" and length > 0) and (.should_trigger | type == "boolean"))
		and any(.[]; .should_trigger) and any(.[]; .should_trigger | not)
	' "$triggers" >/dev/null 2>&1; then
		fail "$triggers: needs {query, should_trigger} entries, at least one true and one false"
	fi

	if [ ! -f "$evals" ]; then
		warn "$skill_dir has no evals/evals.json"
		return
	fi
	if ! jq -e '.evals | type == "array" and length > 0' "$evals" >/dev/null 2>&1; then
		fail "$evals: needs an \"evals\" list with at least one eval"
		return
	fi
	[ "$(jq -r '.skill_name // ""' "$evals")" = "$name" ] || fail "$evals: skill_name must be '$name'"
	jq -e '[.evals[].id] | all(type == "number" and . == floor) and length == (unique | length)' "$evals" >/dev/null ||
		fail "$evals: ids must be unique whole numbers"
	jq -e 'all(.evals[];
		(.prompt | type == "string" and length > 0)
		and (.expectations | type == "array" and length > 0 and all(type == "string"))
		and (.followups // [] | type == "array" and all(type == "string"))
		and (.with_plugin // false | type == "boolean")
		and (.fixture // "" | type == "string"))' "$evals" >/dev/null ||
		fail "$evals: every eval needs a prompt and expectations (strings); followups is a list of strings, with_plugin true or false"
	for fixture in $(jq -r '.evals[].fixture // empty' "$evals" | sort -u); do
		if ! valid_name "$fixture"; then
			fail "$evals: fixture '$fixture' must be lowercase letters, digits and hyphens"
		elif [ ! -x "$skill_dir/evals/fixtures/$fixture.sh" ]; then
			fail "$evals: fixture '$fixture' needs an executable evals/fixtures/$fixture.sh"
		fi
	done
}

# Checks the rules skills and agents share: frontmatter, name format, marker
# rules for the bucket, and the bucket README listing.
check_entry() {
	local path="$1" file="$2" name="$3" bucket="$4"
	local readme link fm_name
	readme="$(dirname "$path")/README.md"

	valid_name "$name" || fail "$path: name must be lowercase letters, digits and hyphens"

	fm_name="$(frontmatter_field "$file" name)"
	[ "$fm_name" = "$name" ] || fail "$file: frontmatter name '$fm_name' does not match '$name'"

	[ -n "$(frontmatter_field "$file" description)" ] || fail "$file: missing description"

	if [ "$bucket" = portable ] && has_markers "$path"; then
		fail "$path: portable entries must not contain CUSTOMIZE markers"
	fi
	if [ "$bucket" = templates ] && ! has_markers "$path"; then
		fail "$path: templates need at least one CUSTOMIZE marker"
	fi

	if [ -d "$path" ]; then
		link="](./$name/SKILL.md)"
	else
		link="](./$name.md)"
	fi
	if [ -f "$readme" ] && ! grep -qF "$link" "$readme"; then
		fail "$readme does not list $name"
	fi
}

for kind in skills agents; do
	for bucket in portable templates drafts; do
		[ -f "$kind/$bucket/README.md" ] || fail "$kind/$bucket/README.md is missing"
	done
done

# Agents first, so skills can be checked against them.
agent_buckets=" "
for bucket in portable templates drafts; do
	for file in agents/"$bucket"/*.md; do
		[ -f "$file" ] || continue
		name="$(basename "$file" .md)"
		[ "$name" = README ] && continue
		check_entry "$file" "$file" "$name" "$bucket"
		case "$agent_buckets" in
		*" $name:"*) fail "$file: name '$name' is used in more than one bucket" ;;
		esac
		agent_buckets="$agent_buckets$name:$bucket "
	done
done

skill_names=""
for bucket in portable templates drafts; do
	for skill_dir in skills/"$bucket"/*/; do
		[ -d "$skill_dir" ] || continue
		skill_dir="${skill_dir%/}"
		name="$(basename "$skill_dir")"
		skill_md="$skill_dir/SKILL.md"

		# skill-creator's eval runs (gitignored), not skills.
		case "$name" in
		*-workspace) continue ;;
		esac

		if [ ! -f "$skill_md" ]; then
			fail "$skill_dir has no SKILL.md"
			continue
		fi

		check_entry "$skill_dir" "$skill_md" "$name" "$bucket"
		case " $skill_names " in
		*" $name "*) fail "$skill_dir: name '$name' is used in more than one bucket" ;;
		esac
		skill_names="$skill_names $name"

		# adapt-skill compares it with a project's copy to offer a refresh.
		if [ "$bucket" = templates ] &&
			! metadata_field "$skill_md" template-revision | grep -Eq '^[0-9]+$'; then
			fail "$skill_md: templates need metadata.template-revision, a whole number"
		fi
		# The skills CLI (skills.sh) finds every SKILL.md under skills/, so
		# only portable skills may be visible to it.
		internal="$(metadata_field "$skill_md" internal)"
		if [ "$bucket" = portable ] && [ -n "$internal" ]; then
			fail "$skill_md: portable skills must not set metadata.internal"
		fi
		if [ "$bucket" != portable ] && [ "$internal" != true ]; then
			fail "$skill_md: $bucket need metadata.internal: true, to hide them from the skills CLI"
		fi
		if [ -f "$skill_dir/SETUP.md" ] && has_markers "$skill_dir/SETUP.md"; then
			fail "$skill_dir/SETUP.md: setup guidance must not contain CUSTOMIZE markers"
		fi

		if [ "$bucket" != drafts ]; then
			if command -v jq >/dev/null; then
				check_evals "$skill_dir" "$name"
			else
				fail "jq is needed to check $skill_dir/evals"
			fi
		fi

		for agent in $(skill_agents "$skill_md"); do
			case "$agent_buckets" in
			*" $agent:"*)
				agent_bucket="${agent_buckets#*" $agent:"}"
				agent_bucket="${agent_bucket%% *}"
				;;
			*)
				fail "$skill_md: needs agent '$agent', which does not exist"
				continue
				;;
			esac
			case "$bucket:$agent_bucket" in
			portable:portable | templates:portable | templates:templates | drafts:*) ;;
			*) fail "$skill_md: a $bucket skill cannot use the $agent_bucket agent '$agent'" ;;
			esac
		done
	done
done

# The plugin loads skills/portable/ as a folder, but its agents one by one,
# and Claude Code also loads any .md file at the top of agents/ on its own.
manifest=.claude-plugin/plugin.json
for file in agents/*.md; do
	[ -f "$file" ] && fail "$file: agents go in a bucket folder; the plugin would load this one"
done
if ! command -v jq >/dev/null; then
	fail "jq is needed to check $manifest"
elif ! jq -e . "$manifest" >/dev/null 2>&1; then
	fail "$manifest is missing or not valid JSON"
else
	[ "$(jq -c .skills "$manifest")" = '["./skills/portable/"]' ] ||
		fail "$manifest: skills must be [\"./skills/portable/\"]"
	expected="$(for file in agents/portable/*.md; do
		[ "$(basename "$file")" = README.md ] || echo "./$file"
	done | sort)"
	listed="$(jq -r '.agents // [] | .[]' "$manifest" | sort)"
	[ "$listed" = "$expected" ] ||
		fail "$manifest: agents must list exactly the portable agents:$(printf '\n%s' "$expected")"
fi

# ocr-review, its agent and setup-ocr each run OCR through npx, pinned. A
# version that drifts in one of them reviews with different rules than the
# preview and setup show.
ocr_pins="$(grep -rhoE --exclude-dir='*-workspace' 'open-code-review@[^[:space:]`"]+' skills agents | sort -u || true)"
if [ "$(printf '%s' "$ocr_pins" | grep -c .)" -gt 1 ]; then
	fail "Open Code Review is pinned to more than one version; use the same one everywhere:$(printf '\n%s' "$ocr_pins")"
fi

if [ "$errors" -gt 0 ]; then
	echo "$errors problem(s) found" >&2
	exit 1
fi
if [ "$warnings" -gt 0 ]; then
	echo "all skills and agents ok, with $warnings warning(s)"
else
	echo "all skills and agents ok"
fi
