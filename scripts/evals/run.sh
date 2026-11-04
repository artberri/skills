#!/usr/bin/env bash
set -euo pipefail

# Runs a skill's evals with `claude -p`, each in a throwaway repository, and
# grades them.
#
# Usage:
#   scripts/evals/run.sh <skill> [--keep] [--no-grade] [eval-id...]
#   scripts/evals/run.sh <skill> --triggers [--keep]
#
# For each eval in <skill>/evals/evals.json, it:
#   1. builds the eval's fixture (evals/fixtures/<fixture>.sh) in a temporary
#      folder outside this repo, with git isolated (a throwaway global config,
#      no signing) and the `gh` stub from stubs/ first on PATH;
#   2. installs the skill into that repository's .claude/skills/, git-excluded,
#      or loads this repo as a plugin when the eval sets "with_plugin";
#   3. runs the prompt, then each of the eval's "followups" in the same
#      session, with a temporary CLAUDE_CONFIG_DIR: none of your settings,
#      plugins, hooks or memory, and with permission checks skipped when the
#      eval sets "skip_permissions";
#   4. saves the replies, the repository's state and the gh calls to
#      <skill>-workspace/<timestamp>/eval-<id>/outputs/ and grades the
#      expectations into grading.json, in skill-creator's format.
#
# --triggers runs each query in evals/triggers.json several times, each in a
# fresh repository from evals/fixtures/triggers.sh (an empty folder without
# one), with the skill installed as in step 2 and this repo's plugin loaded,
# so its sibling skills compete for the query. A run stops at the first tool
# call: the query triggered the skill if that call invokes it.
#
# --keep keeps the temporary folders for inspection. EVAL_MODEL and
# EVAL_GRADER_MODEL choose the models; EVAL_TRIGGER_RUNS (3) and
# EVAL_TRIGGER_TIMEOUT (60 seconds) tune --triggers.
#
# Auth: a temporary config folder can't see a login stored in the macOS
# Keychain, so set CLAUDE_CODE_OAUTH_TOKEN (create one with
# `claude setup-token`; it uses your subscription) or ANTHROPIC_API_KEY.

usage() {
	sed -n '/^# Usage:/,/^# For each eval/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d' >&2
	exit 2
}

die() {
	echo "error: $*" >&2
	exit 1
}

repo="$(cd "$(dirname "$0")/../.." && pwd)"
evals_dir="$repo/scripts/evals"
# shellcheck source=scripts/lib.sh
. "$repo/scripts/lib.sh"

[ $# -ge 1 ] || usage
skill="$1"
shift
keep=0
grade=1
triggers=0
ids=""
while [ $# -gt 0 ]; do
	case "$1" in
	--keep) keep=1 ;;
	--no-grade) grade=0 ;;
	--triggers) triggers=1 ;;
	-h | --help) usage ;;
	[0-9]*) ids="$ids $1" ;;
	*) usage ;;
	esac
	shift
done

skill_dir=""
bucket=""
for b in portable templates drafts; do
	if [ -f "$repo/skills/$b/$skill/SKILL.md" ]; then
		skill_dir="$repo/skills/$b/$skill"
		bucket="$b"
	fi
done
[ -n "$skill_dir" ] || die "no skill named '$skill'"

for tool in claude git jq; do
	command -v "$tool" >/dev/null || die "$tool is needed"
done
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
	die "set CLAUDE_CODE_OAUTH_TOKEN (run 'claude setup-token' once) or ANTHROPIC_API_KEY: evals run with a temporary config folder, which can't see your usual login"
fi

workspace="$skill_dir-workspace/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$workspace"

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/skill-evals.XXXXXX")"
cleanup() {
	if [ "$keep" = 1 ]; then
		echo "kept the temporary folders in $tmp_root"
	elif [ -n "$tmp_root" ] && [ -d "$tmp_root" ]; then
		rm -rf "$tmp_root"
	fi
}
trap cleanup EXIT

cat >"$tmp_root/gitconfig" <<'EOF'
[user]
	name = Eval
	email = eval@example.com
[commit]
	gpgsign = false
[tag]
	gpgsign = false
[init]
	defaultBranch = main
EOF
export GIT_CONFIG_GLOBAL="$tmp_root/gitconfig" GIT_CONFIG_NOSYSTEM=1
export PATH="$evals_dir/stubs:$PATH"
export EVAL_LIB="$evals_dir/fixture-lib.sh"

model_args=()
[ -n "${EVAL_MODEL:-}" ] && model_args=(--model "$EVAL_MODEL")
grader_model_args=()
[ -n "${EVAL_GRADER_MODEL:-}" ] && grader_model_args=(--model "$EVAL_GRADER_MODEL")

