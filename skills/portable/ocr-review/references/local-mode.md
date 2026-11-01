# Local mode

Reviews the commits on the current branch that haven't shipped yet, with no PR and no GitHub: for projects that push straight to the default branch, or a branch that has no PR yet. The reviewer and the rules are the same as for a PR. Only the range, the review state and where the findings go change.

The findings go into a Markdown report and a state file in the git dir, one pair per branch: `$(git rev-parse --git-path ocr-review)/<branch>.md` and `.json`, with the branch name URL-encoded. They are never committed and never leave the machine. `address-pr-comments --local` works through them. Once the reviewed commits have shipped (they are in the base, or their changes are, after a rebase gave them new shas), or the branch has nothing left to ship, the next run drops both files, as a merged PR leaves its threads behind.

Step 0 still applies, except that `gh` isn't needed.

## Step 1: Resolve the base and the range

The base is the remote's default branch: `git symbolic-ref --short refs/remotes/origin/HEAD` (for example `origin/main`). If that fails, use `origin/main` or `origin/master`, whichever exists. With no `origin` remote, stop: local mode needs a base to compare with. Then fetch it: `git fetch origin main` for a base of `origin/main`.

HEAD must be on a branch and the change committed: OCR reviews commits. If the working tree has changes in tracked files, tell the user to commit first (or ship them, which commits) and stop.

```sh
node <skill folder>/scripts/ocr-review.ts review-state --local --base <base> > <scratch path>
node <skill folder>/scripts/ocr-review.ts last-reviewed-sha --local --base <base>
```

Run `review-state` first: it drops a state whose commits have shipped.

- **Nothing to ship** (`git rev-list --count <base>..HEAD` prints `0`): say so and stop.
- **Full review** (the default): the range is `$(git merge-base <base> HEAD)..HEAD`.
- **Incremental review** (`--incremental`, or after fixing earlier local findings): if `last-reviewed-sha` prints a sha and `git merge-base --is-ancestor <sha> HEAD` succeeds, the range is `<sha>..HEAD`. Otherwise (no earlier review, or a rebase rewrote the commits) fall back to a full review and say why.
- **Review state:** when `last-reviewed-sha` prints a sha, the branch has an earlier local review: pass the saved `review-state` output's path to the reviewer, on a full review too. It holds the earlier summary, which an incremental review builds on, and the findings still open.
- **Range already reviewed** (the last reviewed sha equals HEAD): say so and stop.
- **New commits only merge the base:** the same check as for a PR, with `<base>` in place of `origin/<baseRefName>`.

## Step 2: Review in a fresh subagent

As for a PR, with this prompt:

```text
Review the local commits: from <from>, to <HEAD sha>, base <base without the origin/ prefix>, mode <full | incremental>, in the repository at <repo root>.
```

Add `Review state: <path>` when Step 1 says to. Save the reply to a scratch path, never inside the repo.

## Step 3: Save

```sh
node <skill folder>/scripts/ocr-review.ts post <output path> --local --base <base>
```

It checks HEAD still matches `headSha` and that the scores are integers from 1 to 5, closes the earlier findings the reviewer marked closed, adds the new ones with ids, and prints the report and its path. It refuses a reply without `priorFindings` while earlier local findings are open, and an incremental one without `prConfidence`, `prConfidenceReason` and `prSummary`. `--dry-run` prints the report without saving anything.

## Step 4: Report

Show the user the open findings from the report, with their ids, the confidence score (and, on an incremental review, the new commits' score) and the report's path. Mention the `.opencodereview/` line from the PR flow when it applies. Don't fix anything unprompted: offer `address-pr-comments --local` to work through the findings.
