# To do

Work left for later, and things to come back to. Remove an item in the commit that finishes it.

## Add evals to the remaining skills, then make check.sh fail without them

These have no `evals/evals.json` yet: `address-pr-comments`, `ocr-review`, `execute-plan`, `create-plan`, `write-acceptance-criteria`, `capture-learnings`, `research`, `retro`, `setup-ocr` and `setup-review-docs`.

Once each has one, or is exempted explicitly (the user-invoked setup skills are the likeliest), turn the missing-evals warning in `scripts/check.sh` into a failure.

## Notice when the agents' docs change

Codex dropped plugin hooks, and we found out only by trying it in `try-in-agent`. Keep a list of the doc pages this repo depends on, for Claude Code, Codex and Copilot CLI (skills, plugins, hooks, subagents), and a script that fetches them into a gitignored folder and records a hash of each, so a refresh shows which pages changed since last time. Commit only the list and the hashes: copying other people's docs into a public repo isn't ours to do. [eferro/skill-factory](https://github.com/eferro/skill-factory) keeps its copies of Anthropic's docs fresh the same way.

## Add `argument-hint` to the skills that take arguments

`ocr-review` (a PR number, `--local`, `--incremental`), `address-pr-comments` (a PR number or URL, `--local`), `retro` (`day`, `week`) and `ship` (`--base <branch>`) take arguments but have no `argument-hint`, so Claude Code's `/` menu doesn't show them. Six skills already have one, written as `argument-hint: "[...]"`.
