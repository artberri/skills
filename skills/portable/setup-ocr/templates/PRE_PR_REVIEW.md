# Pre-PR review

Check your own diff against this list before opening a pull request. Every item is a mistake review has caught in this repo more than once: catching it here costs a minute, in review a round trip, in production an incident.

It doesn't replace the formatters, linters, type checks and tests. Run those first; this is the correctness pass on top.

**How to use it:** read your diff, then work through "Always" plus the sections matching what you touched. When a check turns up something deliberate, it probably belongs in [KNOWN_NON_ISSUES.md](./KNOWN_NON_ISSUES.md).

## Always

- **The diff contains only this change.** No drive-by reformatting, unrelated files or reordered imports in files you didn't otherwise edit.
- **Every consumer of what you changed is updated in the same PR.** Interfaces, config keys, exports, payloads, and the ones the compiler won't catch: test mocks, fixtures and fakes.
- **Docs that describe what you changed are updated in the same PR.** After a rename, search the Markdown files too.
- **<The rule, stated as what a good diff does.>** <How to check it, and what went wrong when it was missed.>

## <When the diff touches an area, such as "the database" or "HTTP contracts">

- **<Rule.>** <How to check it.>