# prepare <tmp> <fixture> <with-plugin> <log>: points CLAUDE_CONFIG_DIR and
# EVAL_STATE_DIR into <tmp>, builds the fixture (none if empty) and installs
# the skill. Sets `work`, the folder to run in, and `plugin_args`.
prepare() {
	local tmp="$1" fixture="$2" with_plugin="$3" log="$4" agent agent_file
	mkdir -p "$tmp/fixture" "$tmp/config" "$tmp/state"
	export CLAUDE_CONFIG_DIR="$tmp/config" EVAL_STATE_DIR="$tmp/state"
	if [ -n "$fixture" ] &&
		! (cd "$tmp/fixture" && "$skill_dir/evals/fixtures/$fixture.sh" "$tmp/fixture") >"$log" 2>&1; then
		return 1
	fi
	work="$tmp/fixture/repo"
	mkdir -p "$work"
	# What the fixture left, so git_state can show the patches of the commits
	# made during the run.
	start_refs="$tmp/start-refs"
	: >"$start_refs"
	if [ -d "$work/.git" ]; then
		git -C "$work" for-each-ref --format='%(objectname)' >"$start_refs"
	fi

	plugin_args=()
	[ "$with_plugin" = true ] && plugin_args=(--plugin-dir "$repo")
	# A portable skill comes with the plugin; anything else is installed into
	# the project, as adapt-skill would, with the agents it uses.
	if [ "$with_plugin" != true ] || [ "$bucket" != portable ]; then
		mkdir -p "$work/.claude/skills"
		cp -R "$skill_dir" "$work/.claude/skills/$skill"
		rm -rf "$work/.claude/skills/$skill/evals" "$work/.claude/skills/$skill/SETUP.md"
		installed="/.claude/skills/$skill/"
		for agent in $(skill_agents "$skill_dir/SKILL.md"); do
			agent_file="$(find "$repo/agents/templates" "$repo/agents/portable" -name "$agent.md" -print -quit)"
			[ -n "$agent_file" ] || continue
			mkdir -p "$work/.claude/agents"
			cp "$agent_file" "$work/.claude/agents/"
			installed="$installed /.claude/agents/$agent.md"
		done
		# So what this installed doesn't show up as a change to commit. Only
		# that: anything the run itself writes under .claude/ stays visible,
		# as it would in a real project.
		if [ -d "$work/.git" ]; then
			mkdir -p "$work/.git/info"
			# shellcheck disable=SC2086 # one path per word
			printf '%s\n' $installed >>"$work/.git/info/exclude"
		fi
	fi
}

# agent_args: the flags every agent run shares. Claude Code tells the agent
# the name on the account behind the token, which never matches the eval's
# git identity, so the agent is told that identity is the right one;
# otherwise a skill that checks the identity stops there.
agent_args() {
	printf '%s\n' --output-format stream-json --verbose \
		--allowedTools "Bash,Read,Edit,Write,Glob,Grep,Skill" \
		--disallowedTools "AskUserQuestion" \
		--append-system-prompt "The git identity configured for this repository, Eval <eval@example.com>, is the one its commits should use."
}

# first_tool <transcript>: prints the transcript's first tool call, as
# Skill(<skill>), Bash(<start of the command>) or the tool name, or nothing.
first_tool() {
	jq -Rrn '[inputs | fromjson? | select(.type == "assistant") | .message.content[]?
		| select(.type == "tool_use")
		| if .name == "Skill" then "Skill(\(.input.skill // ""))"
		elif .name == "Bash" then "Bash(\(.input.command // "" | split("\n")[0] | .[0:60]))"
		else .name end
	] | first // empty' "$1"
}

# trigger_run <query> <tmp>: runs the query once and prints its first tool
# call, "(no tool)", "(timeout)" or "(fixture failed)".
trigger_run() {
	local query="$1" tmp="$2" transcript pid alive first waited=0 args=()
	if ! prepare "$tmp" "$trigger_fixture" true "$tmp/fixture.log"; then
		echo "(fixture failed)"
		return
	fi
	while IFS= read -r arg; do args+=("$arg"); done < <(agent_args)
	transcript="$tmp/transcript.jsonl"
	(
		cd "$work"
		exec claude -p "$query" "${args[@]}" \
			${plugin_args[@]+"${plugin_args[@]}"} \
			${model_args[@]+"${model_args[@]}"}
	) >"$transcript" 2>"$tmp/stderr.log" &
	pid=$!
	while :; do
		alive=0
		kill -0 "$pid" 2>/dev/null && alive=1
		first="$(first_tool "$transcript")"
		[ -n "$first" ] && break
		if [ "$alive" = 0 ]; then
			first="(no tool)"
			break
		fi
		if [ "$waited" -ge "${EVAL_TRIGGER_TIMEOUT:-60}" ]; then
			first="(timeout)"
			break
		fi
		sleep 1
		waited=$((waited + 1))
	done
	# Stop before the agent acts on the query.
	kill "$pid" 2>/dev/null || true
	wait "$pid" 2>/dev/null || true
	echo "$first"
}

