# shellcheck shell=bash
# Shared by the commit fixtures; sourced, not run. Builds a small Node project
# on main, all of it committed and pushed, with no pull request convention, so
# committing straight to main is fine. Leaves the current folder at the
# repository.
#
# commit_base <root> [style]: style is "conventional" (the default), for
# subjects like `fix(log): ...`, or "package", for Go-style subjects like
# `time: ...`.

# shellcheck source=scripts/evals/fixture-lib.sh
. "$EVAL_LIB"

commit_base() {
	local root="$1" style="${2:-conventional}" m1 m2 m3
	if [ "$style" = package ]; then
		m1="all: set up the project"
		m2="time: add timestamp and date formatting"
		m3="log: record user activity with a timestamp"
	else
		m1="chore: set up the project"
		m2="feat(time): add timestamp and date formatting"
		m3="feat(log): log user activity with a timestamp"
	fi

	eval_repo "$root"
	cd "$root/repo" || return

	cat >package.json <<'EOF'
{
	"name": "app",
	"version": "1.0.0",
	"type": "module",
	"scripts": {
		"test": "true"
	}
}
EOF
	mkdir -p src .github/workflows
	cat >README.md <<'EOF'
# app

Logs user activity.
EOF
	cat >.github/workflows/ci.yml <<'EOF'
name: ci
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm test
EOF
	eval_commit . "$m1"

	cat >src/time.js <<'EOF'
export function formatTimestamp(date) {
	return date.toLocaleString();
}

export function formatDate(date) {
	return date.toISOString().slice(0, 10);
}

export function formatTime(date) {
	return date.toISOString().slice(11, 19);
}

export function isSameDay(a, b) {
	return formatDate(a) === formatDate(b);
}
EOF
	eval_commit . "$m2"

	cat >src/log.js <<'EOF'
import { formatTimestamp } from "./time.js";

export function logActivity(user, action, date = new Date()) {
	return `${formatTimestamp(date)} ${user} ${action}`;
}
EOF
	eval_commit . "$m3"

	git push --quiet -u origin main
}

# The timezone fix: log timestamps in UTC instead of local time.
commit_fix_timezone() {
	perl -0pi -e 's/date\.toLocaleString\(\)/date.toISOString()/' src/time.js
}

# An unrelated CI change: run the tests on Node 22.
commit_bump_node() {
	perl -0pi -e 's/node-version: 20/node-version: 22/' .github/workflows/ci.yml
}

# A new helper at the end of src/time.js, far enough from the timezone fix
# that the two land in separate hunks.
commit_add_duration() {
	cat >>src/time.js <<'EOF'

export function formatDuration(ms) {
	const seconds = Math.round(ms / 1000);
	return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
}
EOF
}
