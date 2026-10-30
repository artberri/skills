# Setting up write-acceptance-criteria

Guidance for `adapt-skill` when it installs or refreshes the `write-acceptance-criteria` template. It is not copied into the project.

The skill is only as good as its access to the sources. For each kind of source, find out where the project keeps it and how this session can read it, and settle a fallback for when the tool isn't there.

## Checking tools

For every source the user names, check how it can be read, in this order:

1. **An MCP server:** look through the tools this session lists (`mcp__<server>__<tool>`) for one that serves the source: Jira, Linear, GitHub, Notion, Confluence, Google Drive, Figma, Slack, Teams. Note the exact tool names the skill will call, and check each with a harmless read (fetch a ticket or page the user names) before writing them in.
2. **A CLI:** `gh`, `glab`, `jira`, `linear` and similar, with `command -v` and an authenticated read (`gh auth status`, `gh issue view <n>`).
3. **Files in the repo:** a docs folder read with the Read tool.

If none works, tell the user what would make it available (connecting the MCP server, installing and logging into the CLI), and ask whether to write the skill for that tool anyway, with the paste or screenshot fallback for when it's missing. MCP server names differ between teammates, so the skill describes each tool by what it does as well as by name.

## What to look for

- **An installed `create-plan`:** if `.claude/skills/create-plan/` exists, reuse its ticket and spec answers, so the two skills read the same sources the same way.
- **Product and user kinds:** the README, `AGENTS.md` / `CLAUDE.md`, and the code that gates access (role, permission, plan or entitlement checks) for the kinds of user a feature can target.
- **Tickets:** the tracker, from branch names, PR titles and commit subjects (`ABC-123`, `#123`), links in docs, and the MCP tools available. How tickets nest (sub-task, story, epic), which level a feature starts from, and which types or labels mark user-facing work.
- **Existing criteria:** a few tickets that already have acceptance criteria, for the heading and format the team uses.
- **Definitions:** specs, one-pagers, PRDs or RFCs: a docs folder, or links in tickets and docs to Notion, Confluence or Google Docs.
- **Designs:** links to Figma or another design tool in tickets, specs and docs.
- **Discussions:** links to Slack, Teams or Discord in docs and tickets, and whether a ticket or channel usually points at the others (a channel topic linking the spec).

## Questions, in this order

Ask one at a time, each led by your recommendation and the tool you checked.

**A. Product context.** Propose a one-line description of the product and the user kinds a feature can target, with the scope rule for each.

**B. Tickets and project management.** Always ask. Propose the tracker, the ID format, the level a feature starts from, how to list its children, which tickets get criteria groups, and the tool to read them with (and whether it worked). Also ask whether the project uses no tracker at all; then criteria are only shown in the conversation or written to a file.

**C. Definitions.** Always ask where specs, one-pagers or PRDs live and how to find the one for a feature. Propose what you found and the tool to read them with.

**D. Designs.** Always ask whether the project has designs and where. Propose the tool, or the screenshot fallback; drop the section if there are none.

**E. Discussions.** Always ask where the team discusses features. Propose the tool, or drop the section if discussions live in ticket comments.

**F. Writing back.** Ask where approved criteria go: back to the tickets (with the tool from B, and whether it can write as well as read), to a file, or only into the conversation. Propose the format and heading from existing tickets.

**G. Coverage.** Propose the checklist each criteria group should consider, from the kind of product (UI states, API errors, permissions, existing data).
