---
name: try-in-agent
description: >-
  Try a change to this repo's skills, agents, hooks or plugin manifest in Codex or GitHub Copilot CLI, inside a
  throwaway config, and report how it behaved there. Use whenever the user asks whether something works in Codex or
  Copilot ("does this work in Copilot?", "try it in Codex", "test the hook in Copilot", "check Codex loads the
  skill", "what does Copilot do with this agent"), or when a change claims to support another agent and nobody has
  seen it run there. Not for Claude Code itself: use the repo's evals (scripts/evals/run.sh) for that.
metadata:
  internal: true
---

# Try in agent

Codex and Copilot CLI load this repo's plugin, but they don't behave like Claude Code: different tool names, hook formats, skill metadata and update rules. A claim that something works there is only worth making after seeing it run. This skill sets up a throwaway config, runs the smallest test that answers the question, and reports what happened.

Read [references/agents.md](references/agents.md) before running anything: it has each agent's commands, where they keep their data, and the gotchas found so far. `<skill-dir>` below is the folder this `SKILL.md` is in.

## 1. Pin down the question

Write it in one line, with what you expect to see: "Copilot loads `research` (it's in `skill list` with no load error)", "with `ARTBERRI_GIT_GUARDRAILS=1`, Copilot denies `git add -A`". A test without an expected result can't fail, so it can't tell you anything.

Then decide whether it needs a session. Many questions don't: whether a skill loads, what Codex's model is offered, what a plugin install contains. Those cost nothing and need no login. A session costs about one request per run and a login made by the user, so say so before starting one.

Decide too whether to test what's published on GitHub or the local, unpushed changes. The references explain both installs.

## 2. Make the sandbox

```sh
exports="$(<skill-dir>/scripts/sandbox.sh <folder>)" || exit 1; eval "$exports"
```

Put `<folder>` in your scratchpad or a temporary folder, never in the repo or the user's home. The first run makes it, and later runs on the same folder print the same exports: `HOME`, `CODEX_HOME`, `XDG_*` and npm's cache, so both agents keep everything there and the user's real config is never touched. Start every command that runs an agent with this line, because each Bash call starts fresh. Keep the `|| exit 1`: when the script fails, a bare `eval "$(…)"` carries on, and the agent runs in the user's real home.

## 3. Install and probe

Install the plugin in the sandbox (published, or a local marketplace with the working tree), then run the no-login probes that answer or narrow the question.

## 4. Run a session, if needed

A fresh sandbox has no login, so don't try a session first to find out: ask the user to log in inside the sandbox with the exact command from the references, and wait for them. Then run each session in a throwaway repo, with only the tools the test needs:

- Allow named tools (`--allow-tool 'shell(git status:*)'` in Copilot, `-s workspace-write` in Codex), never `--allow-all-tools`, `--yolo` or a sandbox bypass. A session can run commands on the user's machine.
- Keep the user's GitHub out of it: use a fake `gh` first on `PATH` when the test involves PRs.
- Don't make the agent commit with signing turned off; the repo's git guardrails block that, and the test rarely needs a commit.

Read the session's log, not only its reply: the events show which tools ran, what hooks returned and which skills loaded.

## 5. Report and clean up

Report the question, the result (works, doesn't work, or inconclusive and why), and the evidence: the command and the lines of output or log that show it. Say what you didn't test.

If the result changes a claim in the repo's docs (`README.md`, `AGENTS.md`, a skill's text), or adds a gotcha to [references/agents.md](references/agents.md), propose the edit.

Then delete the sandbox. If the user logged in, tell them the login still exists on their account, and where to revoke it (GitHub's authorized apps for Copilot, ChatGPT's security settings for Codex).
