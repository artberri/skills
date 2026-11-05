#!/usr/bin/env bash
set -euo pipefail

# Makes a throwaway config for trying this repo's plugin in Codex or Copilot
# CLI, and prints the exports that point both agents (and npm's cache) at it.
# Load them at the start of each command that runs an agent, so that a
# failure stops the command instead of leaving it in the real home folder:
#
#	exports="$(<skill-dir>/scripts/sandbox.sh <folder>)" || exit 1; eval "$exports"
#
# The first run makes <folder>, which must not exist yet or be empty: home/
# (the agents' config, and any login), work/ (a git repo to run sessions in)
# and npm/. Later runs on the same folder only print the exports again. Delete
# the whole folder when done: it may hold a login token in plain text.

[ $# -eq 1 ] || {
	echo "usage: $0 <folder>" >&2
	exit 2
}
root="$1"
# Marks a folder this script made, so a later run reuses it.
marker=.try-in-agent-sandbox
if [ ! -e "$root/$marker" ]; then
	if [ -e "$root" ] && [ -n "$(ls -A "$root" 2>/dev/null)" ]; then
		echo "error: $root isn't empty and isn't a sandbox this script made; pick a new folder" >&2
		exit 1
	fi
	mkdir -p "$root/home/.codex" "$root/work" "$root/npm"
	git -C "$root/work" init -q
	: >"$root/$marker"
fi
root="$(cd "$root" && pwd)"

# One line per variable, quoted for eval. GH_TOKEN and friends are unset so
# Copilot only ever uses the sandbox's own login.
printf 'export SANDBOX=%q\n' "$root"
printf 'export HOME=%q\n' "$root/home"
printf 'export CODEX_HOME=%q\n' "$root/home/.codex"
printf 'export XDG_CONFIG_HOME=%q XDG_STATE_HOME=%q\n' "$root/home/.config" "$root/home/.state"
printf 'export npm_config_cache=%q\n' "$root/npm"
printf 'unset GH_TOKEN GITHUB_TOKEN COPILOT_GITHUB_TOKEN\n'
