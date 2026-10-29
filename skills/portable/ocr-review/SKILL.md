---
name: ocr-review
description: >-
  Review an open pull request locally with Open Code Review (OCR) in delegation mode and post the findings to the PR
  as a GitHub review. OCR picks the reviewable files and the per-path rules (from `.opencodereview/` when the repo has
  one); a fresh subagent with no implementation context does the review on the user's Claude Code subscription, so
  no API cost. Use this skill when a hook asks for it after `gh pr create` or `git push`, when the user asks to
  "review the PR with OCR", "run the OCR review" or "re-review the new commits", or invokes `/ocr-review`
  (optionally with a PR number and `--incremental`).
metadata:
  agents: ocr-reviewer
---

# OCR review

Runs a review of the PR on the current branch and posts it as a single GitHub review: inline comments on lines in the diff, a file-level comment for a finding on a line outside the diff, and the review body for a file the PR doesn't change. The review body ends with a hidden `<!-- ocr-review reviewed-sha=<sha> -->` marker, which is how a later incremental run knows where the last review stopped.

It also keeps a whole-PR verdict in the PR body, between `<!-- ocr_comment -->` and `<!-- /ocr_comment -->`: the PR's confidence score, its summary and every open OCR finding, rewritten on each run. An incremental review scores only its new commits, so this block is where the PR's current score lives.

The optional hook in this skill's `hooks/` folder (see its [README](./hooks/README.md)) asks Claude to run this after `gh pr create`, and after a `git push` to a PR this skill has already reviewed, without asking the user first. Skip it when the PR, or the new commits, are docs-only or a very small, obvious change (a typo, a lint fix, a one-line correction), and say so.

Paths like `scripts/ocr-review.ts` are relative to this skill's folder. Run every command from the repository root, and call the script by its full path: `node <skill folder>/scripts/ocr-review.ts`.

OCR is always run pinned, through npx, so nobody needs a global install:

```sh
npx -y @alibaba-group/open-code-review@1.12.12 delegate ...
```

## Step 0: Check the tools

Run `node --version`. If `node` is not found, tell the user this skill needs Node.js 22.18 or later (for `npx` and for running `scripts/ocr-review.ts`) and stop. If it is older than 22.18, tell them it can't run the TypeScript script and needs upgrading, and stop. `gh` must be installed and logged in too; if `gh auth status` fails, say so and stop.

## Step 1: Resolve the PR and the range

```sh
gh pr view [<number>] --json number,headRefOid,baseRefName,url
git rev-parse HEAD
```

- **No PR:** stop. This skill reviews PRs; for local changes use `/code-review`.
- **Local HEAD differs from `headRefOid`:** the review must match what GitHub shows, or inline comments land on the wrong lines. Tell the user to push (or pull) first. Do not push on their behalf.
- **Full review** (the default, and after `gh pr create`): `git fetch origin <baseRefName>`, then the range is `origin/<baseRefName>..<headRefOid>`.
- **Incremental review** (after a push, or `--incremental`): `node <skill folder>/scripts/ocr-review.ts last-reviewed-sha <number>`. If it prints a sha and `git merge-base --is-ancestor <sha> HEAD` succeeds, the range is `<sha>..<headRefOid>`. Otherwise (no previous OCR review, or a rebase rewrote the branch) fall back to a full review and say why.
- **Review state, on every review, full ones included:** run `last-reviewed-sha` as above. If it prints a sha, the PR has an earlier OCR review: save the output of `node <skill folder>/scripts/ocr-review.ts review-state <number>` to a scratch path. It holds the last PR summary and the still-unresolved OCR findings with their replies. The reviewer closes or keeps each of them, so the PR-body block doesn't drop them or bring them back later, and the post is refused without that verdict while earlier OCR threads are still open.
- **Range already reviewed** (last reviewed sha equals HEAD): say so and stop.
- **New commits only merge the base branch** (every commit `git rev-list --first-parent <sha>..<headRefOid>` prints has a second parent that `git merge-base --is-ancestor <commit>^2 origin/<baseRefName>` accepts): there is nothing of the PR's own to review, so say so and stop. A merge of any other branch, or any own commit, gets reviewed. Conflict fixes made inside a base merge are not reviewed this way; run a full review if a merge needed real conflict work.

## Step 2: Review in a fresh subagent

The session that wrote the code believes it is right, and reviews it accordingly. Spawn the `ocr-reviewer` agent (Agent tool, `subagent_type: "ocr-reviewer"`) with a fresh context. It holds the review instructions and has no edit tools. Its prompt is only the inputs:

```text
Review PR <number>: from <from>, to <to>, base <baseRefName>, mode <full | incremental>, in the repository at <repo root>.
```

When Step 1 saved a review-state file, add `Review state: <path>` with it, on a full review too.

Add nothing else: no design notes, plan context or your own opinion of the change, so the reviewer sees only the code. If the `ocr-reviewer` agent isn't installed, stop and tell the user: this skill needs it.

The agent replies with the findings JSON. Save the reply, as is, to a scratch path (the session scratchpad, or `mktemp`), never a path inside the repo.

## Step 3: Post

```sh
node <skill folder>/scripts/ocr-review.ts post <output path>
```

It checks that the PR head still matches `headSha` and that the scores are integers from 1 to 5. It places each finding inline when its lines are in the PR diff, as a file-level comment when the file is in the PR but the line isn't, and in the review body otherwise. It then rewrites the OCR block in the PR body, leaving everything else in the body (other bots' blocks included) as it was, and prints the review URL. A reply without `priorFindings` while earlier OCR threads are open is refused, as is an incremental one without `prConfidence`, `prConfidenceReason` and `prSummary`. Pass `--dry-run` to print the review, the file-level comments and the PR-body block without posting anything. The review is posted as the user with `event: COMMENT`: GitHub does not let authors request changes on their own PR.

## Step 4: Report

Give the user the review URL, the PR's confidence score (and, on an incremental review, the new commits' score) and a one-line count by severity. Do not start fixing findings unprompted: the user reads them first. A finding that turns out to be a settled convention belongs in the project's known-non-issues file, if `.opencodereview/background.md` names one, so the next review skips it; suggest adding it.
