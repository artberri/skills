---
name: setup-ocr
description: "Configure this repo for the ocr-review skill: draft `.opencodereview/background.md` and `rule.json`, pointing the reviewer at the project's review docs (and creating them with setup-review-docs when there are none). Run once per repo, and again to refresh it."
disable-model-invocation: true
---

# Setup OCR

Tailors [Open Code Review](https://github.com/alibaba/open-code-review) and the `ocr-review` skill to this repo. Without it, reviews run on OCR's built-in rules: test files are excluded, generated and vendored files are reviewed, and the reviewer knows nothing about the project's conventions, so it raises findings the team already settled.

It sets up:

- **`.opencodereview/background.md`**: project context for the reviewer, and the docs it reads.
- **`.opencodereview/rule.json`**: which files OCR reviews, and per-path review rules.

The reviewer is only as good as the review docs it reads: known non-issues, a pre-PR review checklist and footguns. Those belong to the whole project, not just OCR, so the `setup-review-docs` skill creates and maintains them, and this skill points the background at them.

This is a prompt-driven skill, not a script. Explore, present what you found, confirm with the user, then write. The background template is in this skill's `templates/` folder.

## 1. Explore

Run `node --version` first. If `node` is missing or older than 22.18, tell the user that `ocr-review` needs Node.js 22.18 or later, then carry on: only the verify step needs it.

Read what exists; don't assume:

- `.opencodereview/`: if it exists, this is a refresh. Start from its files and propose changes, never a rewrite.
- `AGENTS.md`, `CLAUDE.md`, `README`: what the project is, and conventions that look like defects to an outsider (no enums, no classes, unusual error handling, and so on).
- Languages, formatters and linters (their config files), so the background can say they own style.
- Generated, vendored and lock files, and build output that is committed: candidates for `exclude`.
- Where tests live and how they're named: OCR excludes test files by default, and `include` brings them back.
- **Review docs, under any name**: a review checklist, a known-issues or conventions list, a pitfalls doc. The instruction file often lists them. Note their paths and section headings: the background points at them, and the per-path rules name their sections.

## 2. Present findings and ask

Summarise what's there and what's missing, then take these sections in order: one section, one answer, then the next. Lead each with your recommendation so the user can accept it in a word.

**A. Review docs.** If the repo has no known non-issues list or no pre-PR checklist, recommend creating them first, since the background and rules lean on them. On a yes, read `../setup-review-docs/SKILL.md` (relative to this skill's folder) and follow it to the end, then come back here and carry on with the docs it wrote. If that file isn't there, tell the user to run `/setup-review-docs` and continue without the docs for now. If the docs exist, just list them.

**B. `rule.json`.** Propose the `exclude` list, the test `include` patterns, and a few per-path `rules`, each a short checklist that names the doc section to read first (`"Read the 'Tests' section of docs/PRE_PR_REVIEW.md first. Check that ..."`). Keep the rules to areas where the repo has real conventions; OCR's built-in rules cover the rest. The format:

```json
{
	"include": ["**/*.test.ts"],
	"exclude": ["package-lock.json", "**/generated/**"],
	"rules": [{ "path": "**/*.test.ts", "rule": "..." }]
}
```

A matching rule replaces OCR's built-in rule for that file; add `"merge_system_rule": true` to an entry to keep both.

## 3. Draft and confirm

Show the user every file you will write or change, in full (as a diff on a refresh):

- `.opencodereview/background.md`, from `templates/background.md`. Docs to read on every review (known non-issues, the pre-PR checklist) go in the first list; footguns and other long docs go in the "check against the diff" list, so the reviewer reads only the matching entries. Leave out a list, and its lead-in, when no doc belongs in it.
- `.opencodereview/rule.json`.

Let the user edit before writing anything.

## 4. Write and verify

Write the files. Then:

- Check `rule.json` parses: `node -e 'JSON.parse(require("fs").readFileSync(".opencodereview/rule.json", "utf8"))'`.
- Check every doc path in `background.md` and in the rules exists.
- Run `npx -y @alibaba-group/open-code-review@1.12.12 delegate preview --from <a commit ~20 commits back> --to HEAD -B .opencodereview/background.md` and check the reviewable and excluded files match what the user expects: tests in, generated files out.
- Run `npx -y @alibaba-group/open-code-review@1.12.12 delegate rule <one path per rule>` and check each gets the intended rule.

Tell the user what was written and that the files are meant to be committed, so every reviewer on the team gets the same setup. Don't commit them yourself.
