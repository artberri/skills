---
name: commit
description: Commit the current changes as small, focused, signed commits with messages in the repo's own style that explain why. Use whenever the user asks to commit ("commit", "commit this", "make a commit", "split this into commits"). Never use it unprompted.
---

# Commit

Commits what is in the working tree, the way the user would: one topic per commit, messages in the repo's style, nothing hidden. Run it only when the user asked to commit in this session, and never push.

The conversation you are in is the best source for the *why* of a change. Use it: a message that only restates the diff adds nothing.

## 1. Check the setup

- `git config user.email` and `git config user.name`: is this the identity this repo should use (work vs personal)? If it looks wrong or is unset, stop and ask.
- `git config commit.gpgsign`: note whether commits are signed. If signing fails later, stop and tell the user. Never pass `--no-gpg-sign` or turn signing off.
- `git branch --show-current`: if this is the default branch of a repo where work goes through pull requests, ask whether to create a branch first.
- Read the project's commit rules if any: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, a commitlint config, `.gitmessage`. They win over this skill.

## 2. Read everything that will be committed

- `git status --short`, `git diff` and `git diff --cached`. Staged changes may come from the user or another tool; include them in your plan, and don't unstage anything without saying so.
- Untracked files: decide for each whether it belongs in a commit, should be ignored, or should be left alone. Ask when unsure.
- Scan the diff for anything that must not be committed: secrets, tokens, private keys, `.env` files, and absolute paths containing a username (`/Users/<name>/`, `/home/<name>/`). If the repo is public (`gh repo view --json visibility`), also look for internal hostnames, work identifiers and personal data. Stop and report anything you find.

## 3. Plan the commits

Group the changes by topic: one commit per thing a reader would want to revert or review on its own (a feature, a fix, a CI change, a rename). Then order them so each commit works without the later ones.

When one file holds changes for two topics, split it: stage a version of the file with only the first topic's changes. See [PARTIAL-STAGING.md](./PARTIAL-STAGING.md); interactive `git add -p` is not available.

If the split is not obvious, show the plan (commits, files, messages) and ask before committing.

## 4. Write the messages

Match the style of `git log --oneline -20`: Conventional Commits (`feat:`, `fix:`, `ci:`), a ticket prefix, plain imperative sentences, whatever the repo uses. In a repo with no history, use Conventional Commits.

- Subject: what the commit does, in the repo's style, under about 72 characters.
- Body, when the subject isn't enough: why the change was made, and anything a reviewer would not see in the diff. Leave out what the diff already shows.
- Add trailers (`Co-authored-by`, `Signed-off-by`, issue links) only when the repo's convention or the user's instructions ask for them.

## 5. Commit

- Stage exactly the planned files or hunks, and check with `git diff --cached --stat` before each commit.
- Commit with `-m` for the subject and another `-m` for the body. Never use `-q`/`--quiet`: it hides warnings such as a guessed identity.
- If a pre-commit hook fails, fix what it reports and commit again, or tell the user. Never pass `--no-verify`.
- If signing fails, stop and tell the user.

## 6. Verify

- `git log --show-signature -<n>` (when signing is on): each new commit has a good signature from the expected key.
- `git status --short`: report anything left uncommitted, and why.
- If you split a file across commits and the repo has a quick check (a lint or validation script, or tests that run in seconds), run it against each earlier commit on its own: `git archive <sha> | tar -x -C <scratch dir>`, then run the check there.

Report each commit's hash and subject, the signature status, and what is left uncommitted. Don't push.
