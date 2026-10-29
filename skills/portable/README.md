# Portable

Skills that work as they are, in any project.

- **[adapt-skill](./adapt-skill/SKILL.md)**: Adapt a skill template copied into a project by filling in its `CUSTOMIZE` markers.
- **[ocr-review](./ocr-review/SKILL.md)**: Review a pull request with Open Code Review in a fresh subagent and post the findings as a GitHub review, with an optional hook that runs it after `gh pr create` and `git push`. Needs Node.js 22.18+ and `gh`.
- **[setup-ocr](./setup-ocr/SKILL.md)**: Configure a repo for `ocr-review`: draft `.opencodereview/background.md` and `rule.json`, and offer the review docs the reviewer reads. Run once per repo.
