# Portable

Skills that work as they are, in any project.

- **[address-pr-comments](./address-pr-comments/SKILL.md)**: Work through a PR's open review comments: evaluate each one, apply the agreed fixes, commit and push, reply on disagreements and resolve the threads. Needs Node.js 18+ and `gh`.
- **[adapt-skill](./adapt-skill/SKILL.md)**: Install a skill template into a project, or refresh one already there, filling in its `CUSTOMIZE` markers from the project. Run it again when the project or the template changes.
- **[commit](./commit/SKILL.md)**: Commit the current changes as small, focused, signed commits, with messages in the repo's style that explain why. Splits files across commits when needed, and never pushes.
- **[ocr-review](./ocr-review/SKILL.md)**: Review a pull request with Open Code Review in a fresh subagent and post the findings as a GitHub review, with an optional hook that runs it after `gh pr create` and `git push`. Needs Node.js 22.18+ and `gh`.
- **[setup-ocr](./setup-ocr/SKILL.md)**: Configure a repo for `ocr-review`: draft `.opencodereview/background.md` and `rule.json`, and offer the review docs the reviewer reads. Run once per repo.
