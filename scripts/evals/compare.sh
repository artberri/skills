#!/usr/bin/env bash
set -euo pipefail

# Compares a skill's evals with the skill as it was at a base ref.
#
# Usage: scripts/evals/compare.sh <skill> [--base <ref>] [eval-id...]
#
# Exports <ref> (default origin/main) and runs the working tree's evals twice
# with scripts/evals/run.sh: once against that export, once against the working
# tree. Prints each expectation as passed before, passed now, and gained, lost
# or unchanged. Exits non-zero if any expectation was lost.
#
# Needs the same auth as run.sh.

usage() {
	sed -n '/^# Usage:/,/^# Exports/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d' >&2
	exit 2
}

die() {
	echo "error: $*" >&2
	exit 1
}

repo="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
	usage
fi
[ $# -ge 1 ] || usage
skill="$1"
shift
base="origin/main"
ids=""
while [ $# -gt 0 ]; do
	case "$1" in
	--base)
		shift
		[ $# -ge 1 ] || usage
		base="$1"
		;;
	[0-9]*) ids="$ids $1" ;;
	-h | --help) usage ;;
	*) usage ;;
	esac
	shift
done

for tool in git jq tar; do
	command -v "$tool" >/dev/null || die "$tool is needed"
done
git rev-parse --verify "$base^{commit}" >/dev/null 2>&1 || die "no such ref: $base"

skill_dir=""
for bucket in portable templates drafts; do
	if [ -f "$repo/skills/$bucket/$skill/SKILL.md" ]; then
		skill_dir="$repo/skills/$bucket/$skill"
	fi
done
[ -n "$skill_dir" ] || die "no skill named '$skill'"
[ -f "$skill_dir/evals/evals.json" ] || die "$skill has no evals/evals.json"
# shellcheck disable=SC2086 # ids are separate words, like run.sh
[ -n "$ids" ] || ids="$(jq -r '.evals[].id' "$skill_dir/evals/evals.json")"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/skill-compare.XXXXXX")"
cleanup() {
	if [ -n "${tmp:-}" ] && [ -d "$tmp" ]; then
		rm -rf "$tmp"
	fi
}
trap cleanup EXIT

mkdir -p "$tmp/base"
git archive "$base" | tar -x -C "$tmp/base"

old_skill=""
for bucket in portable templates drafts; do
	if [ -f "$tmp/base/skills/$bucket/$skill/SKILL.md" ]; then
		old_skill="$tmp/base/skills/$bucket/$skill"
	fi
done
[ -n "$old_skill" ] || die "$skill does not exist at $base"

# The working tree's evals, on both copies, so a new expectation is graded
# against the old skill too.
rm -rf "$old_skill/evals"
mkdir -p "$old_skill/evals"
cp "$skill_dir/evals/evals.json" "$old_skill/evals/evals.json"
if [ -d "$skill_dir/evals/fixtures" ]; then
	cp -R "$skill_dir/evals/fixtures" "$old_skill/evals/fixtures"
	for fixture in "$old_skill"/evals/fixtures/*.sh; do
		[ -f "$fixture" ] || continue
		chmod +x "$fixture"
	done
fi

run_evals() {
	local label="$1"
	shift
	local log="$tmp/$label.log"
	echo "===== $label ====="
	# shellcheck disable=SC2086 # ids are separate arguments
	"$repo/scripts/evals/run.sh" "$skill" "$@" $ids | tee "$log"
	sed -n 's/^results: //p' "$log" | tail -n 1 >"$tmp/$label.workspace"
	[ -s "$tmp/$label.workspace" ] || die "$label run did not report a results folder"
}

run_evals before --skill-dir "$old_skill"
before_ws="$(tr -d '\r' <"$tmp/before.workspace")"
mkdir -p "$skill_dir-workspace"
before_saved="$skill_dir-workspace/before-$(basename "$before_ws")"
rm -rf "$before_saved"
cp -R "$before_ws" "$before_saved"
before_ws="$before_saved"

run_evals now
now_ws="$(tr -d '\r' <"$tmp/now.workspace")"

lost=0
gained=0
unchanged=0
echo "base: $base ($(git rev-parse --short "$base"))"
echo "now: working tree"
echo "before results: $before_ws"
echo "now results: $now_ws"
echo

# shellcheck disable=SC2086 # ids are separate words, like run.sh
for id in $ids; do
	before_file="$before_ws/eval-$id/grading.json"
	now_file="$now_ws/eval-$id/grading.json"
	if [ ! -f "$before_file" ] || [ ! -f "$now_file" ]; then
		echo "eval $id: missing grading.json" >&2
		lost=$((lost + 1))
		continue
	fi
	jq -nr --slurpfile before "$before_file" --slurpfile now "$now_file" '
		def passed_of($rows; $text):
			if any($rows[]; .text == $text) | not then "missing"
			elif any($rows[]; .text == $text and .passed) then "pass"
			else "fail"
			end;
		def mark($b; $n):
			if $b == "pass" and $n != "pass" then "lost"
			elif $n == "pass" and $b != "pass" then "gained"
			else "unchanged"
			end;
		($now[0].expectations // []) as $ne
		| ($before[0].expectations // []) as $be
		| ([$ne[].text] + [$be[].text | select(. as $t | any($ne[]; .text == $t) | not)]) as $texts
		| $texts[]
		| . as $text
		| passed_of($be; $text) as $b
		| passed_of($ne; $text) as $n
		| [($text | gsub("\n"; " ") | gsub("\r"; "") | gsub("[|]"; "/")), $b, $n, mark($b; $n)]
		| @tsv
	' | tr -d '\r' >"$tmp/rows-$id.tsv"
	echo "eval $id"
	echo "| expectation | before | now | result |"
	echo "| --- | --- | --- | --- |"
	while IFS=$'\t' read -r text before_pass now_pass result; do
		[ -n "$text" ] || continue
		echo "| $text | $before_pass | $now_pass | $result |"
		case "$result" in
		lost) lost=$((lost + 1)) ;;
		gained) gained=$((gained + 1)) ;;
		unchanged) unchanged=$((unchanged + 1)) ;;
		esac
	done <"$tmp/rows-$id.tsv"
	echo
done

echo "$unchanged unchanged, $gained gained, $lost lost"
[ "$lost" -eq 0 ]
