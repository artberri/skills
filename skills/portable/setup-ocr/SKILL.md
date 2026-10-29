---
name: setup-ocr
description: "Configure this repo for the ocr-review skill: draft `.opencodereview/background.md` and `rule.json`, and offer the review docs the reviewer reads (known non-issues, pre-PR review checklist, footguns). Run once per repo, and again to refresh it."
disable-model-invocation: true
---

# Setup OCR

Tailors [Open Code Review](https://github.com/alibaba/open-code-review) and the `ocr-review` skill to this repo. Without it, reviews run on OCR's built-in rules: test files are excluded, generated and vendored files are reviewed, and the reviewer knows nothing about the project's conventions, so it raises findings the team already settled.

It sets up:

- **`.opencodereview/background.md`**: project context for the reviewer, and the docs it reads.
- **`.opencodereview/rule.json`**: which files OCR reviews, and per-path review rules.
- **Review docs**, each optional:
  - `KNOWN_NON_ISSUES.md`: patterns that look like defects but are deliberate. Recommended: it is what stops repeated false positives.
  - `PRE_PR_REVIEW.md`: the defect types this repo keeps getting, as a checklist. Recommended.
  - `FOOTGUNS.md`: runtime pitfalls that pass review and type checks. Offered.

This is a prompt-driven skill, not a script. Explore, present what you found, confirm with the user, then write. Templates for every file are in this skill's `templates/` folder.

## 1. Explore

Run `node --version` first. If `node` is missing or older than 22.18, tell the user that `ocr-review` needs Node.js 22.18 or later, then carry on: only the verify step needs it.

Read what exists; don't assume:

- `.opencodereview/`: if it exists, this is a refresh. Start from its files and propose changes, never a rewrite.
- `AGENTS.md`, `CLAUDE.md`, `README`: what the project is, and conventions that look like defects to an outsider (no enums, no classes, unusual error handling, and so on).
- Languages, formatters and linters (their config files), so the background can say they own style.
- Generated, vendored and lock files, and build output that is committed: candidates for `exclude`.
- Where tests live and how they're named: OCR excludes test files by default, and `include` brings them back.
- The docs folder, and two things about it:
  - **Its naming convention.** Default to capitals with underscores (`PRE_PR_REVIEW.md`). If its existing doc files follow another convention (`pre-pr-review.md`, `PrePrReview.md`), use that one instead.
  - **Docs that already play one of the three roles**: a review checklist, a known-issues or conventions list, a pitfalls doc. Point the background at those instead of creating duplicates.
- If `gh repo view` works, the review threads on the last 20 or so merged PRs (`gh api repos/{owner}/{repo}/pulls/<number>/comments`). Look for findings the author rejected with a reason that would hold next time: they are known non-issues. Look for real bugs that reviews caught more than once: they are checklist items.

## 2. Present findings and ask

Summarise what's there and what's missing, then take these sections in order: one section, one answer, then the next. Lead each with your recommendation so the user can accept it in a word.

**A. Review docs.** For each of the three, say whether it exists already (under any name), and recommend creating `KNOWN_NON_ISSUES.md` and `PRE_PR_REVIEW.md` if missing. Offer `FOOTGUNS.md`. Give the paths you would use, following the naming convention you found.

**B. Seed entries.** For each doc being created, list the entries you would start it with: from rejected and repeated PR findings, and from conventions in `AGENTS.md` / `CLAUDE.md`. A doc with no real entries yet is fine; never invent one.

**C. `rule.json`.** Propose the `exclude` list, the test `include` patterns, and a few per-path `rules`, each a short checklist that names the doc section to read first (`"Read the 'Tests' section of docs/PRE_PR_REVIEW.md first. Check that ..."`). Keep the rules to areas where the repo has real conventions; OCR's built-in rules cover the rest. The format:

```json
{
	"include": ["**/*.test.ts"],
	"exclude": ["package-lock.json", "**/generated/**"],
	"rules": [{ "path": "**/*.test.ts", "rule": "..." }]
}
```

A matching rule replaces OCR's built-in rule for that file; add `"merge_system_rule": true` to an entry to keep both.

## 3. Draft and confirm

Show the user every file you will write or change, in full:

- `.opencodereview/background.md`, from `templates/background.md`. Docs to read on every review go in the first list; `FOOTGUNS.md` and other long docs go in the "check against the diff" list, so the reviewer reads only the matching entries.
- `.opencodereview/rule.json`.
- Each new review doc, from its template, with the seed entries from B. Fix the cross-links between docs to the names you chose.
- A short section for `AGENTS.md` or `CLAUDE.md` (whichever exists; if both, the one the other imports; if neither, ask) listing the review docs and when to read them, since they help whoever writes the code, not only the reviewer.

Let the user edit before writing anything.

## 4. Write and verify

Write the files. Then:

- Check `rule.json` parses: `node -e 'JSON.parse(require("fs").readFileSync(".opencodereview/rule.json", "utf8"))'`.
- Run `npx -y @alibaba-group/open-code-review@1.12.12 delegate preview --from <a commit ~20 commits back> --to HEAD -B .opencodereview/background.md` and check the reviewable and excluded files match what the user expects: tests in, generated files out.
- Run `npx -y @alibaba-group/open-code-review@1.12.12 delegate rule <one path per rule>` and check each gets the intended rule.

Tell the user what was written and that the files are meant to be committed, so every reviewer on the team gets the same setup. Don't commit them yourself.