run_triggers() {
	local triggers_file="$skill_dir/evals/triggers.json" count q query should runs r tmp results
	[ -f "$triggers_file" ] || die "$skill has no evals/triggers.json"
	trigger_fixture=""
	[ -x "$skill_dir/evals/fixtures/triggers.sh" ] && trigger_fixture=triggers
	runs="${EVAL_TRIGGER_RUNS:-3}"
	results="$workspace/triggers-result.jsonl"
	: >"$results"
	count="$(jq length "$triggers_file")"
	q=0
	while [ "$q" -lt "$count" ]; do
		query="$(jq -r --argjson q "$q" '.[$q].query' "$triggers_file")"
		should="$(jq -r --argjson q "$q" '.[$q].should_trigger' "$triggers_file")"
		# The runs of one query go in parallel; each has its own folders.
		r=0
		while [ "$r" -lt "$runs" ]; do
			tmp="$tmp_root/trigger-$q-$r"
			mkdir -p "$tmp"
			trigger_run "$query" "$tmp" >"$tmp/first" &
			r=$((r + 1))
		done
		wait
		cat "$tmp_root"/trigger-"$q"-*/first |
			jq -Rsc --arg query "$query" --argjson should "$should" --arg skill "$skill" '
				split("\n") | map(select(length > 0)) as $first
				| ($first | map(select(. == "Skill(\($skill))" or endswith(":\($skill))"))) | length) as $hits
				| (if ($first | length) == 0 then 0 else $hits / ($first | length) end) as $rate
				| {query: $query, should_trigger: $should, triggers: $hits, runs: ($first | length),
					trigger_rate: $rate, pass: (if $should then $rate >= 0.5 else $rate < 0.5 end),
					first_tools: $first}' >>"$results"
		jq -r '"\(if .pass then "PASS" else "FAIL" end) \(.triggers)/\(.runs) expected=\(.should_trigger): \(.query)\n     first calls: \(.first_tools | join(", "))"' <<<"$(tail -n 1 "$results")"
		q=$((q + 1))
	done
	jq -s '{skill_name: $skill, results: ., summary: {total: length, passed: (map(select(.pass)) | length), failed: (map(select(.pass | not)) | length)}}' \
		--arg skill "$skill" "$results" >"$workspace/triggers-result.json"
	rm -f "$results"
	jq -r '"\(.summary.passed)/\(.summary.total) trigger queries passed"' "$workspace/triggers-result.json"
	echo "details: $workspace/triggers-result.json"
}

# turn <n> <message> [session-id]: sends one message in the eval's repository,
# saves the transcript and the final reply, and prints the session id.
turn() {
	local n="$1" message="$2" session="${3:-}" resume_args=() args=()
	[ -n "$session" ] && resume_args=(--resume "$session")
	while IFS= read -r arg; do args+=("$arg"); done < <(agent_args)
	(
		cd "$work"
		claude -p "$message" "${args[@]}" \
			${resume_args[@]+"${resume_args[@]}"} \
			${plugin_args[@]+"${plugin_args[@]}"} \
			${permission_args[@]+"${permission_args[@]}"} \
			${model_args[@]+"${model_args[@]}"}
	) >"$run_dir/transcript-$n.jsonl" 2>"$run_dir/stderr-$n.log" || true
	jq -Rr 'fromjson? | select(.type == "result") | .result // ""' \
		"$run_dir/transcript-$n.jsonl" >"$out/response-$n.md"
	jq -Rr 'fromjson? | select(.type == "result") | .session_id // empty' \
		"$run_dir/transcript-$n.jsonl" | tail -n 1
}

