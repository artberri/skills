---
name: create-plan
description: >-
  Create a phased implementation plan for a feature, refactor, migration or bug fix, in the project's plans folder,
  for `execute-plan` to carry out. Use whenever the user wants to plan, design or scope out work before writing code:
  `/create-plan`, "create a plan", "draft a plan", "plan out this task", "let's plan this", "write an implementation
  plan", or a non-trivial change they ask how to break down. Also revises an existing plan ("update this plan",
  `/create-plan revise <folder>`) and audits one against the code ("audit this plan", "review the plan", "poke holes
  in this plan", `/create-plan audit <folder>`). Small, single-phase or decision-free work gets a suggestion to
  execute directly instead. For executing a plan, use `execute-plan`.
argument-hint: "[brief path | plan folder | revise <plan folder> | audit <plan folder>]"
metadata:
  template-revision: "2"
---

# Create a plan

Produces a plan that a later session, or this one, carries out with `execute-plan`. A plan is a sequence of phases; each phase is a vertical slice that is independently shippable and small enough to review in one sitting.

**Don't write anything to disk until the user has agreed** on the task, the contracts, the ticket (if any) and the phase breakdown. The plan is the artifact; the conversation before it is where the thinking happens. And not every plan needs a file: step 4 checks that.

<!-- CUSTOMIZE: the project's plans folder. Use the one it already has (look for .agents/plans/, .ai/plans/, docs/plans/, plans/); if it has none, ask the user, recommending .agents/plans/. If execute-plan is installed, use the same folder it does. -->
Plans live in **`.agents/plans/`**, the plans folder. Completed plans are archived under its `done/` folder by `execute-plan`.

## Plan folders

Every plan is a folder named in kebab-case, with no date: a date is added only when the plan is archived.

**Single plan** (one task, at most one ticket):

```
<plans folder>/<kebab-name>/
├── brief.md    # the input brief, if there is one; read-only once planning starts
├── plan.md     # the plan
└── ...         # other assets: design screenshots, API snapshots, notes
```

**Board** (two or more tickets, one plan each):

```
<plans folder>/<kebab-epic-name>/
├── brief.md
├── board.md                          # order, dependencies and progress of the plans
├── <TICKET-ID>-<kebab-desc>.plan.md  # one plan per ticket
└── ...
```

The formats are in [references/plan-template.md](references/plan-template.md), [references/board-template.md](references/board-template.md) and [references/brief-template.md](references/brief-template.md).

## Input

- A **brief** (`brief.md`, see the template), a **plan folder**, inline text, or nothing.
- **Nothing:** ask for a short kebab-case name and whether the work spans several tickets, create the folder with a copy of the brief template as `brief.md`, tell the user to fill it in and come back with `/create-plan <folder>`, and stop.
- **A plan folder that already has `plan.md` or `.plan.md` files**, or `revise <folder>`: this is a revision. Follow [references/revision-guide.md](references/revision-guide.md) instead of the steps below.
- **`audit <folder>`**, or a request to audit, review or stress-test an existing plan: follow [references/audit-guide.md](references/audit-guide.md) instead of the steps below.
- **An existing plan for the same task**, found while exploring: don't create a duplicate. Point the user at it and ask whether to revise it or start fresh.

## Step 1: Capture the task

Gather these from the user and the brief. When something is missing, propose a reasonable default and let them correct it rather than questioning them round after round.

1. **The task:** 1-3 sentences on what to build, fix or change. Confirm your understanding back.

<!-- CUSTOMIZE: the public contracts this project's changes affect, from its architecture (AGENTS.md, CLAUDE.md, the code layout): HTTP endpoints, events and handlers, use cases, screens and routes, database schemas, CLI commands, public library APIs, test suites. List only the kinds this project has. -->
2. **The contracts involved:** the observable surfaces the change affects. If the user doesn't name them, propose a list:
	- HTTP endpoints (added, changed, removed)
	- Database schemas and migrations
	- Test suites (and the cases inside them)

3. **What must be true when it's done:** the behaviour the work delivers, as rules a test can check: who can do what, what happens on each outcome, which edge cases are refused and how. Draft them from the ticket's acceptance criteria and the spec (step 2) rather than asking the user to write them. Contracts say what the surface looks like; these rules say what it does, and they are what the plan's tests prove.

<!-- CUSTOMIZE: tickets. Which tracker the project uses (GitHub issues, Jira, Linear, none), the ID format, and how to read a ticket with the tools available (an MCP server, `gh issue view`). If tickets have parents (sub-task → story → epic) that hold the acceptance criteria or link the spec, say how to walk up to them. If the project uses no tracker, say so and drop the ticket parts of this skill. -->
4. **The ticket, if any.** Optional: if the user has none, move on. Tickets are GitHub issues (`#123`); read one with `gh issue view <number> --comments`. Record the ID: `execute-plan` uses it for branch names and commit subjects. Two or more tickets make this a board.

## Step 2: Research before drafting

Read what the task will touch; without it the plan is generic and the phases won't match reality.

- The project's `AGENTS.md` / `CLAUDE.md`, and the docs they point to, for architecture and conventions.

<!-- CUSTOMIZE: where specs and designs live (a docs folder, Notion, Figma, Confluence, the ticket itself) and how to read them with the tools available. Only list sources the project actually uses; if a needed tool is unavailable, ask the user to paste the content. -->
- The spec and acceptance criteria: the ticket's description and comments, and any spec or design it links. Check the existing code against the spec: a mismatch there is a decision for the user before the plan is written, not a bug to discover in phase two. Link the sources in the plan's **Context**.

- The code: trace the key files and note their paths for **Context**.

**Verify every symbol you quote against the current code.** Naming a field, method, dependency or literal that doesn't exist is the most common plan defect, and an expensive one, because execution follows the plan literally. Before writing a line into the plan:

- Open the file and copy the real identifier rather than the one you expect.
- Name the exact package each import comes from.
- For a type or contract change, list the whole ripple: every schema, generated file, consumer and wiring point. A plan that changes one schema and stops fails in phase two.
- If the plan claims something is already done or wired, link the code that does it.

Surface gaps before drafting, in one message: no source of truth, vague scope, no acceptance criteria anywhere, or sources that contradict each other. What stays unresolved goes in the plan's **Open questions and risks**.

## Step 3: Propose the phases

Walk the user through the proposed phases before writing anything. Each phase is a **vertical slice**:

- It includes everything needed to ship that slice (schema, logic, test, wiring), not the schema in one phase and its handler in another.
- It's independently committable and pushable: tests pass, the build is green, and the code makes sense on its own.
- It touches about 15 files at most, so review stays manageable. Going over is fine when the files are tightly coupled (one type change rippling through its consumers); say why in the phase description.
- It has a single responsibility: a phase that emits something and also handles it is two phases.
- For feature, behaviour-change and bug-fix phases, it has an **outside-in TDD checklist**: tests ordered from the outermost slice (usually an acceptance test) inward. Each test names the behaviour rules it proves (`B1`, `B2`). Every rule is proved by a test in some phase, or listed as manual with the reason.

On a board, each ticket gets its own plan, with 1-3 phases inside it if the ticket is large. Order the plans by the brief's execution order, or propose one from the dependencies you found.

Present the breakdown and ask for approval. If the user pushes back on a boundary or a contract, iterate in the conversation.

## Step 4: Decide whether the plan deserves a file

A plan file earns its keep when it records decisions worth coming back to: phases someone will carry out across several sessions, contracts that were debated, an ordering that isn't obvious from the code. Otherwise it's bookkeeping that starts going stale the moment work begins.

If most of these hold for the approved breakdown, ask the user before writing:

- One phase, or two that would land in one sitting, each one commit's worth.
- No real contract decisions: nothing new on the public surface, or a shape nobody debated.
- No alternatives weighed.
- No handoff: work starts now, in this session.

Offer two options with the concrete reasons: **execute directly** (keep the phases as a checklist in the conversation and start now, with the same small-commit discipline `execute-plan` uses) or **write the plan anyway** (for a record, a handoff, or later). Recommend executing directly; it's the user's call. Skip this step for plans that are clearly multi-phase or decision-heavy.

## Step 5: Write the plan

Once the user has approved the phases:

1. Create `<plans folder>/<kebab-name>/` if it doesn't exist yet.
2. Copy the brief in as `brief.md` if one was given and isn't there already.
3. Write `plan.md` (single plan), or one `<TICKET-ID>-<kebab-desc>.plan.md` per ticket plus `board.md` (board), from the templates.
4. Save any assets gathered while planning (design screenshots, API snapshots) into the folder.

**Plan mode:** when this runs inside Claude Code's plan mode, the harness only allows edits to its own plan file. Still try to write to the plans folder and let the permission prompt ask the user; only if they reject it, fall back to the harness's plan file.

Tips for good phases:

- Phase titles read like commit subjects: short and imperative.
- To-dos are specific enough for someone else to carry out. Avoid "handle" or "support" without concrete files or behaviour.
- More than about 10 to-dos is probably two phases.
- A behaviour rule that reads like a to-do ("add a 403 check to the route") is implementation; restate it as what a caller observes ("another user's id answers 403").
- Decisions with a reason behind them stay in **Context**; the rules they produce go in **Behaviour**.
- Work left out on purpose goes in **Open questions and risks** as `Deferred`, with why.

## Step 6: Hand off

1. Show the user the path you wrote.
2. **Offer an audit:** a pass over the plan that checks its scope, ordering, names, edge cases and tests against the code, before anyone executes it. Recommend it for multi-phase plans and boards. If the user accepts, follow [references/audit-guide.md](references/audit-guide.md), then come back here.
3. **Don't start executing.** Suggest `/execute-plan <plan folder>` when they're ready, ideally in a fresh session or after compacting the context.

## Edge cases

- **A one-liner** (a typo, a trivial rename): say a plan is overkill and suggest just making the change, without steps 1-3.
- **Several valid approaches:** present them briefly and ask the user to pick before drafting phases.
- **The user wants the file immediately**, without discussing contracts or phases: explain once why the conversation matters. If they still want to skip it, draft with your best guess and list the assumptions at the top of the plan.
