# Working in this repo

This repo holds agent skills. Each skill is a folder under one of three buckets:

- `skills/portable/`: works as-is in any project. Never contains `CUSTOMIZE` markers.
- `skills/templates/`: installed into a project and adapted (and later refreshed) by the `adapt-skill` skill, or copied by `scripts/add-template.sh` for agents other than Claude Code. Always contains at least one `CUSTOMIZE` marker.
- `skills/drafts/`: work in progress. Not installed and not listed outside its own README.

When you are unsure which bucket a skill belongs in, ask: would it be wrong in some project if nobody edited it? If so, it is a template.

When the user asks for a portable skill, challenge that before writing it. List what the skill depends on that varies between projects: commands, paths, tools, services, conventions, review or release processes. For each, decide whether the skill can find it out reliably at run time (from `AGENTS.md` or `CLAUDE.md`, CI config, package manifests, `git log`, or a config file a `setup-*` skill writes), or would have to hard-code or guess it.

- If everything can be found out, say so in one line and carry on: portable is right.
- If something would be hard-coded or guessed, recommend a template instead. Explain why, name the parts that would become `CUSTOMIZE` markers, and wait for the user to decide. They may still choose portable; then make those parts discoverable at run time, or say plainly in the skill what it assumes.

## Skill rules

- The folder name is the skill name: lowercase letters, digits and hyphens. It matches the `name` field in the `SKILL.md` frontmatter.
- Skill names are unique across all buckets, so a template copied into a project never clashes with a globally installed portable skill.
- `description` says what the skill does and when to use it, written so the model can tell when to reach for it.
- A user-invoked skill (one only the human should trigger) sets `disable-model-invocation: true`.
- Keep `SKILL.md` short. Move long reference material into sibling files that `SKILL.md` links to and loads only when needed.
- Every skill is listed in its bucket's `README.md` as `- **[name](./name/SKILL.md)**: one-line description.`
- Templates and drafts set `metadata.internal: true`; portable skills don't. The `skills` CLI (skills.sh) finds every `SKILL.md` under `skills/`, and this hides the ones it shouldn't install: a template copied without `adapt-skill` keeps its markers, and `skills update` would overwrite an adapted copy. Moving a draft to `portable/` means removing the field. Adapted copies in a project keep it, which is harmless: only the `skills` CLI reads it.
- Skills also run in agents other than Claude Code (Codex, Copilot, Gemini CLI...), so a command that runs a file in the skill's folder writes it as `<skill-dir>/scripts/...` and says once that `<skill-dir>` is the folder the `SKILL.md` is in. Not `${CLAUDE_SKILL_DIR}`: only Claude Code fills it in. `scripts/check.sh` rejects it.

## Agents

`agents/` holds Claude Code subagent definitions that skills start. It uses the same three buckets as `skills/`, with one file per agent: `agents/<bucket>/<name>.md`.

- Frontmatter has `name` (matching the file name) and `description`, plus `tools` and `model` when the agent should be limited. The body is the agent's system prompt.
- Agent names are unique across the agent buckets, and each agent is listed in its bucket's `README.md` as `- **[name](./name.md)**: one-line description.`
- A template agent has `CUSTOMIZE` markers, the same as a template skill. A portable agent has none.
- A skill that starts an agent names it in its instructions and lists it in its frontmatter:

  ```yaml
  metadata:
    agents: reviewer test-runner
  ```

  Names are space-separated. `scripts/check.sh` verifies each one exists and fits: a portable skill can only use portable agents, and a template skill can use portable or template agents. `adapt-skill` (or `scripts/add-template.sh`) installs the template agents into the project together with the skill.
- Tell the agent to start with a fresh context, and give it everything it needs in the prompt: it does not see the conversation.
- When a plugin loads the agent, its name carries the plugin prefix (`artberri:ocr-reviewer`). Skills tell the model to use the name its Agent tool lists, never a hard-coded `subagent_type`.

## The plugin

`.claude-plugin/plugin.json` makes the repo the `artberri` Claude Code plugin, which ships the portable skills and agents.

- Skills come in as a folder (`./skills/portable/`), so a new portable skill needs no manifest change.
- Agents must be listed one by one: add every portable agent to `agents`, and nothing else. `scripts/check.sh` enforces this, and rejects `.md` files at the top of `agents/`, which Claude Code would load on its own.
- A hook that belongs to one skill lives in that skill's `hooks/` folder. A hook that applies whichever skill runs, like the git guardrails, lives in `hooks/<name>/` at the top of the repo, with a `README.md` saying what it does and how to turn it on.
- Hooks are registered in the manifest only if they default to off, with an environment variable to turn them on, because they run for everyone who installs the plugin. Name the variable `ARTBERRI_<NAME>`, so it can't clash with another tool's (`GIT_*` belongs to git).
- After changing the manifest, run `claude plugin validate .`. Warnings about the bucket `README.md` files lacking frontmatter are expected: the validator reads every `.md` under `agents/`, while Claude Code only loads what the manifest lists.

## Writing skills with skill-creator

