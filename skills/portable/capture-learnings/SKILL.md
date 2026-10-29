---
name: capture-learnings
description: Review the current conversation for reusable learnings (corrections, gotchas, patterns, missed skills, procedures worth turning into a skill), check them against the project's existing docs, and, once the user approves, write them into the project where the next agent will find them. Use whenever the user asks to capture learnings, review what was learned, document gotchas or corrections, extract reusable patterns, write down mistakes so they don't repeat, check whether anything belongs in AGENTS.md or a skill, or do a post-task review. Trigger phrases include "capture learnings", "what did we learn", "document the gotchas", "write those down", "pull out anything for future reference", "extract patterns", "/capture-learnings". Also offer it at the end of a non-trivial task, even if not asked.
---

# Capture learnings

Review the current conversation for reusable corrections, gotchas and patterns, and document them in the project, where every agent and teammate working on it will find them. Never in an agent's personal memory.

## 0. Map the project's docs

Before extracting anything, find where this project keeps what agents should know. Read, don't assume:

- **The instruction file:** `AGENTS.md` or `CLAUDE.md` at the root (if one only imports the other, the imported one is the real target), plus any nested ones in subfolders. Note its sections: rules, conventions, a list of skills, references, checks to run.
- **Project skills:** `.claude/skills/`, `.agents/skills/`, or wherever the instruction file says skills live, with their reference files. A skill installed from a template (its frontmatter has `metadata.template-revision`) belongs to the project and can be edited; a refresh with `adapt-skill` keeps those edits.
- **Review docs**, if the project has them, under any name: a known non-issues list (`KNOWN_NON_ISSUES.md`), a pre-PR review checklist (`PRE_PR_REVIEW.md`), a pitfalls doc (`FOOTGUNS.md`).
- **Available skills:** the skills you can invoke in this session, including those from plugins.

## 1. Extract candidates

Scan the conversation for:

- **Corrections:** moments the user said "no", "not like that", "instead do...", or you had to redo something.
- **Gotchas:** unexpected behaviour, subtle bugs, or non-obvious constraints found during the work.
- **Patterns:** approaches that worked well and aren't documented yet.
- **Missed skills:** skills that were available and should have been used but weren't.
- **New skill candidates:** multi-step procedures you carried out that would make a good skill. A candidate qualifies only if **all** apply:
  - It took three or more distinct steps (not a single command or one-off edit).
  - It has clear inputs the user would pass next time (an issue ID, a file path, a URL).
  - It has a clear output or end state (a file written, a PR opened, a report produced).
  - The same procedure would run the same way on different inputs.
  - No existing skill covers it.

  A single-rule correction ("use X instead of Y") is not a skill candidate: it belongs in the instruction file or a reference. How often a procedure recurs across sessions can't be seen from one conversation, so judge candidates by their shape and let the user decide.

For each candidate, write:

- **What:** a one-line summary.
- **Why it matters:** what went wrong, or what it prevents.
- **Where it belongs:** the file to update (see the placement rules below).

## 2. Verify against the existing docs

This step prevents duplicates and puts each learning where it will be found. For each candidate:

1. **Read the target file.** Don't go from memory.
2. **Search for existing coverage** in the target file and the instruction file, by keywords related to the learning.
3. **Classify it:**
   - **skip:** the rule or pattern is already documented. Quote the existing text. But if it exists and was still broken in this conversation, ask why: it may be buried, worded so it isn't found, or missing from where the work happened. If the docs failed to prevent the mistake, mark it **discoverability** instead and propose one of:
     - stronger trigger words or a more prominent place in the instruction file, so the rule is found earlier;
     - a cross-reference from where you were working to where the rule lives;
     - a better `description` for the skill that should have been used, with the skill-creator skill if it's available.
   - **amend:** the idea is documented but misses the nuance you found. Name the gap.
   - **add:** genuinely new.

## 3. Propose

Present every candidate in a table, with its status, so the user can see your work:

```
| # | What | Where | Status |
|---|------|-------|--------|
| 1 | Missing edge case in a shared hook | AGENTS.md → Conventions | add: not documented |
| 2 | Use skill X before Y work | skill X description | skip: already in AGENTS.md |
| 3 | Check reference X before doing Y | AGENTS.md → Checks | discoverability: rule exists, but its wording misses common task terms |
| 4 | Bundle a multi-step procedure | new skill | new-skill: 4 steps, input an issue ID, output a resolved issue |
```

For **add** and **amend**, show the exact text you'll insert and where (the section, and after which line or paragraph), so the user approves precise edits, not intentions.

For **new-skill**, show the proposed name, a one-line description of what it does and when it triggers, the steps it would automate, and its inputs and outputs. Don't create the skill yourself: the user decides, then uses the skill-creator skill (or asks you to).

**Wait for the user's confirmation.** They may remove, edit or redirect entries before anything is written.

## 4. Document

Apply the confirmed learnings:

- Keep additions minimal and in the style of each file.
- In the instruction file, add to the most relevant existing section; create a new one only if nothing fits.
- In a skill's references, add next to the related topic, not in a separate "learnings" section.
- In a skill's `SKILL.md`, broaden the `description` if its trigger wording was the problem.

## 5. Verify

If any source code was touched, run the project's checks: those its instruction file lists, or the ones its CI runs. For docs-only changes, re-read the edited sections to confirm they say what was approved.

Don't commit; tell the user what changed so they can.

## Placement rules

Put each learning where the next agent will find it, using the structure you mapped in step 0:

| Learning | Target |
|----------|--------|
| A rule that must always or never be followed | The instruction file's rules section |
| A project convention or architecture fact | The instruction file's most relevant section |
| A gotcha specific to one skill's area | That skill's reference files, next to the related topic |
| A skill that exists but wasn't used | That skill's `description` (a project skill), or the instruction file's list of skills |
| A runtime pitfall that passes review and type checks | `FOOTGUNS.md`, if the project has one |
| A review finding that is a settled convention, not a defect | `KNOWN_NON_ISSUES.md`, if the project has one |
| A defect class that review keeps catching | `PRE_PR_REVIEW.md`, if the project has one |
| A reference worth linking | The instruction file's references section |
| A multi-step procedure no skill covers | A new skill proposal (never created automatically) |

A skill that comes from a plugin isn't the project's to edit: don't touch the plugin's installed files. Propose the change to the user so they can make it where the plugin is maintained, and put any project-specific workaround in the instruction file.

## Rules

- **Never** write learnings to an agent's personal memory. They go into the project, so they reach everyone working on it.
- Prefer existing files and sections. If a learning fits nowhere, suggest a new document or skill and let the user decide.
- **Never** document what can be read from the code. Only document what an agent would get wrong without the learning.
