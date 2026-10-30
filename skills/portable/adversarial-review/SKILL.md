---
name: adversarial-review
description: >-
  Review local changes before they ship by starting reviewers with a fresh context who know only what the change
  should achieve: no implementation notes, no design reasoning, no conversation. Quick mode uses one reviewer; council
  mode runs several in parallel, each focused on one area (concurrency, edge cases, error handling, security...), and
  ranks findings by how many reviewers found them independently. Use when the user wants a sanity check on changes
  before committing or opening a PR: "adversarial review", "council review", "devil's advocate", "poke holes in this",
  "find what I missed", "what could go wrong", "second pair of eyes", or `/adversarial-review`. Especially worth it
  after long, non-trivial work on concurrency, state, lifecycle or async ordering, where the implementer's model can
  drift from what the code does. For an open pull request, use `ocr-review` instead.
argument-hint: "[files or paths to review]"
---

# Adversarial review

Starts reviewers with a fresh context that know only what the change **should** do, and asks them to find where it doesn't.

It works because the session that wrote the code has a mental model that justifies every line. Reviewers briefed only on the desired outcomes can't lean on that justification, so they find the races, edge cases and cold starts the implementer's model glossed over.

## Step 1: Resolve the scope

By default, review the current branch against the base branch. Find it with `git symbolic-ref --short refs/remotes/origin/HEAD`, falling back to `main` or `master`.

```sh
git diff <base>...HEAD --stat
git status --short
```

Include uncommitted changes in the scope. On the base branch itself, review only the uncommitted changes. If the user named files or paths, review those instead.

Say the resolved scope back in one line and go on unless the user corrects it. If there's nothing to review, say so and stop.

## Step 2: Capture the desired outcomes

The reviewers check the code against these, so they must be **outcome-shaped, not solution-shaped**. "When the user cancels mid-upload, the partial file is deleted and the quota restored" is good. "We track uploads in a map and clear it in `finally`" leaks the solution and neutralises the review.

Find them in this order:

1. **A plan:** if the change comes from a plan (a `plan.md` or `.plan.md` in the project's plans folder, often named in the branch or the conversation), take the **Behaviour** rules of the phases in scope.
2. **The conversation:** outcomes the user stated, such as numbered cases or acceptance criteria.
3. **The user:** otherwise ask, in one short message: "What should this change accomplish? Just the behaviour: outcomes, edge cases, invariants. Not how the code does it."

When you found them in a plan or the conversation, show them and confirm before going on. Strip any implementation detail that crept in.

## Step 3: Choose the mode

Ask the user to pick one:

| Mode | When |
| ---- | ---- |
| **Quick** | One reviewer looking at everything. Fast and cheap; for small or focused changes. |
| **Council** (recommended for non-trivial changes) | You propose three focus areas from [references/lenses.md](references/lenses.md) that fit the change, with a one-line reason each. One reviewer per area, in parallel. |
| **Custom** | The user picks the focus areas from the catalog. One reviewer per area. |

## Step 4: Start the reviewers

Build each reviewer's prompt from [references/reviewer-prompt.md](references/reviewer-prompt.md). Reviewers don't see this conversation, so each prompt must stand on its own.

- **Quick:** one general-purpose agent, with the template's general checklist.
- **Council and Custom:** one general-purpose agent per focus area, all started in a single message so they run in parallel. Each prompt gets a reviewer number, its focus area and description from the catalog, and the line "Your primary focus is <area>, but flag anything else you find."

**Never put in the prompt:** your view of why the code is right, design notes or trade-offs, commit messages, the conversation that led to the design, or verdicts agreed earlier ("we already decided X is fine"). They bias the reviewer towards agreeing.

**Always put in the prompt:** the repository's absolute path, the files in scope, the diff commands to run, the desired outcomes word for word, and one to three failure modes specific to this change.

## Step 5: Triage

Read the flagged code yourself before showing anything, and classify each finding:

- **Real:** you can describe the concrete path to the failure.
- **Already handled:** the reviewer missed code that deals with it; cite the line.
- **Self-corrected:** the reviewer raised it, then withdrew it in its own reasoning. Drop it.
- **Speculative:** you can't confirm it either way. The user decides.

In council and custom modes, first merge the findings across reviewers. Findings within about five lines of each other in the same file are usually one issue. Count how many reviewers found each one independently:

| Found by | Consensus |
| -------- | --------- |
| All, or all but one | **Strong:** almost certainly real. |
| Two or more | **Partial:** likely real. |
| One | **Solo:** a blind spot the others missed, or a false positive. Triage these with most care. |
| One, and another said it's fine | **Disputed.** |

## Step 6: Present the verdict

One table, most serious first:

```
| # | File:line | Issue | Consensus | Severity | Verdict | Action |
| - | --------- | ----- | --------- | -------- | ------- | ------ |
| 1 | src/upload.ts:42 | Cancel during retry leaves the quota reserved | 3/3 strong | blocker | Real | fix |
| 2 | src/upload.ts:88 | Timer not cleared on error | 1/3 solo | serious | Real | fix |
| 3 | src/quota.ts:17 | Negative quota on double refund | 1/3 solo | nit | Speculative | you decide |
```

Drop the consensus column in quick mode. Below the table, in council and custom modes, add a short summary: how many issues, how many reached consensus, and any area every reviewer agreed is correct, which is worth knowing too.

**Don't fix anything until the user says which findings to act on.** Then apply the fixes, run the project's checks on what changed, and commit with the `commit` skill if it's available, in commits of their own, separate from the reviewed work.

## When not to use it

- A small edit whose correctness is clear: the overhead isn't worth it.
- Pure styling changes, with no behaviour to get wrong.
- When the user wants an opinion on direction or design, not a bug hunt.
