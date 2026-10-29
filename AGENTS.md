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
- Hooks a skill ships are registered in the manifest only if they default to off, with an environment variable to turn them on, because they run for everyone who installs the plugin.
- After changing the manifest, run `claude plugin validate .`. Warnings about the bucket `README.md` files lacking frontmatter are expected: the validator reads every `.md` under `agents/`, while Claude Code only loads what the manifest lists.

## Writing skills with skill-creator

When creating a skill or substantially revising one, use the skill-creator skill if one is available (the name depends on the harness). Its eval loop and description tuning are the main reasons to use it, especially for model-invoked skills.

- Test cases go in `evals/evals.json` inside the skill folder and are committed. `adapt-skill` and `scripts/add-template.sh` leave them out when installing a template into a project.
- Eval runs go in `<skill>-workspace/` next to the skill. These folders are gitignored and skipped by `scripts/check.sh`. Delete them when you are done.
- For a template, run the evals against the template as it is: the example content under each marker stands in for a project.
- Skip its packaging step (`.skill` files). Skills here are installed from the repo.
- Its output still has to follow the rules above and pass `scripts/check.sh`.

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
