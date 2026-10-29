<!-- Board: ./board.md (only when this plan is part of a board; drop this line otherwise) -->

# Plan: <Title>

**Ticket:** <ID and link, or drop this line>

## Goal

<1-3 sentences: what this plan delivers and why.>

## Behaviour

<What the system does once the plan is done, one observable rule per line. No file names, no phases: a rule survives a change of implementation. `execute-plan` fills in each rule's proving test as it goes.>

- **B1.** <e.g. "A user lists only their own orders; another user's id answers 403."> — _proved by:_
- **B2.** ...

## Context

### Sources

<Links to the ticket, spec and designs, with one line on what each holds.>

### Key files

| Area | Files |
| ---- | ----- |
| ...  | [path/to/file](path/to/file) |

### Contracts

<Only the kinds that apply: endpoints, events, schemas, screens, test suites…>

- **<Kind>:** ...

### Dependencies

<Only if there are any: other PRs, plans or work that must land first, and which phase each blocks.>

## Open questions and risks

<Unresolved items from planning. `execute-plan` checks the `Open` ones that affect a phase before starting it. Drop the section if there are none.>

| # | Question or risk | Source | Affects | Status |
| - | ---------------- | ------ | ------- | ------ |
| 1 | ... | ... | Phase 2 | Open |

<!-- Status: Open, Resolved or Deferred (left out on purpose, with why). -->

## Phase 1: <Short imperative title>

> Skills: <skills to load before this phase, or drop this line>
> Ticket: <ID, when phases map to different tickets, or drop this line>
> Design: <link to the design for this phase, or drop this line>

**Description:** <1-2 sentences on what this phase delivers, and why it comes now.>

**Outside-in TDD checklist** (drop for pure refactors and docs-only phases):

- [ ] Acceptance test (B1, B2): ...
- [ ] Integration test (B3): ...
- [ ] Unit test: ...

**To-do:**

- [ ] <Concrete action, e.g. "Add column X to table Y">
- [ ] <Next action>

**Verify:**

- [ ] The project's checks pass for what this phase touched (see `execute-plan`).
- [ ] <Acceptance criterion this phase delivers>

## Phase 2: <Short imperative title>

...

## Next step

Phase 1: <one sentence on what to do next>. Run `/execute-plan <plan folder>`.
