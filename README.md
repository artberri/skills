# Skills

The agent skills I use often enough to want them in every project.

There are two kinds:

- **[Portable](./skills/portable/README.md)**: work as they are, in any project. You install them once and use them everywhere.
- **[Templates](./skills/templates/README.md)**: assume things only a project knows (its test command, its commit style, where its docs live). You copy one into a project and adapt it there, and the project owns that copy.

[Drafts](./skills/drafts/README.md) are skills in progress. They never get installed.

Some skills hand work to **agents** (subagents with their own prompt, tools and model). Agents are split the same way: [portable](./agents/portable/README.md), [templates](./agents/templates/README.md) and [drafts](./agents/drafts/README.md). A skill lists the agents it uses, and adding a template brings in its template agents too.

## Using a template in a project

From inside the project, with the plugin or the `adapt-skill` skill installed, run [`/adapt-skill <skill>`](./skills/portable/adapt-skill/SKILL.md). It installs the template into the folder where the project keeps its skills (`.claude/skills/`, `.agents/skills/`, `.github/skills/` or `.gemini/skills/`), and, for Claude Code, any template agents it uses into `.claude/agents/`. It fills in every `CUSTOMIZE` marker from what it finds in the project and asks you about anything it can't work out. Run it again later to refresh the skill when the project's conventions or scripts change, or the template improves: it keeps your own edits.

Without an agent that can run `adapt-skill`, copy the template with the script and adapt it by hand:

```sh
scripts/add-template.sh <skill> path/to/project
```

It picks the skills folder the way `adapt-skill` does: the one the project already keeps skills in, otherwise `.agents/skills/` for a project with an `AGENTS.md` and no `CLAUDE.md`, otherwise `.claude/skills/`. Choose another with `--dir`, for example `--dir .github/skills` for Copilot. Template agents are copied only into a Claude Code project's `.claude/agents/`.

## Installing the portable skills and agents

The repo is a plugin named `artberri` that ships the portable skills and agents. Templates and drafts are not part of it. Claude Code, Codex and GitHub Copilot CLI all install it from the [artberri marketplace](https://github.com/artberri/claude-plugins). A release reaches installs when the plugin's version changes, through each agent's update command below.

### Claude Code

```sh
claude plugin marketplace add artberri/claude-plugins
claude plugin install artberri@artberri
```

Update with `claude plugin update artberri@artberri`.

### Codex

```sh
codex plugin marketplace add artberri/claude-plugins
codex plugin add artberri@artberri
```

To update, run `codex plugin add artberri@artberri` again. (`codex plugin marketplace upgrade` only refreshes the marketplace list, not the plugin.)

### GitHub Copilot CLI

```sh
copilot plugin marketplace add artberri/claude-plugins
copilot plugin install artberri@artberri
```

Update with `copilot plugin update artberri@artberri`.

### Others (Gemini CLI, Cursor, OpenCode...)

[skills.sh](https://www.skills.sh/) copies the portable skills into a project, or with `-g` into your home folder:

```sh
npx skills add artberri/skills
```

Update with `npx skills update`, and run `add` again to get skills added since. This route installs skills only: no agents or hooks, so `ocr-review` (which needs its reviewer agent) won't run.

### What works where

All three plugin installs load every portable skill. A few depend on the agent:

- `ocr-review` runs in Claude Code and Copilot CLI, which load its reviewer agent; Codex can't start named agents.
- `retro` reads Claude Code, Codex and Copilot CLI sessions.
- `setup-ocr` and `setup-review-docs` only run when you ask for them in Claude Code and Codex. Copilot CLI has no way to keep its model from starting a skill on its own.
- The optional hooks run in Claude Code and Copilot CLI, which both read them from the plugin. Codex doesn't run a plugin's hooks (tested with Codex 0.166.0).

### From a checkout (Claude Code)

To load the plugin from a checkout, so edits take effect in the next session, add the checkout's path to `CLAUDE_CODE_PLUGIN_DIRS` in your `settings.json` (separate several folders with `:`):

```json
{
	"env": {
		"CLAUDE_CODE_PLUGIN_DIRS": "/path/to/skills"
	}
}
```

The plugin also registers optional hooks, all off until you turn them on with an environment variable. One is [git-guardrails](./hooks/git-guardrails/README.md), which blocks the git commands the skills forbid: staging everything, force-pushing, and skipping signing or hooks.

Plugin skills keep their short names (`/commit`) unless another plugin uses the same one; then use `/artberri:commit`. Agents always carry the prefix: `artberri:ocr-reviewer`.

## Layout

```
.claude-plugin/plugin.json     the artberri plugin: portable skills and agents
skills/
	portable/<skill>/SKILL.md    use as-is
	templates/<skill>/SKILL.md   copy into a project, then adapt
	drafts/<skill>/SKILL.md      work in progress
agents/
	portable/<agent>.md          same buckets, one file per agent
	templates/<agent>.md
	drafts/<agent>.md
hooks/
	git-guardrails/              optional hook that blocks forbidden git commands
scripts/
	add-template.sh              copy a template (and its agents) into a project, without adapt-skill
	check.sh                     validate every skill, agent and README
	lib.sh                       helpers shared by the scripts
	evals/run.sh                 run a skill's evals in throwaway repositories and grade them
```

Each skill is a folder with a `SKILL.md` and any reference files it loads on demand, plus its evals in `evals/`.

## Credits

The layout and conventions draw on [mattpocock/skills](https://github.com/mattpocock/skills).

## License

[MIT](./LICENSE)
