---
name: write-acceptance-criteria
description: >-
  Write acceptance criteria for a feature by cross-referencing its tickets, specs, designs, team discussions and the
  codebase, flag conflicts and gaps between them, and write the agreed criteria back to the tickets. Also revises
  existing criteria. Use whenever the user wants acceptance criteria written, drafted, reviewed or updated:
  `/write-acceptance-criteria <ticket>`, "write the AC for this epic", "draft acceptance criteria", "what should the AC
  be", "update the AC", "the AC needs changing". For turning criteria into an implementation plan, use `create-plan`.
argument-hint: "[ticket | update <ticket>]"
metadata:
  template-revision: "1"
---

# Write acceptance criteria

Turns what a team has said about a feature, across its tickets, specs, designs and discussions, into acceptance criteria a developer can build against and a test can check. The value is in the cross-referencing: the sources rarely agree, and the conflicts and gaps are what the team needs to settle before anyone builds.

**Nothing is written to a ticket until the user has approved the draft.**

## Modes

| Invocation | Mode |
| ---------- | ---- |
| `/write-acceptance-criteria <ticket>` | **Fresh:** write criteria for a feature from scratch. |
| `/write-acceptance-criteria update <ticket>` | **Revision:** read the existing criteria, apply a change, and show a diff before writing. Follow [references/revision-guide.md](references/revision-guide.md) instead of the steps below. |

If the user asks to update or change existing criteria, or a ticket already has criteria, use revision mode.

## Product context

<!-- CUSTOMIZE: what the product is, in a sentence, and the kinds of user or account a feature can target (roles, plans or tiers, account states, platforms), with the scope rule for each: when a feature targets only one kind, the others are out of scope and get no scenarios or gap flags. From the README, AGENTS.md, the code that gates access (role checks, entitlement or plan checks), and the specs. -->
The product is a web app for teams. Features can target:

- **Roles:** admins and members. A feature for admins only has no member scenarios.
- **Plans:** Free and Pro. A feature for Pro only has no Free scenarios, apart from the upgrade prompt if the spec shows one.

## Step 1: Gather the inputs

Ask for what's missing in one message, and don't ask again for anything the user already gave:

<!-- CUSTOMIZE: the inputs to ask for, matching the sources below: the ticket ID format and level (an epic, a story, an issue), where discussions happen (a channel, a thread), and which links the user may have (a spec, a design file). Say which are optional and where each can be found without asking (a link in the ticket, a channel topic). -->
1. **The ticket:** the GitHub issue for the feature (`#123`), usually the parent issue whose sub-issues are the work items.
2. **The discussion:** the Slack channel or thread where the feature was discussed. Optional.
3. **The spec:** a link or path to the feature's spec. Look for it in the issue first; ask only if it isn't there.
4. **The design:** a Figma link. Optional; look for it in the issue and the spec first.

## Step 2: Check the tools

For each source the inputs need, check that its tool is available in this session: the MCP tool or CLI named below. Teammates may have the same MCP server under a different name, so if the named tool is missing, look for one that does the same job before falling back.

When a source's tool is unavailable, say so and use its fallback: ask the user to paste the content, or to share screenshots. Never skip a source silently; if the user chooses to go without it, note that in the draft.

## Step 3: Read the sources

Read them in parallel. For each, note what it says about the feature's behaviour, and where.