git_state() {
	if ! git -C "$work" rev-parse --git-dir >/dev/null 2>&1; then
		echo "(no git repository)"
		return
	fi
	echo "## Current branch"
	git -C "$work" branch --show-current
	echo
	echo "## Status"
	git -C "$work" status --short
	echo
	echo "## Local branches"
	git -C "$work" branch -vv
	echo
	echo "## Commits on every branch, newest first"
	git -C "$work" log --all --format='%n%h%d%n  %s%n%b' --name-status -n 30
	echo
	echo "## Remote refs (origin)"
	git -C "$work" ls-remote origin 2>&1 || true
	echo
	echo "## Patches of the commits made during the run (first 200 KB)"
	if [ -s "$start_refs" ]; then
		sed 's/^/^/' "$start_refs" |
			git -C "$work" log --all --stdin -p --format='%n%h%d %s' 2>&1 | head -c 200000 || true
	else
		git -C "$work" log --all -p --format='%n%h%d %s' 2>&1 | head -c 200000 || true
	fi
}

run_one() {
	local id="$1" eval_json tmp fixture session count i message
	eval_json="$(jq -c --argjson id "$id" '.evals[] | select(.id == $id)' "$evals_file")"
	if [ -z "$eval_json" ]; then
		echo "eval $id: not found in $evals_file" >&2
		return
	fi
	run_dir="$workspace/eval-$id"
	out="$run_dir/outputs"
	tmp="$tmp_root/eval-$id"
	mkdir -p "$out"
	jq '{eval_id: .id, prompt, followups: (.followups // []), expectations}' <<<"$eval_json" >"$run_dir/eval_metadata.json"

	fixture="$(jq -r '.fixture // empty' <<<"$eval_json")"
	if ! prepare "$tmp" "$fixture" "$(jq -r '.with_plugin // false' <<<"$eval_json")" "$run_dir/fixture.log"; then
		echo "eval $id: fixture '$fixture' failed, see $run_dir/fixture.log" >&2
		return
	fi

	# Claude Code refuses writes under .claude/ in -p mode whatever the
	# allow rules, path rules or hooks say, so an eval whose skill installs
	# skills or agents there opts in to skipping permission checks.
	permission_args=()
	if [ "$(jq -r '.skip_permissions // false' <<<"$eval_json")" = true ]; then
		permission_args=(--dangerously-skip-permissions)
	fi

	session="$(turn 1 "$(jq -r .prompt <<<"$eval_json")")"
	count="$(jq '.followups // [] | length' <<<"$eval_json")"
	i=0
	while [ "$i" -lt "$count" ]; do
		if [ -z "$session" ]; then
			echo "eval $id: no session id after turn $((i + 1)); skipping the rest of the follow-ups" >&2
			break
		fi
		message="$(jq -r --argjson i "$i" '.followups[$i]' <<<"$eval_json")"
		i=$((i + 1))
		session="$(turn "$((i + 1))" "$message" "$session")"
	done

	git_state >"$out/git-state.txt"
	# What the run wrote under .claude/: git_state shows only that it is
	# there, as an untracked folder, not what it holds.
	if [ -d "$work/.claude" ]; then
		cp -R "$work/.claude" "$out/claude"
		rm -rf "$out/claude/skills/$skill"
	fi
	if [ -f "$tmp/state/gh.log" ]; then
		cp "$tmp/state/gh.log" "$out/gh.log"
	else
		echo "(gh was never called)" >"$out/gh.log"
	fi

	if [ "$grade" = 0 ]; then
		echo "eval $id: ran, not graded: $run_dir"
		return
	fi
	# Graded from a copy outside this repo, so its CLAUDE.md stays out.
	mkdir -p "$tmp/grade"
	cp -R "$run_dir/." "$tmp/grade/"
	(
		cd "$tmp/grade"
		claude -p "$(cat "$evals_dir/grader-prompt.md")" \
			--output-format json \
			--allowedTools "Read,Write,Glob,Grep" \
			--disallowedTools "AskUserQuestion,Bash,Edit" \
			${grader_model_args[@]+"${grader_model_args[@]}"}
	) >"$run_dir/grader.json" 2>"$run_dir/grader-stderr.log" || true
	if jq -e '.summary.total' "$tmp/grade/grading.json" >/dev/null 2>&1; then
		cp "$tmp/grade/grading.json" "$run_dir/grading.json"
		jq -r --arg id "$id" '"eval \($id): \(.summary.passed)/\(.summary.total) expectations passed" + ([.expectations[] | select(.passed | not) | "\n  failed: \(.text)"] | join(""))' "$run_dir/grading.json"
	else
		echo "eval $id: grading failed, see $run_dir/grader.json"
	fi
}

if [ "$triggers" = 1 ]; then
	run_triggers
	exit 0
fi

evals_file="$skill_dir/evals/evals.json"
[ -f "$evals_file" ] || die "$skill has no evals/evals.json"
[ -n "$ids" ] || ids="$(jq -r '.evals[].id' "$evals_file")"
for id in $ids; do
	run_one "$id"
done
echo "results: $workspace"
