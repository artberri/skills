# Auditing a plan

Loaded by `create-plan` when the user accepts the audit offered in step 6, or runs `audit <folder>`. The audit probes a written plan for gaps, wrong assumptions and hidden risks before execution starts, so `execute-plan` can follow it literally.

## What to audit

- **A folder with `board.md`:** every `.plan.md` in it, in the board's order, plus a cross-plan pass at the end.
- **A folder with `plan.md`:** that plan.
- **A path to one `.plan.md`:** only that plan.
- **Nothing:** the plan just written in this conversation; otherwise list the plan folders (not `done/`) and ask.

Phases whose title ends with ✅ are already done: read them for context, but don't audit or change them.

## How it works

Walk through the plan in the passes below, one dimension at a time. Within a pass, settle the decisions others depend on first.

**Answer from the code before asking.** If opening a file, searching for a symbol or reading a spec settles a question, do that and report what you found. Ask the user only for what needs their judgement or knowledge the project doesn't hold.

### Pass 1: Scope

- Does the plan cover what the sources (brief, ticket, spec, designs) ask for, and nothing they don't?
- Is every requirement in the sources captured as a **Behaviour** rule, and is each rule something a caller can observe rather than an implementation step?
- If the plan changes shared code, what else uses it, and does the plan account for that?
- Is any phase too big (well over ~15 files or ~10 to-dos), doing two things, or too small to stand on its own?

### Pass 2: Dependencies and ordering

- Does any phase rely on work from a later phase?
- Is each phase a true vertical slice: committable on its own, with tests passing and the build green?
- Are there outside dependencies (another team's API, a migration, design assets, a release) that could block a phase? Are they in **Dependencies**?
- Within a phase, are the to-dos in an order that works?

### Pass 3: Feasibility against the code

- Open the files, symbols, packages and contracts the plan names: do they exist, with those exact names? A wrong identifier is the most common plan defect.
- Does each type or contract change list its whole ripple: schemas, generated files, consumers, wiring?
- Does the plan follow the patterns the code already uses for the same kind of thing, and the conventions in `AGENTS.md` / `CLAUDE.md`?
- Anything costly at run time the plan ignores: large data sets, N+1 queries, heavy renders, bundle size?

### Pass 4: Edge cases and states

<!-- CUSTOMIZE: the edge cases and states that matter in this project, from its architecture and domain: UI states (loading, empty, error), offline behaviour, permissions and roles, plans or entitlements, platform differences, localisation, concurrency and retries, idempotency, migrations on existing data, backwards compatibility of APIs or events. List only the ones that apply. -->
- Failure paths: what each new or changed operation does on invalid input, a missing record, a permission denied, or a dependency that's down.
- Existing data: does a schema or format change work for records that already exist?
- Compatibility: can callers of a changed API, event or CLI keep working during the rollout?

### Pass 5: Tests

- Is every **Behaviour** rule proved by a test in some phase, or listed as manual with a reason?
- Does each TDD checklist run outside in, starting from the outermost test the change needs?
- Do the tests named exist where the project keeps that kind of test?

### Pass 6: Open questions and risks

- Can any `Open` item be answered now, from the code or the sources?
- Are there risks the plan doesn't list?
- Is anything marked `Resolved` that isn't, or `Deferred` without a reason?

### Board: cross-plan pass

- Do the board's order and dependencies match what each plan actually needs from the others?
- Do plans that share types, contracts or files agree on their names and shapes?

## How to interact

Present the findings one pass at a time, numbered and grouped, and classify each one:

- **Question:** needs the user's decision.
- **Suggestion:** a concrete change you propose, which the user accepts or rejects.
- **FYI:** something you checked that is fine, but worth knowing.

```
**Pass 2: Dependencies and ordering**
1. Question: Phase 2 calls `GET /orders/{id}/items`, which doesn't exist yet and isn't in any phase. Is another team shipping it, or should Phase 2 add it?
2. Suggestion: Phase 3's migration is needed by Phase 2's tests. Move it to the start of Phase 2.
3. FYI: Phase 1 changes `formatTotal`, which `InvoiceView` also uses. The change is backwards compatible.
```

Skip a pass that finds nothing, saying so in one line. After each pass, wait for the user's answers before moving to the next.

## After the audit

1. **Summarise** the changes agreed during the audit.
2. **Show the diff** to the plan files and wait for approval. Follow the rules in [revision-guide.md](revision-guide.md): completed phases stay locked and phase numbers stay as they are. Settled questions become `Resolved`; new ones go in **Open questions and risks**.
3. **Save** the plan files, then go back to step 6 of `create-plan` to hand off.
