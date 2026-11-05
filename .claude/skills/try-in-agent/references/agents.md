# Codex and Copilot CLI in a sandbox

What each agent does, as tested in throwaway configs. Every command assumes the sandbox's exports are loaded (`eval "$(<skill-dir>/scripts/sandbox.sh <folder>)"`) in the same shell command.

## Contents

- [Running them](#running-them)
- [Installing the plugin](#installing-the-plugin)
- [Probes that need no login](#probes-that-need-no-login)
- [Logging in](#logging-in)
- [Sessions](#sessions)
- [Hooks](#hooks)
- [Updates](#updates)

## Running them

Both run from npx, so nothing is installed globally:

```sh
npx -y @openai/codex@latest <args>
npx -y @github/copilot@latest <args>
```

Filter `npm notice` lines out of the output. Codex also warns about PATH aliases when `CODEX_HOME` is new; it's harmless.

## Installing the plugin

**As published** (what users get), from this repo, which is its own marketplace (`.claude-plugin/marketplace.json`, named `artberri-skills`):

```sh
npx -y @openai/codex@latest plugin marketplace add artberri/skills
npx -y @openai/codex@latest plugin add artberri-skills@artberri-skills
npx -y @github/copilot@latest plugin marketplace add artberri/skills
npx -y @github/copilot@latest plugin install artberri-skills@artberri-skills
```

**With unpushed changes**, copy the working tree into a folder and add that folder as the marketplace: the copy lists itself, so the same `artberri-skills@artberri-skills` installs from it. From the repo root, `git ls-files -z --cached --others --exclude-standard | tar --null -T - -cf - | tar -xf - -C <folder>` copies the tracked files with their current edits, plus new files not yet added (a plain `git ls-files` misses those); it works with both BSD and GNU tar. The two agents treat the folder differently:

- **Codex** copies the plugin into `$CODEX_HOME/plugins/cache/artberri-skills/artberri-skills/<version>/`. After editing the copy, run `plugin add` again to re-copy it.
- **Copilot** loads a local folder live, without copying, so edits take effect in the next session.

Neither accepts a `file://` or `git://` marketplace, so how updates arrive from a git marketplace can only be tested against GitHub.

Where the installed copy lives, to read or patch it: Codex prints it (`Installed plugin root:`), under `$CODEX_HOME/plugins/cache/artberri-skills/artberri-skills/<version>/`. Copilot prints only a success line, and keeps a GitHub install in `$HOME/.copilot/installed-plugins/artberri-skills/artberri-skills/`.

Claude Code can add the same folder too: `claude plugin marketplace add <folder>` with `CLAUDE_CONFIG_DIR` pointing at a throwaway folder, and with `CLAUDE_CODE_PLUGIN_DIRS` unset, or `plugin list` also shows the checkouts it names. Users of Claude Code install `artberri-skills@artberri` from `artberri/claude-plugins` instead.

## Probes that need no login

- `npx -y @openai/codex@latest debug prompt-input hi` (run inside `$SANDBOX/work`) prints everything Codex's model would see as JSON: its tools, and the skills it's offered (`- <name>: <description>` lines). Use it to check that a skill loads, or that `agents/openai.yaml` hides one.
- `npx -y @github/copilot@latest skill list` lists the skills Copilot loaded, and any that failed to load with the reason (for example a frontmatter YAML error).
- `plugin list` in either agent shows what's installed and, for Codex, the version.

## Logging in

A real session needs a login, made inside the sandbox:

- **Codex:** the user types `! CODEX_HOME=$SANDBOX/home/.codex npx -y @openai/codex@latest login` (with the real path) and finishes in the browser.
- **Copilot:** its login asks whether to store the token as plain text, which the `!` prompt can't answer. The user runs `HOME=$SANDBOX/home npx -y @github/copilot@latest login` in their own terminal and says yes.

Give the user the exact command with the sandbox's path, and wait.

## Sessions

Run each session in `$SANDBOX/work` or another throwaway repo, with only the tools the test needs:

- **Codex:** `npx -y @openai/codex@latest exec -s workspace-write -C <repo> "<prompt>" </dev/null`. Without `</dev/null` it waits on stdin until it times out. `workspace-write` keeps its writes inside the repo; use `read-only` when it shouldn't write.
- **Copilot:** `npx -y @github/copilot@latest -s --allow-tool '<pattern>' -p "<prompt>"`. Patterns like `write` and `shell(git status:*)` work. A multi-word pattern such as `shell(gh pr create:*)` doesn't match; allow `shell(gh:*)` instead, with a fake `gh` first on `PATH` if nothing should reach GitHub.

Each session costs about one request. Where they leave their logs:

- **Copilot:** `$HOME/.copilot/session-state/<id>/events.jsonl` (with `workspace.yaml` next to it). Events: `user.message`, `assistant.message`, `tool.execution_start` (`toolName`, `arguments`), `tool.execution_complete` (`fileEdits`), `skill.invoked`, `hook.start` and `hook.end` (`output`).
- **Codex:** `$CODEX_HOME/sessions/YYYY/MM/DD/rollout-*.jsonl`. The first line is `session_meta` (`cwd`, `git`). `event_msg` events of type `item_completed` hold `UserMessage`, `AgentMessage`, `CommandExecution` (`command`, `parsed_cmd`) and `FileChange` (`changes`).

Codex's subagent tool, `spawn_agent`, takes no agent type, so named agents can't run there, and its `fork_turns` defaults to `all`: a subagent gets the whole conversation unless the call sets `fork_turns: "none"`.

## Hooks

Copilot runs the hooks in `plugin.json` and fills `${CLAUDE_PLUGIN_ROOT}`. A hook gets Claude Code's field names (`tool_name: "Bash"`, `tool_input.command`), except that a `PostToolUse` hook gets the command's output in `tool_result.text_result_for_llm` (and `tool_response` is null). Copilot reads `additionalContext` at the top level of a hook's output; a `PreToolUse` deny in Claude Code's shape works.

Copilot's `hook.start` events log its own format, not what the hook receives. To see a hook's real input, patch the sandbox's installed copy to save its stdin first (`tee <file> >/dev/null; exec <<file>` right after `set -euo pipefail`), run the session, and read the file. Never patch the repo's copy for this.

A plugin hook is off until its `ARTBERRI_*` variable is `1`: set it on the session command.

Codex doesn't run a plugin's hooks (tested with 0.166.0): `codex features list` shows `plugin_hooks` as `removed`, and a session with `ARTBERRI_GIT_GUARDRAILS=1` ran `git add -A` with no hook event in its log or in `logs_2.sqlite`. Its own hooks (`hooks` is `stable`) are untested; they'd need a trust step (Codex stores a `trusted_hash` per hook) and a matcher for its shell tool, which the model calls as `exec_command`, not `Bash`.

`-s workspace-write` makes `.git` read-only, so `git add` and `git commit` fail there with `index.lock: Operation not permitted`. A failure like that comes from Codex's sandbox, not a hook.

## Updates

Neither agent updated the plugin by itself when it started. By hand, `copilot plugin update artberri-skills@artberri-skills` and running `codex plugin add artberri-skills@artberri-skills` again both bring in the latest `main`. `codex plugin marketplace upgrade` only refreshes the marketplace repo, not the plugin.