When creating a skill or substantially revising one, use the skill-creator skill if one is available (the name depends on the harness). Its eval loop and description tuning are the main reasons to use it, especially for model-invoked skills.

- Test cases go in `evals/evals.json` inside the skill folder and are committed. `adapt-skill` and `scripts/add-template.sh` leave them out when installing a template into a project.
- Eval runs go in `<skill>-workspace/` next to the skill. These folders are gitignored and skipped by `scripts/check.sh`. Delete them when you are done.
- For a template, run the evals against the template as it is: the example content under each marker stands in for a project.
- Skip its packaging step (`.skill` files). Skills here are installed from the repo.
- Its output still has to follow the rules above and pass `scripts/check.sh`.

## Evals

Every portable and template skill should have `evals/evals.json`. For now `scripts/check.sh` only warns when one is missing. The format is skill-creator's, plus four optional fields per eval that `scripts/evals/run.sh` reads:

- `fixture`: the name of a script in `evals/fixtures/<name>.sh` that builds the eval's starting state. It gets an empty folder and creates the repository at `<folder>/repo`, usually with `eval_repo` from `scripts/evals/fixture-lib.sh` (sourced through `$EVAL_LIB`), which also makes a bare `origin` to push to. Helpers shared by one skill's fixtures go in a sourced file next to them.
- `followups`: the user's answers, sent in order in the same session after each reply. Use them when the skill should stop and ask; the first reply is then graded on whether it asked.
- `with_plugin`: `true` loads this repo as a plugin, so the skills it chains to are available. By default only the skill under test is installed, which tests its fallbacks when the others are missing.
- `skip_permissions`: `true` runs the eval with `--dangerously-skip-permissions`. Set it only when the skill must write under the project's `.claude/` (installing skills or agents): Claude Code refuses those writes in `-p` mode, whatever the allow rules or hooks say. The agent can then run any command on your machine without asking, network included, so keep it off everywhere else.

Write expectations that can be checked against `outputs/git-state.txt` (branches, commits and their files, the remote's refs), `outputs/claude/` (the repository's `.claude/` folder, without the skill under test, which `git-state.txt` only lists as untracked) and `outputs/gh.log` (every `gh` call), not only against the agent's reply. `gh` is a stub (`scripts/evals/stubs/gh`) that never reaches GitHub and fakes one pull request at a time.

`evals/triggers.json` holds `{query, should_trigger}` pairs, in skill-creator's format, that test the description. Include near misses that belong to a sibling skill. `run.sh --triggers` runs each query a few times with the skill installed as it would be in a project and this repo's plugin loaded, so the siblings compete, and records the first tool call of each run: the query triggered the skill if that call invokes it. The queries run in a fresh repository from `evals/fixtures/triggers.sh`, or an empty folder without one; give a skill that acts on work in progress a `triggers.sh`, or the model looks around first. skill-creator's own trigger runner installs a stand-in command with a different name and no siblings, so its numbers don't carry over.

Run them with `scripts/evals/run.sh <skill> [eval-id...]`, or `--triggers`. Each run uses a temporary config folder, so it needs `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`) or `ANTHROPIC_API_KEY`. Runs cost model usage, so CI only validates the files.

## CUSTOMIZE markers

A template marks each project-specific part with an HTML comment placed just above the content it governs:

```markdown
## Running the tests

<!-- CUSTOMIZE: the command that runs the test suite, and how to run a single test file.
Look in package.json scripts, the Makefile, or CI config. -->
Run `npm test`. For one file: `npx vitest run path/to/file.test.ts`.
```

- The comment starts its own line. `scripts/check.sh` only counts markers at the start of a line, so a skill can mention the syntax inline in backticks.
- The comment says what to fill in and where in a project to look for it.
- The content under it, up to the next heading or marker, is an example. It shows the shape of the answer and gets replaced.
- `adapt-skill` rewrites that content for the project and deletes the marker. An adapted skill has no markers left.

Every template carries `metadata.template-revision`, a whole number, in its frontmatter. Bump it whenever you change the template: `adapt-skill` compares it with a project's copy to offer a refresh. `scripts/check.sh` requires it.

Guidance for adapting a template that the markers alone can't carry (which questions to ask and in what order, what to look for across the project) goes in a `SETUP.md` next to its `SKILL.md`, not in a separate skill. `adapt-skill` follows it; it is never copied into the project and has no markers of its own.

## Checks

Run `scripts/check.sh` after adding, renaming or moving a skill or agent. It validates frontmatter, marker rules, name uniqueness, the agents each skill uses, and the bucket READMEs. CI runs it, plus ShellCheck and shfmt on every shell script, including those inside skill folders.

## Style

- Tabs for indentation, except YAML.
- Shell scripts: Bash that runs on macOS's `/bin/bash` 3.2, `set -euo pipefail`, quoted variables, clean under ShellCheck and shfmt. They must work on both macOS and Linux (BSD vs GNU tools).
- This repo is public: no secrets, internal hostnames, work identifiers or absolute paths with a username.