<!-- CUSTOMIZE: the ticket tracker and how to read it: the tool (an MCP server's tools, a CLI such as `gh`, `glab`, `jira` or `linear`) with the exact calls, how to list a ticket's children, which ticket types or labels hold user-facing work (these become the criteria groups) and which are left out of the groups (backend-only, chores), and where existing criteria live in a ticket (a heading, a field). Fallback: the user pastes the tickets. -->
### Tickets

- Read the issue with `gh issue view <number> --comments`, and list its sub-issues with `gh api repos/{owner}/{repo}/issues/<number>/sub_issues`.
- For each sub-issue, note its title, description, labels, and any existing `## Acceptance criteria` section. If one already has criteria, say so and offer revision mode before going on: a fresh run rewrites what someone may have edited by hand.
- Issues labelled `backend` or `chore` stay in the cross-reference table but get no criteria group.
- Fallback: ask the user to paste the issue and its sub-issues.

<!-- CUSTOMIZE: where the product definitions live (specs, one-pagers, PRDs, RFCs: a docs folder, Notion, Confluence, Google Docs, the ticket itself), how to find the one for a feature (linked from the ticket, a channel topic, a naming pattern) and how to read it (an MCP tool, the Read tool). Fallback: the user pastes it. -->
### Specs

- Specs live in `docs/specs/`, one file per feature, usually linked from the issue. Read them with the Read tool.
- Extract the requirements, success criteria, scope statements and the user kinds the feature targets.
- Fallback: ask the user to paste the spec.

<!-- CUSTOMIZE: where designs live (Figma, Penpot, Sketch, screenshots in the ticket) and how to read them: the MCP tools and how to get the IDs they need from a link. Fallback: the user shares screenshots. Delete this section if the project has no designs. -->
### Designs

- Designs are in Figma. Parse the file key and node ID from the link, then read it with the Figma MCP server's design-context and screenshot tools.
- Extract the screens, the labels on actions, each screen's states (empty, loading, error, populated) and what changes after an action.
- Fallback: ask the user for screenshots. If a design link was shared but can't be read, ask for screenshots before going on rather than skipping it.

<!-- CUSTOMIZE: where the team discusses features (Slack, Microsoft Teams, Discord, GitHub Discussions, ticket comments) and how to read it: the MCP tools to find a channel or thread and read its messages. Fallback: the user pastes the relevant excerpts. Delete this section if discussions all happen in ticket comments. -->
### Discussions

- Find the channel with the Slack MCP server's channel search, then read its messages. Note the channel topic: it often links the spec.
- Look for decisions, scope changes, edge cases raised and behaviour the team agreed on, with their dates.
- Fallback: ask the user to paste the relevant messages.

### The code

A light, read-only check of what exists:

- Whether some of the feature already exists. Use `AGENTS.md` / `CLAUDE.md` to find where features live before searching.
- What gates access (role, plan or account checks): it tells you which user kinds the criteria must cover.
- The project's glossary or domain docs, if it has them, to map the sources' terms to the code's.

## Step 4: Cross-reference and flag

Before drafting, build a cross-reference table, one row per requirement, one column per source you read:

| Requirement | Tickets | Spec | Design | Discussion | Conflict or gap |
| ----------- | ------- | ---- | ------ | ---------- | --------------- |
| Saving shows a confirmation | ✓ | ✓ | ✓ | — | — |
| Empty-state copy | — | ✓ | ✓ | ✓ | Not in the tickets |

Then flag:

- **Conflicts:** sources that say different things about the same behaviour. State both and ask which wins.
- **Gaps:** behaviour implied but never specified. Propose the question to ask the product owner.
- **Ambiguous tickets:** a description that's unclear. Propose a clarifying question.
- **Edge cases:** raised in discussions, shown in design states, or that follow from the domain.

Apply the scope rules from **Product context**: user kinds a feature doesn't target get no scenarios and no gap flags.

## Step 5: Draft the criteria

Group the criteria by the tickets that hold user-facing work (step 3). If there are none yet, group them by functional area.

<!-- CUSTOMIZE: the format the team writes criteria in: the heading, Given/When/Then or plain checklist items, and any summary sentence for the parent ticket. Copy it from tickets that already have good criteria. -->
Each group is a checklist under an `## Acceptance criteria` heading:

```
- [ ] Given <context>, when <action>, then <outcome>.
- [ ] The <component> shows <state> when <condition>.
- [ ] Selecting <action> takes the user to <destination>.
```

The parent ticket gets a short summary in sentences: "When a user does X, they see Y. If Z, they see W instead."

<!-- CUSTOMIZE: what every group should consider, from the kind of product this is: for a UI, its states (loading, empty, error, after an action), action labels and when actions are disabled, and navigation; for an API, status codes, validation errors, idempotency and pagination; for any product, the user kinds in scope, permissions, and existing data. -->
For each screen or functional area, cover:

- The happy path.
- Loading, empty and error states.
- What changes after the action succeeds.
- Each action: its label, when it's disabled, where it leads.
- The user kinds in scope (see **Product context**).
- The edge cases flagged in step 4.

Each criterion states something a user or a test can observe, not how it's built.

## Step 6: Get approval

Present the open conflicts and gaps first, then the full draft, grouped. Say plainly that nothing will be written until the user approves. Revise and present again until they do.

## Step 7: Write the criteria back

<!-- CUSTOMIZE: where approved criteria go and how: back to each ticket with the tracker's tool (which call, which field or heading, how the description's format is handled), to a file (a brief for create-plan, a docs page), or only shown in the conversation. -->
Once the user approves, for each ticket with a criteria group:

1. Read its current description, and keep everything outside the criteria section as it is.
2. If it already has an `## Acceptance criteria` section, replace that section in place; otherwise append one. Two criteria sections in one ticket end up contradicting each other.
3. Write it back with `gh issue edit <number> --body-file <file>`.

Criteria for the feature as a whole, with no ticket to hold them, go in the parent issue. Then list what was written:

```
Criteria written to:
- #124 Results screen ✓
- #125 Empty state ✓
```

If `create-plan` is available, suggest it as the next step: the criteria become the plan's behaviour rules.

## Rules

- Read-only on the codebase: never write code or change project files.
- Never write to a ticket before the user approves the draft or the diff.
- Keep a ticket's existing description; change only its criteria section.
