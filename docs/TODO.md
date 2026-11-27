# To do

Work left for later, and things to come back to. Remove an item in the commit that finishes it.

## Add evals to the remaining skills, then make check.sh fail without them

These have no `evals/evals.json` yet: `address-pr-comments`, `ocr-review`, `execute-plan`, `write-acceptance-criteria`, `research`, `retro`, `setup-ocr` and `setup-review-docs`.

Once each has one, or is exempted explicitly (the user-invoked setup skills are the likeliest), turn the missing-evals warning in `scripts/check.sh` into a failure.

## Notice when the agents' docs change

Codex dropped plugin hooks, and we found out only by trying it in `try-in-agent`. Keep a list of the doc pages this repo depends on, for Claude Code, Codex and Copilot CLI (skills, plugins, hooks, subagents), and a script that fetches them into a gitignored folder and records a hash of each, so a refresh shows which pages changed since last time. Commit only the list and the hashes: copying other people's docs into a public repo isn't ours to do. [eferro/skill-factory](https://github.com/eferro/skill-factory) keeps its copies of Anthropic's docs fresh the same way.

## Add the skills.sh badge to the README

`[![skills.sh](https://skills.sh/b/artberri/skills)](https://skills.sh/artberri/skills)` under the title shows the install count. Right after the first install it said "resource not found", though the repo's page was up, so it came out. Put it back once `https://skills.sh/b/artberri/skills` shows a count.

## Settle when adversarial-review confirms the outcomes

In its evals, every council run, both before and after the diagnosis and scope areas, reviewed in its first reply when the prompt already gave the outcomes and the mode. Step 2 says to confirm outcomes found in the conversation. Either say that outcomes the user has just typed count as confirmed, or make the stop firmer. Then fix the evals' follow-ups, which now arrive after the verdict.

## Test what adversarial-review's diagnosis area finds

Its eval shows the area being picked for a bug fix, not that it finds more: the old areas also found the missing `await`, because the cause sits in the same file as the fix. A fixture with the cause in another module would test it.
