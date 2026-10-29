# Setting up ship

Guidance for `adapt-skill` when it installs or refreshes the `ship` template. It is not copied into the project.

## What to look for

- **Shipping today:** the default branch (`git remote show origin`), and whether recent history arrives through merged PRs (`gh pr list --state merged --limit 20`) or as direct commits on the default branch.
- **Branch and ticket conventions:** remote branch names (`git branch -r`), merged PR titles and commit subjects. Look for a ticket pattern (`ABC-123`, `#123`) and where an ID can be found without asking: the branch name, a plans folder, the issue tracker. Don't assume any particular tracker: use what the project shows, or none.
- **Commit convention:** `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, a commitlint config, and `git log --oneline -30`. Conventional Commits unless the project states, or its history clearly uses, another convention.
- **Tidy commands:** formatter and linter-autofix scripts in `package.json`, the Makefile or the task runner, and git hooks (pre-commit, lefthook, husky) that may already run them on commit.
- **Review docs:** a pre-PR review checklist (`PRE_PR_REVIEW.md` or a doc in that role) and a known non-issues list (`KNOWN_NON_ISSUES.md` or similar), under any name the project uses. The self-review paragraph stays only if the checklist exists; on a refresh, add it if one has appeared since.
- **PR template:** `.github/pull_request_template.md` or a `PULL_REQUEST_TEMPLATE` folder.
- **Reviewers and checks:** which skills are available (`ocr-review`, `address-pr-comments`), the required CI checks on recent PRs (`gh pr checks <n>`), and the authors of reviews on recent PRs (bots other than OCR).

## Questions, in this order

**A. Shipping mode.** Always ask on an install: does this project ship **through pull requests**, or **by committing straight to the main branch**? Recommend what the history shows. Confirm the base branch.

**B. Branch and ticket naming** (pull requests only). Propose the naming you found, with the ticket rule if there is one, or plain kebab-case slugs if there isn't.

**C. Commit convention and tidy commands.** Propose them, or say a git hook already tidies on commit.

**D. Self-review.** If the project has a pre-PR checklist, propose the self-review paragraph pointing at it. If it has none, say the paragraph is left out, and mention that `/setup-ocr` can create one.

**E. Reviews** (pull requests only). Say whether `ocr-review` and `address-pr-comments` are available. Then ask whether anything else should be waited for or checked after the PR opens: required CI checks, or another review bot. Propose what you found on recent PRs.
