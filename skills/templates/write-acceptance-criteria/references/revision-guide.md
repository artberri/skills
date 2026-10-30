# Revising acceptance criteria

Loaded by `write-acceptance-criteria` in revision mode: `update <ticket>`, a request to change existing criteria, or a ticket found to have criteria already. Use the tools, sources and format from `SKILL.md`.

## Step R1: Find out what changed

Ask in one message, unless the user already said:

1. **What changed:** new, removed or amended behaviour, in plain words, or a link to where the change lives (a message, an updated spec, a new design).
2. **Which tickets it affects,** if they know. If not, work it out from the parent ticket.

## Step R2: Read the current criteria

Read the parent ticket and its children with the tracker's tool, and extract each one's current criteria section.

## Step R3: Read the change

If the user pointed at a source, read it with that source's tool and extract only the delta: what is new, what is gone, and what contradicts the current criteria. Flag any conflict with the other sources, as in step 4 of `SKILL.md`.

## Step R4: Show a diff

Show the changes per ticket:

```
#124 Results screen

  ADD:
  - [ ] Given the user already exported today, the Export action is disabled with "Exported" as its label.

  REMOVE:
  - [ ] The export limit resets at midnight in the user's time zone.

  UNCHANGED: 6 criteria
```

Show only the tickets that change, then list the unchanged ones by name, so the user sees the scope at a glance.

## Step R5: Get approval

Don't write anything until the user approves the diff. Revise and show it again if they ask for changes.

## Step R6: Write the updates

For each affected ticket, write it back the way step 7 of `SKILL.md` does: keep the description outside the criteria section, and replace only that section. Then list what changed:

```
Criteria updated in:
- #124 Results screen: 1 added, 1 removed ✓
```
