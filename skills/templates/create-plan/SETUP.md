# Setting up create-plan

Guidance for `adapt-skill` when it installs or refreshes the `create-plan` template. It is not copied into the project.

## What to look for

- **An installed `execute-plan`:** if `.claude/skills/execute-plan/` exists, reuse its plans folder and ticket conventions, so the two skills agree.
- **Plans folder:** an existing one (`.agents/plans/`, `.ai/plans/`, `docs/plans/`, `plans/`), or one named in `AGENTS.md` / `CLAUDE.md`.
- **Tickets:** the tracker the project uses, from branch names, PR titles and commit subjects (`ABC-123`, `#123`), links in docs, and the MCP tools available (a Jira, Linear or GitHub server). How tickets nest (sub-task, story, epic) and which level holds the acceptance criteria and the spec link.
- **Specs and designs:** where they live (a docs folder, Notion, Figma, Confluence, the ticket itself), and which tools are available to read them.
- **Contracts:** the kinds of public surface this project has, from its architecture docs and code layout: HTTP routes, events and handlers, use cases, screens and routes, schemas and migrations, CLI commands, a library's public API.

## Questions, in this order

**A. Plans folder.** Recommend the existing one if there is one; otherwise ask, recommending `.agents/plans/`. Skip it if `execute-plan` already set one.

**B. Tickets.** Propose the tracker, ID format and how to read a ticket that you found, or "no tracker". Confirm how to walk up to the acceptance criteria if tickets nest.

**C. Specs and designs.** Propose where they live and how to read them.

**D. Contracts.** Propose the list of contract kinds for this project.

**E. Edge cases for the audit.** Propose the edge cases and states the audit should check (`references/audit-guide.md`, pass 4), from what you found about the project: UI states, offline, roles and entitlements, platforms, localisation, retries and idempotency, existing data, API or event compatibility. Keep only the ones that apply.
