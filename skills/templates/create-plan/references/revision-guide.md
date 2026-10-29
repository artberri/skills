# Revising a plan

Loaded by `create-plan` when it's given a plan folder that already has plans, or `revise <folder>`.

## Revise, or create a new plan?

| Situation | Action |
| --------- | ------ |
| Requirements changed for an in-progress plan | **Revise** the existing plan |
| Sources updated (spec edited, new designs, new acceptance criteria) | **Revise**: re-read them and diff |
| Scope grew a lot (a new area, a new domain) | **New plan** |
| The plan was rejected entirely | **New plan** |
| A different feature, even a related one | **New plan**: keep plans focused |

## What to revise

- **A folder with `board.md`:** every `.plan.md` in it, with a diff per plan. Adding a ticket means a new `.plan.md` placed on the board by its dependencies; removing one means marking it removed on the board and keeping the file for reference.
- **A folder with `plan.md`:** that plan.
- **A path to one `.plan.md`:** only that plan.

## Rules

1. **Completed phases are locked.** A phase whose title ends with ✅ is never changed: not its content, numbering or checklists. Show it as locked, for context.
2. **Keep the numbering.** Don't renumber phases; append new ones, or insert them as sub-phases (`Phase 3b`), so references stay valid.
3. **Refresh the context.** Update **Sources**, **Contracts**, **Dependencies** and **Behaviour** from what you re-read.
4. **Settle open questions.** Mark the ones the new information answers as `Resolved`; add the ones the diff raises.
5. **Overwrite, don't duplicate.** Save the revision to the same file. `brief.md` stays as it was.
6. **Ask first.** Show the diff and wait for the user's approval before saving.

## The diff

Present the changes in four groups:

- **Locked:** the completed phases, by title, for reference.
- **Modified:** each incomplete phase that changes: what changed (to-dos, checklists, description) and which source drove it.
- **New:** each requirement no existing phase covers: where it would go and where it came from.
- **Removed:** each requirement the sources no longer mention, and why it's going. Confirm each one with the user: the omission may be accidental.
