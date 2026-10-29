---
name: execute-plan
description: >-
  Execute an implementation plan written by `create-plan`, one phase at a time, with outside-in TDD and small
  commits, and archive it when the last phase is done. Handles boards (several ticket plans in one folder) by picking
  the next plan whose dependencies are done. Use whenever the user wants to execute, run, resume or continue a plan:
  `/execute-plan`, "execute the plan", "run the plan", "continue the plan", "work on the next phase", or when they
  point at a plan folder or file and ask to start implementing it. For creating a plan, use `create-plan`.
argument-hint: "[plan folder | plan file]"
metadata:
  template-revision: "1"
---

# Execute a plan

Carries out a plan from `create-plan`, phase by phase. Each phase is a vertical slice: when it's done, tests pass, the build is green, and the plan's checkboxes and ✅ markers say so.

**The critical rule:** execute only the **current phase** per invocation. When it's done, stop and ask before starting the next. Each phase stays atomic and reviewable.

<!-- CUSTOMIZE: the project's plans folder: the same one create-plan uses. -->
Plans live in **`.agents/plans/`**, the plans folder. Completed plans are archived under its `done/` folder, which is never searched for an active plan.

## Step 1: Find the plan

| The user gave | What to do |
| ------------- | ---------- |
| A folder with `board.md` | **Board mode:** show the board's checklist and propose the first unchecked plan whose dependencies are all checked. The user can pick another; if its dependencies aren't done, warn and let them go ahead anyway. |
| A folder with `plan.md` | Execute `plan.md`. |
| A path to a `.plan.md` file | Execute that plan. If its folder has a `board.md`, read it for context. |
| A topic | List the plan folders (not `done/`), pick the best match, and confirm it. |
| Nothing | List the plan folders (not `done/`) and ask which one. |

## Step 2: Find the current phase

The current phase is the **first** phase whose title doesn't end with ✅. Completed phases are never re-executed, amended or "cleaned up". If every phase is ✅ but the plan isn't archived yet, go to step 7.

The **Next step** section should agree. If it doesn't (it points at a phase already marked ✅), raise the inconsistency before going on.

Before starting the phase:

- **Open questions:** if **Open questions and risks** has `Open` items that affect this phase, list them and ask whether to resolve them now, defer them, or go ahead.
- **Phase metadata:** a `> Skills:` line names skills to load first. A `> Design:` line links the design for this phase: read it with the tools available before building UI. A `> Ticket:` line names the ticket the phase belongs to.

## Step 3: Set up the branch

<!-- CUSTOMIZE: branching. If the project has a ship skill, follow its branch convention (feature branches and their naming, or committing straight to the main branch). Otherwise use what the project's docs and history show. Include the ticket rule if there is one. -->
Work on a feature branch, one per plan: on a board, each plan gets its own branch from the base branch, not from the previous plan's branch. If the current branch already belongs to this plan (you're resuming), stay on it. Otherwise create `<short-kebab-slug>` from the base branch, named after the plan, with `git switch -c`. Never switch branches mid-phase.

## Step 4: Execute the phase

Work through the phase's **TDD checklist** and **To-do** top to bottom, outside in, in baby steps:

<!-- CUSTOMIZE: how tests are written and run in this project: the test skills it has (write-tests, run-tests), the commands to run a single test file, and the kinds of test (acceptance, integration, unit) and where each lives. -->
1. For each behaviour change, bug fix or new feature step: write the failing test first, run it with `npm test -- <file>`, and check it fails for the right reason. Write the minimum code to pass it, then refactor with the tests green.

<!-- CUSTOMIZE: project-specific procedures some to-dos need: a skill or doc for database migrations, code generation after changing events or schemas, batch scripts. Delete this item if there are none. -->
2. For database schema changes, follow the project's migration process.

3. Commit **small, stable units**: one atomic change per commit, not one commit per phase.
4. Don't silently expand scope. If you find something the phase doesn't cover, raise it with the user instead of tacking it on.

**Check in on large phases.** With fewer than 5 to-dos, work straight through. With more, pause every 5 or so: summarise what's done (files changed, decisions made) and ask "Continue?".

## Step 5: Before each commit

<!-- CUSTOMIZE: the checks to run before each commit, scoped to what changed: formatter and linter on the changed files, type check on the affected package only, the tests touched. Name the exact commands. Drop any a git hook already runs on commit. -->
- [ ] Format and lint the changed files: `npm run format -- <files>`, `npm run lint -- <files>`.
- [ ] Type-check the affected package: `npm run typecheck`.
- [ ] Run the tests you touched, not the whole suite.
- [ ] Update the plan file:
	- Tick the to-dos and TDD items this commit completes.
	- For each **Behaviour** rule a test in this commit proves, fill in its _proved by:_ with the test file and name.
	- Mark the phase title with ✅ only when every item in the phase is ticked.
	- Update **Next step** when you cross a to-do boundary or finish the phase.
- [ ] Commit the plan file together with the code: progress and code travel together.

Commit with the `commit` skill if it's available.

<!-- CUSTOMIZE: the commit message convention. Conventional Commits unless the project states another; add the ticket rule from step 3 if there is one. -->
Messages follow Conventional Commits: `<type>(<scope>): <imperative summary>`.

If a check or test fails, fix it before committing; don't mark anything done until the phase's **Verify** items pass.

## Step 6: End of the phase: stop

When the phase title has its ✅:

1. Summarise the phase: the commits, the files touched, and any deviation from the plan.
2. Raise anything surprising: tests you had to rework, scope the plan didn't foresee, follow-ups for later phases. A follow-up the user agrees to defer goes in the plan's **Open questions and risks** as `Deferred`.
3. If this was the plan's last phase, go to step 7. Otherwise **ask whether to start the next phase**; don't continue on your own. If the user agrees, go back to step 2.

## Step 7: End of the plan: archive

When every phase of the plan is ✅, archive it in the same commit that closes the last phase:

- **Single plan:** move the plan's folder into `done/`, prefixed with today's date:

  ```sh
  git mv <plans folder>/<name> <plans folder>/done/$(date +%Y-%m-%d)-<name>
  ```

- **Board, other plans still open:** tick this plan on `board.md` in place, appending its branch (and PR, if any): `1. [x] ... | <branch> | PR #123`. Don't archive the folder yet. Show the updated board and suggest the next plan whose dependencies are done, ideally in a fresh session.
- **Board, this was the last plan:** tick it, then move the whole board folder into `done/`, prefixed with today's date, the same way.

Use `git mv`, never `mv` or `rm`, so history records a rename. Then tell the user the plan is complete and where it was archived.

A completed plan found unarchived (every phase ✅, or every board item ticked) gets archived in a commit of its own.

## Edge cases

- **Plan not found:** list what's in the plans folder and ask.
- **Resuming mid-phase:** you're on the plan's branch with uncommitted changes that belong to the current phase. Don't create a new branch, and don't stash or discard anything: read the plan, work out which to-do you were on, and continue. Ask if unsure.
- **Several phases in one go:** confirm explicitly first. Even then, commit and ✅ each phase on its own.
- **The plan no longer matches the code** (someone already made a change): don't redo the work blindly. Raise the mismatch and ask how to reconcile it before editing anything.
