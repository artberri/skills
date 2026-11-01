---
name: ship
description: >-
  Take finished work from the working tree to shipped in one move: commit it, bring the branch up to date, push, and,
  when the project ships through pull requests, open the PR and see it through the first review round. Use whenever the
  user wants to "ship", "ship it", "open a PR", "raise a PR", "create a pull request", "commit and push this", "get this
  reviewed", or invokes `/ship` (optionally with `--base <branch>`). Reach for it the moment a chunk of work is finished.
metadata:
  template-revision: "2"
---

# Ship

Gets finished work shipped with as little ceremony as possible: the safe, conventional choices (branch name, what to commit, commit message, PR title and body) are made automatically, so the user goes from a dirty working tree to a shipped change in one invocation.

**Operating principle:** decide and act, don't interrogate. Stop and ask only for the judgment calls the user must own: a possible secret, files that look unrelated to the change, a rebase conflict, or a review finding that needs a product decision.

<!-- CUSTOMIZE: how this project ships. Keep one of the two variants, "pull requests" or "main branch", in this paragraph and in steps 2, 4, 5, 6 and 7, and delete the other. Set the base branch to the remote's default branch (`git remote show origin`). -->
This project ships **through pull requests** against `main`. `ship` accepts `--base <branch>` to target another base. (Main-branch variant: this project ships **by committing straight to `main`**: no feature branches, no pull requests.)

## Step 1: Read the current state

```sh
git branch --show-current
git status --short
git log --oneline -5
```

## Step 2: Branch

**Pull requests.** Never commit work onto the base branch. On a feature branch, stay on it: never switch, never create a duplicate. On the base branch, create a feature branch before committing anything, with `git switch -c <name>`, without asking.

<!-- CUSTOMIZE: branch naming and ticket references. Look at remote branch names (`git branch -r`), merged PR titles (`gh pr list --state merged --limit 30`) and commit subjects for a ticket pattern (`ABC-123`, `#123`), and note where a ticket ID can be found without asking (the branch name, a plans folder, the issue tracker). If the project uses no tickets, keep only the semantic name. -->
Name the branch with a short kebab-case slug of the change, such as `fix-timezone-logging`. This project doesn't use ticket IDs.

**Main branch.** Stay on `main`. If you are on another branch, ask the user: don't merge or rebase it into `main` on their behalf. Detached HEAD: stop and ask them to check out a branch.

## Step 3: Commit

**Keep the change coherent.** Look at the changed files. If some clearly don't belong to the same change as the rest (a fix to one feature plus an unrelated CI edit), ask whether to include them. The default is one coherent change per ship.

<!-- CUSTOMIZE: the tidy commands to run on the files about to be committed (formatter, linter autofix), from package.json scripts, the Makefile, or the pre-commit / lefthook / husky config. If a git hook already runs them on commit, say so instead and drop the commands. -->
**Tidy** the source files you're about to commit: `npm run format -- <files>` and `npm run lint -- --fix <files>`.

<!-- CUSTOMIZE: keep this paragraph only if the project has a pre-PR review checklist (PRE_PR_REVIEW.md or a doc playing that role), and fix the path. Mention the known non-issues file only if the project has one (KNOWN_NON_ISSUES.md or similar). Delete the paragraph otherwise. -->
**Self-review** what you are about to commit against [docs/PRE_PR_REVIEW.md](../../../docs/PRE_PR_REVIEW.md): the "Always" list plus the sections matching what you touched. Do it before committing, so a fix is just another edit rather than an amend. If something you find is a settled convention rather than a defect, it belongs in [docs/KNOWN_NON_ISSUES.md](../../../docs/KNOWN_NON_ISSUES.md).

**Commit** with the `commit` skill if it is available: it checks the identity, scans for secrets, and splits the work into focused commits. Tell it the message convention below. If nothing is pending and the branch already has commits, skip committing.

Without the `commit` skill: stage by explicit path, never `git add -A`. Don't stage anything that looks like a secret (`.env` files, keys, credentials, files containing tokens): list them and ask. Then commit with the convention below.

