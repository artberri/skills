---
name: address-pr-comments
description: Address unresolved PR review comments end to end. Fetch every open thread and any findings left outside threads, evaluate each one (agree or disagree, with a reason), apply the agreed fixes, run the project's checks, commit and push, reply on disagreements, then resolve the threads. Use when the user says "address PR comments", "fix review feedback", "respond to the review", "resolve PR threads", "check PR comments", or shares a PR that has open review threads.
---

# Address PR comments

## Prerequisites

- `gh` CLI authenticated (`gh auth status`)
- Node.js 18+

If either is missing, tell the user and stop.

## Input

A PR number, URL, or nothing: infer it from the current branch if omitted.

## Workflow

### 1. Resolve the PR and gather the feedback

```bash
PR=$(gh pr view --json number -q .number 2>/dev/null || echo "")
node ${CLAUDE_SKILL_DIR}/scripts/pr-threads.mjs list $PR
gh pr view $PR --json body,reviews
```

`list` prints every unresolved inline thread: thread ID, file and line (or just the file for a file-level comment), author, the full comment and any replies. A thread marked `outdated` points at code that has changed since; check whether it still applies.

Reviewers also leave findings outside threads: in a review's summary body (for example, findings in files the PR doesn't change) or in a block they keep in the PR description (a score plus a list of open findings). Read the review bodies and the PR body, and treat each concrete finding there as its own item. A finding in a summary or block that duplicates an open thread is the same item; don't count it twice. A confidence score is context, not an action item.

If there are no unresolved threads and no findings outside threads, tell the user and stop.

### 2. Evaluate each item

For each item, read the referenced file and line in the source code. If the project documents how to handle review feedback (in `AGENTS.md`, `CLAUDE.md` or `CONTRIBUTING.md`), apply that. Otherwise:

- Evaluate the suggestion on its own merits, not on who made it.
- State **agree** or **disagree** with a one-sentence reason.
- If agreeing: describe what needs to change.
- If disagreeing: explain concisely why the current code is correct or why the suggestion would make things worse.

If the project keeps a list of settled conventions (such as `KNOWN_NON_ISSUES.md`), a finding that matches an entry there is a disagree, citing the entry.

### 3. Present the verdict table and wait for confirmation

Present a table before touching any code. The **Source** column tells inline threads apart from findings outside threads:

```
| # | Source | File:Line | Comment (truncated) | Verdict | Action |
|---|--------|-----------|---------------------|---------|--------|
| 1 | Thread | src/foo.ts:42 | "missing dep array" | Agree | move helper to module scope |
| 2 | Thread | src/bar.ts:10 | "fragile string match" | Disagree | pre-existing, out of scope for this PR |
| 3 | Review summary | src/baz.ts:88 | "unhandled null case" | Agree | add null guard |
```

Then ask the user to confirm, saying plainly that confirming means the fixes will be committed and pushed, and the threads replied to and resolved. They may override verdicts or exclude items. Wait for their answer.

### 4. Apply the agreed fixes

Apply each agreed fix, following the project's coding standards (`AGENTS.md`, `CLAUDE.md`, or the surrounding code).

Then run the project's checks: the ones its docs list, or the lint, type-check, format and test commands its CI runs. If any check fails, fix the issue before committing.

### 5. Commit and push

Commit with the `commit` skill if it is available. Otherwise, commit only the files you changed, by name, with a message in the repo's style (`git log --oneline -10`) that says the commit addresses review comments. Then `git push`.

### 6. Reply on disagreements

Steps 6 and 7 apply to inline threads only. Findings outside threads have no thread to reply to or resolve: they are handled by the fix, or reported back to the user in the step 7 summary.

For each disagreed thread, post a reply explaining the reasoning:

```bash
node ${CLAUDE_SKILL_DIR}/scripts/pr-threads.mjs reply <THREAD_NODE_ID> "<reply text>"
```

Keep replies to one or two sentences on why the current approach is correct.

### 7. Resolve the threads

Resolve each agreed thread (it's fixed) and each disagreed thread from a bot (it has a reply explaining the decision):

```bash
node ${CLAUDE_SKILL_DIR}/scripts/pr-threads.mjs resolve <THREAD_NODE_ID>
```

For a disagreed thread from a human reviewer, ask the user whether to resolve it or leave it open for the reviewer to answer.

Tell the user how many threads were fixed, how many were replied to with a disagreement (and which of those were resolved), and how many findings outside threads were addressed or declined.

### 8. Offer a re-review

If the `ocr-review` skill is available and the PR has an OCR review (its summary or PR-body block says "OCR review"), ask: "Want me to re-run the OCR review on the new commits?" If yes, run `/ocr-review --incremental`. Skip the question if the OCR hook is turned on (`OCR_REVIEW_OFFER=1`): the push already triggers it.
