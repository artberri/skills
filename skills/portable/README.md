# Portable

Skills that work as they are, in any project.

- **[address-pr-comments](./address-pr-comments/SKILL.md)**: Work through a PR's open review comments: evaluate each one, apply the agreed fixes, commit and push, reply on disagreements and resolve the threads. With `--local`, works through the findings of a local OCR review and commits without pushing. Needs Node.js 18+ and, for PRs, `gh`.
- **[adapt-skill](./adapt-skill/SKILL.md)**: Install a skill template into a project, or refresh one already there, filling in its `CUSTOMIZE` markers from the project. Run it again when the project or the template changes.
- **[adversarial-review](./adversarial-review/SKILL.md)**: Review local changes before shipping with fresh-context reviewers who know only the desired outcomes: one reviewer, or a council focused on different areas with findings ranked by consensus.
- **[capture-learnings](./capture-learnings/SKILL.md)**: Review the conversation for corrections, gotchas, patterns and missed skills, check them against the project's docs, and write the approved ones where the next agent will find them.
- **[commit](./commit/SKILL.md)**: Commit the current changes as small, focused, signed commits, with messages in the repo's style that explain why. Splits files across commits when needed, and never pushes.
- **[ocr-review](./ocr-review/SKILL.md)**: Review a pull request with Open Code Review in a fresh subagent and post the findings as a GitHub review, with an optional hook that runs it after `gh pr create` and `git push`. With `--local`, reviews unpushed commits and keeps the findings on the machine instead. Needs Node.js 22.18+ and, for PRs, `gh`.
- **[research](./research/SKILL.md)**: Research the feasibility, integration cost and risks of adopting a library, tool or architectural change, from docs, GitHub issues, the codebase and the web, and save a structured report.
- **[retro](./retro/SKILL.md)**: Retrospective over the last day or week of Claude Code sessions in a project: what went well, what went wrong, ways of working on both sides, and 3-5 concrete proposals (new skills, docs, rules, workflow changes). Needs Python 3.9+.
- **[setup-ocr](./setup-ocr/SKILL.md)**: Configure a repo for `ocr-review`: draft `.opencodereview/background.md` and `rule.json`, pointing the reviewer at the project's review docs. Run once per repo, and again to refresh it.
- **[setup-review-docs](./setup-review-docs/SKILL.md)**: Create or refresh a repo's review docs (known non-issues, pre-PR checklist, footguns) from merged PR reviews and its conventions. Safe to rerun: it improves the docs without rewriting or duplicating them.
