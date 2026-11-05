# Contributing to Made-to-Measure Skills

Help is welcome and much appreciated, whether you are an experienced developer or about to send your first pull request. Have a look at the [open issues](https://github.com/artberri/skills/issues), and please follow the [code of conduct](CODE_OF_CONDUCT.md).

This repo holds agent skills for Claude Code, Codex and GitHub Copilot CLI. The portable skills, and the agents they use, ship as the `artberri-skills` plugin; templates are installed into a project and adapted to it. This file covers how to set the repo up, try a change in each agent, and send it.

For anything bigger than a small fix, a new skill included, open an issue first and say what you'd like to change, so we can agree on the shape before you spend time on it.

## Setting up

You need **git**, **jq**, **ShellCheck** and **shfmt** for the checks, and **Python 3.9+** for the tests of `retro`'s session reader. **Claude Code** runs the evals and validates the plugin's manifest, and **Node.js** gives you `npx`, which runs Codex and Copilot CLI without installing them.

Fork the repository, and clone your fork:

```sh
git clone https://github.com/YOUR_USERNAME/skills.git
cd skills
```

There is nothing to install or build: the skills are Markdown and shell scripts, and the agents load them as they are.

## Trying a change

### In Claude Code

Load the plugin from your clone. Either for one session:

```sh
claude --plugin-dir /path/to/skills
```

or for every session, by adding the folder to `CLAUDE_CODE_PLUGIN_DIRS` in your `~/.claude/settings.json` (several folders are separated by `:`):

```json
{
	"env": {
		"CLAUDE_CODE_PLUGIN_DIRS": "/path/to/skills"
	}
}
```

Edits take effect in the next session. If you also installed the published plugin, disable it while you work (`claude plugin disable artberri-skills@artberri`), so the session runs your copy.

### In Codex and Copilot CLI

Both install plugins from a marketplace, and a copy of your clone is one: its `.claude-plugin/marketplace.json` lists the plugin at the root. In Claude Code, the repo's own `try-in-agent` skill installs your working tree in a throwaway config and runs the test: ask it "does this work in Copilot?". To do it by hand, [its notes](.claude/skills/try-in-agent/references/agents.md) have each agent's commands, where it keeps its files, and what we've found so far. Point `HOME` at a throwaway folder first, as [its script](.claude/skills/try-in-agent/scripts/sandbox.sh) does, so your own config isn't touched.

### A template

In a test project, with the plugin loaded from your clone, run `/adapt-skill <skill>`: it reads the templates next to itself, so it adapts your copy. Without an agent that runs it, `scripts/add-template.sh <skill> path/to/project` copies the template as it is.

## Where things are

- `skills/portable/`: skills that work as they are, in any project. The plugin ships them.
- `skills/templates/`: skills with `CUSTOMIZE` markers on the parts that differ between projects, which `adapt-skill` fills in.
- `skills/drafts/`: work in progress, never installed.
- `agents/`: the subagents that skills start, in the same three buckets.
- `hooks/`: hooks that apply whichever skill runs, off until a user turns them on.
- `.claude/skills/`: skills for working on this repo, which the plugin never ships.
- `scripts/`: the checks, the eval runner and `add-template.sh`.

[AGENTS.md](AGENTS.md) has the full layout and the rules for writing and changing skills, agents and hooks. It's also what an AI agent working in the repo reads first (`CLAUDE.md` links to it), so a rule written there reaches both of you.

## Writing or changing a skill

- Not sure whether a skill is portable or a template? Ask whether it would be wrong in some project if nobody edited it. If so, it's a template.
- Use Anthropic's skill-creator plugin when you create a skill or rework one: its eval loop and description tuning are the point.
- Every installed skill's `description` is loaded into every session, so make it as long as it needs to be and no longer. AGENTS.md has a checklist to read it against.
- List the skill in its bucket's `README.md` and, unless it's a draft, in the Skills section of the top-level README.
- Bump a template's `metadata.template-revision` whenever you change it, so `adapt-skill` offers projects a refresh.

`scripts/check.sh` catches most of what these rules can check.

## Checks

Run these before you send a change. CI runs the same:

```sh
scripts/check.sh
git ls-files -z "*.sh" "scripts/evals/stubs/*" | xargs -0 shellcheck -x
shfmt -d .
hooks/git-guardrails/test.sh
scripts/test-add-template.sh
python3 -I skills/portable/retro/scripts/test_extract_sessions.py
```

After changing anything in `.claude-plugin/`, also run `claude plugin validate .`. Warnings about the bucket `README.md` files lacking frontmatter are expected.

## Evals

Every portable skill and template should have evals in `evals/evals.json`: test cases with a starting repository, the user's prompt and the expectations to grade. Run them with:

```sh
scripts/evals/run.sh <skill> [eval-id...]
scripts/evals/run.sh <skill> --triggers
```

Each eval runs Claude Code in a throwaway repository with a temporary config folder, so it can't see your usual login: set `CLAUDE_CODE_OAUTH_TOKEN` (create one with `claude setup-token`) or `ANTHROPIC_API_KEY`. Runs cost model usage, so CI only validates the files; say in your pull request which evals you ran and how they did. Results go in `<skill>-workspace/`, which git ignores; delete it when you are done. The Evals section of AGENTS.md has the format.

## Code style

- Tabs for indentation, JSON included. Only YAML uses spaces.
- Shell scripts: Bash that runs on macOS's `/bin/bash` 3.2 and on Linux (mind the BSD and GNU differences in `sed -i`, `date`, `stat`...), with `set -euo pipefail` and quoted variables, clean under ShellCheck and shfmt.
- Skills run in more agents than Claude Code: write a skill's own folder as `<skill-dir>`, not `${CLAUDE_SKILL_DIR}`, and keep its frontmatter strict YAML.
- Comments explain why, not what, in full sentences.

## Commits and pull requests

- Small commits, one topic each, with [Conventional Commits](https://www.conventionalcommits.org) subjects: `feat: …`, `fix: …`, `docs: …`. The body says why.
- A pull request says what changed, why, and how you checked it: the evals you ran, and the agents you tried it in.
- Keep the checks green in every commit.
- Never commit secrets, tokens, local paths or anything personal; check the diff before you push.

## Versions

There are no release tags: installs follow `main`. Claude Code, Codex and Copilot CLI update an install only when the `version` in [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) changes, so bump it in the same pull request as any change to what the plugin ships: the manifest, portable skills and agents, and `hooks/` (evals and docs don't count). Bump the patch for fixes and wording, the minor for a new skill or behaviour, and the major when something users rely on goes away. `scripts/check.sh` fails if you forget; it compares with `origin/main` through `git diff`, which skips untracked files, so run `git add -N` on new files first.

Templates aren't in the plugin: their `template-revision` is what tells a project there's something new.

## License

The skills are under the [MIT license](LICENSE); by contributing you agree your work is licensed the same way. The README's [credits](README.md#credits) name the projects they learned from.
