# Skills

The agent skills I use often enough to want them in every project.

There are two kinds:

- **[Portable](./skills/portable/README.md)**: work as they are, in any project. You install them once and use them everywhere.
- **[Templates](./skills/templates/README.md)**: assume things only a project knows (its test command, its commit style, where its docs live). You copy one into a project and adapt it there, and the project owns that copy.

[Drafts](./skills/drafts/README.md) are skills in progress. They never get installed.

Some skills hand work to **agents** (subagents with their own prompt, tools and model). Agents are split the same way: [portable](./agents/portable/README.md), [templates](./agents/templates/README.md) and [drafts](./agents/drafts/README.md). A skill lists the agents it uses, and adding a template brings in its template agents too.

## Using a template in a project

```sh
scripts/add-template.sh <skill> path/to/project
```

That copies the skill into `path/to/project/.claude/skills/<skill>`, and any template agents it uses into `path/to/project/.claude/agents/`. Then, from inside the project, run [`/adapt-skill <skill>`](./skills/portable/adapt-skill/SKILL.md). The agent fills in every `CUSTOMIZE` marker from what it finds in the project, and asks you about anything it can't work out.

## Installing the portable skills and agents

The repo is a Claude Code plugin named `artberri` that ships the portable skills and agents. Templates and drafts are not part of it.

To load it from a checkout, so edits take effect in the next session, add the checkout's path to `CLAUDE_CODE_PLUGIN_DIRS` in your `settings.json` (separate several folders with `:`):

```json
{
	"env": {
		"CLAUDE_CODE_PLUGIN_DIRS": "/path/to/skills"
	}
}
```

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
scripts/
	add-template.sh              copy a template (and its agents) into a project
	check.sh                     validate every skill, agent and README
	lib.sh                       helpers shared by the scripts
```

Each skill is a folder with a `SKILL.md` and any reference files it loads on demand.

## Credits

The layout and conventions draw on [mattpocock/skills](https://github.com/mattpocock/skills).

## License

[MIT](./LICENSE)
