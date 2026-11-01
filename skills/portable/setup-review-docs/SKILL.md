---
name: setup-review-docs
description: "Create or refresh this repo's review docs: known non-issues, a pre-PR review checklist and footguns, seeded from merged PR reviews and the project's conventions, and listed in AGENTS.md or CLAUDE.md. Safe to rerun: a rerun brings existing docs up to the current shape, adds what PR reviews have taught since, and flags stale entries, without rewriting or duplicating what is there."
disable-model-invocation: true
---

# Setup review docs

Writes the docs that reviewers (human, `ocr-review`, `adversarial-review`) and the people writing the code read, and that `ship`, `capture-learnings` and `address-pr-comments` keep using:

- **`KNOWN_NON_ISSUES.md`**: patterns that look like defects but are deliberate. Recommended: it is what stops repeated false positives.
- **`PRE_PR_REVIEW.md`**: the defect types this repo keeps getting, as a checklist. Recommended.
- **`FOOTGUNS.md`**: runtime pitfalls that pass review and type checks. Offered.

The templates are in this skill's `templates/` folder. They define the current shape of each doc: its intro, its how-to-use text, its sections and the format of an entry.

This is a prompt-driven skill, not a script. Explore, present what you found, confirm with the user, then write.

## Reruns

Run it as often as you like. Every run does the same thing: look at what exists, work out what would make it better, propose that, and write only what the user approves. The first run creates the docs; later runs improve them. A run straight after another, with nothing new in the repo, proposes nothing: say so and stop.

What makes that hold:

- **Entries belong to the project.** Never drop, reword or reorder one silently. Every change to an existing entry is a proposal with a reason.
- **Change for a reason, never for style.** Don't rephrase an entry that is correct and already in the current format. Churn makes the next run's diff noisy and the docs' history hard to read.
- **The template sets the structure; the project's docs set the content.** Bring framing text and entry format up to the template. Keep the project's entries, section names and wording.
- **No state files.** What changed since the last run comes from git: the last commit that touched each doc.

## 1. Explore

Read what exists; don't assume.

- **Existing review docs, under any name.** A review checklist, a known-issues or conventions list, a pitfalls doc, anywhere in the repo (`docs/`, the root, `.github/`). A doc that already plays a role is that role's doc: improve it, never create a second one beside it. Note when each was last changed: `git log -1 --format='%H %cs' -- <path>`.
- **The docs folder and its naming convention.** Default to capitals with underscores (`PRE_PR_REVIEW.md`). If the existing doc files follow another convention (`pre-pr-review.md`, `PrePrReview.md`), use that one. With no docs folder, propose `docs/`.
- **`AGENTS.md`, `CLAUDE.md`, `README`.** Conventions that look like defects to an outsider (no enums, no classes, unusual error handling, and so on) are known non-issues. Note whether the instruction file already has a section listing the review docs.
- **PR reviews.** If `gh repo view` works, read the review threads (`gh api repos/{owner}/{repo}/pulls/<number>/comments`, plus the reviews' bodies) on merged PRs. On a first run, read the last 20 or so. On a rerun, read those merged since the oldest of the docs' last-change dates. Findings the author rejected with a reason that would hold next time are known non-issues. Real bugs that reviews caught more than once are checklist items. A subtle runtime bug that cost real time is a footgun.

When a doc already exists, also check it against its template and against the code:

- **Shape.** Intro or how-to-use text that is missing or behind the template, sections the template now has, entries not in the template's entry format (the claim in bold, then why; for footguns: wrong, what happened, right). Bring the framing up to date, using the project's names. Reformat an entry only when its format differs, keeping its meaning, and its words where they still fit.
- **Staleness.** Entries that name a file, function, config key or tool that no longer exists, or a convention the code no longer follows. Propose updating or removing each one, with the evidence; the user decides.
- **Duplicates and misfiles.** Two entries that say the same thing (merge them), and entries in the wrong doc: a defect class in the non-issues list, a deliberate pattern in the checklist, a runtime trap in the checklist that belongs in footguns.
- **Links.** Links between the docs, and from the instruction file, must point at the docs' real paths.

## 2. Present findings and ask

Summarise what's there and what's missing, then take these sections in order: one section, one answer, then the next. Lead each with your recommendation so the user can accept it in a word. Skip a section with nothing to propose.

**A. Which docs.** For each of the three, say whether it exists, and where, under what name. Recommend creating `KNOWN_NON_ISSUES.md` and `PRE_PR_REVIEW.md` if missing; offer `FOOTGUNS.md`. Give the paths you would use.

**B. New entries.** For each doc, the entries you would add, each with its source: the PR and thread, or the line in `AGENTS.md` / `CLAUDE.md`. A doc with no real entries yet is fine. Never invent an entry, and never add one the doc already covers.

**C. Changes to existing docs.** One list per doc: framing brought up to the template, entries reformatted, stale entries to update or remove, duplicates to merge, entries to move to another doc. Each with a one-line reason.

**D. The instruction file.** A short section in `AGENTS.md` or `CLAUDE.md` (whichever exists; if both, the one the other imports; if neither, ask) listing the review docs and when to read them, since they help whoever writes the code, not only the reviewer. If such a section already exists, propose edits to it, not a second one.

## 3. Draft and confirm

Show the user what you will write: new docs in full, from their templates with the entries from B and the links fixed to the names you chose; changes to existing files as a diff. Let the user edit before writing anything.

## 4. Write and verify

Write the files. Then:

- Check every link between the docs, and from the instruction file, resolves to a file that exists.
- Check no entry was lost: every entry the docs held before this run is still there, or was removed, merged or moved with the user's approval.

Tell the user what was written and that the docs are meant to be committed. Don't commit them yourself. If `.opencodereview/background.md` exists, check it points at the docs' current paths, and suggest `/setup-ocr` if it doesn't.
