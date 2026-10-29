# Working in this repo

This repo holds agent skills. Each skill is a folder under one of three buckets:

- `skills/portable/`: works as-is in any project. Never contains `CUSTOMIZE` markers.
- `skills/templates/`: copied into a project by `scripts/add-template.sh`, then adapted with the `adapt-skill` skill. Always contains at least one `CUSTOMIZE` marker.
- `skills/drafts/`: work in progress. Not installed and not listed outside its own README.

When you are unsure which bucket a skill belongs in, ask: would it be wrong in some project if nobody edited it? If so, it is a template.

## Skill rules

- The folder name is the skill name: lowercase letters, digits and hyphens. It matches the `name` field in the `SKILL.md` frontmatter.
- Skill names are unique across all buckets, so a template copied into a project never clashes with a globally installed portable skill.
- `description` says what the skill does and when to use it, written so the model can tell when to reach for it.
- A user-invoked skill (one only the human should trigger) sets `disable-model-invocation: true`.
- Keep `SKILL.md` short. Move long reference material into sibling files that `SKILL.md` links to and loads only when needed.
- Every skill is listed in its bucket's `README.md` as `- **[name](./name/SKILL.md)**: one-line description.`

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

## Checks

Run `scripts/check.sh` after adding, renaming or moving a skill. It validates frontmatter, marker rules, name uniqueness and the bucket READMEs. CI runs it, plus ShellCheck and shfmt on `scripts/`.

## Style

- Tabs for indentation, except YAML.
- Shell scripts: Bash that runs on macOS's `/bin/bash` 3.2, `set -euo pipefail`, quoted variables, clean under ShellCheck and shfmt. They must work on both macOS and Linux (BSD vs GNU tools).
- This repo is public: no secrets, internal hostnames, work identifiers or absolute paths with a username.