<!-- CUSTOMIZE: the commit message convention. Conventional Commits unless the project states another (AGENTS.md, CONTRIBUTING.md, commitlint config) or its history clearly uses one. Add the ticket rule from step 2 if there is one. -->
**Message convention:** Conventional Commits, `<type>(<scope>): <imperative summary>`. `type` is `feat`, `fix`, `chore`, `refactor`, `docs`, `test` and so on, inferred from the diff; `scope` is the dominant package or module, and can be left out when there isn't one.

## Step 4: Bring the branch up to date

**Pull requests:** `git fetch origin <base>` then `git rebase origin/<base>`.

**Main branch:** `git pull --rebase origin main`.

On a conflict, stop: report the conflicting files and ask how to proceed. Never guess a resolution.

## Step 5: Push

**Pull requests:** `git push -u origin <branch>` for a new branch, `git push --force-with-lease` once it exists on the remote (after a rebase). Never a bare `--force`. If the push is rejected, the remote has commits you don't: stop and ask.

**Main branch:** `git push origin main`, never forced. If it is rejected, run step 4 once more and retry; if it is rejected again, stop and ask.

## Step 6: Open the pull request

**Main branch:** skip this step.

**Pull requests.** If `gh pr view --json url,number` finds a PR for the branch, the push already updated it: don't open another. Otherwise:

```sh
gh pr create --base "<base>" --title "<title>" --body "<body>"
```

- **Base:** the `--base` value if given, otherwise the project's base branch.
- **Title:** the commit convention's subject for the whole change. For a single-commit PR, the commit subject.

<!-- CUSTOMIZE: the PR body. If the repo has a pull request template (.github/pull_request_template.md), mirror its sections here: `gh pr create --body` bypasses it. Add a "Self-review" section only if step 3 has the self-review paragraph, linking the checklist by its absolute GitHub URL (a relative link in a PR body resolves against the repo root). -->
- **Body:** grounded in the full diff (`git diff origin/<base>...HEAD`), no boilerplate:

  ```markdown
  ## Summary

  <1-3 sentences on what this change does and why>

  ## Changes

  - <key change>
  ```

  Mention anything deliberate a reviewer would otherwise flag: it pre-empts the finding.

**Updating a PR body later:** never replace it wholesale with `gh pr edit --body`. Review bots keep their own blocks in it (OCR between `<!-- ocr_comment -->` and `<!-- /ocr_comment -->`). Read the current body, edit around those blocks, and write back the merged result.

## Step 7: First review round

**Main branch:** skip to the checks paragraph below, if this project kept it.

**OCR review.** If the `ocr-review` skill is available, run it on the PR right after it is opened, without asking. Skip it for a docs-only PR or a very small, obvious change, and say so. If the OCR hook is on, it asks for the same review: run it once.

<!-- CUSTOMIZE: other reviewers or checks to wait for besides OCR: a review bot, required CI checks. Find them on recent PRs (`gh pr checks <n>`, the authors of their reviews). Keep the wait bounded. Delete this paragraph if there are none. -->
**Checks.** Wait for the required CI checks, bounded: poll `gh pr checks <n>` about every 30 seconds for at most 10 minutes. If they haven't finished, report them as pending; never hang the ship on a slow check. A failing check is a finding.

**Address the findings.** If the `address-pr-comments` skill is available, run it on the PR to work through the review's findings. It shows a verdict table and waits for the user's confirmation before changing anything. Otherwise, list the findings in the report and leave them for the user. One bounded review pass per ship: don't wait for a second round.

## Step 8: Report

Give the user the result plainly: the PR URL (or, on the main branch, the pushed commits), plus a one-line recap of the branch, the commit subjects and the base. Note what the review round found and what happened to each finding, and anything left for the user to decide.

## Edge cases

- **Clean tree, already pushed.** Nothing to do but confirm: return the existing PR URL or the last pushed commit.
- **Clean tree on the base branch, nothing unpushed.** There's nothing to ship. Say so rather than creating an empty branch.
- **`gh` not authenticated.** Surface the error and suggest `gh auth login`. Never invent a PR URL.
- **A review never arrived.** Deliver the result with the review noted as pending. Never imply a change is clean because no review came in.
