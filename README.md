# Skills

The agent skills I use often enough to want them in every project.

There are two kinds:

- **[Portable](./skills/portable/README.md)**: work as they are, in any project. You install them once and use them everywhere.
- **[Templates](./skills/templates/README.md)**: assume things only a project knows (its test command, its commit style, where its docs live). You copy one into a project and adapt it there, and the project owns that copy.

[Drafts](./skills/drafts/README.md) are skills in progress. They never get installed.

## Using a template in a project

```sh
scripts/add-template.sh <skill> path/to/project
```

That copies the skill into `path/to/project/.claude/skills/<skill>`. Then, from inside the project, run [`/adapt-skill <skill>`](./skills/portable/adapt-skill/SKILL.md). The agent fills in every `CUSTOMIZE` marker from what it finds in the project, and asks you about anything it can't work out.

## Installing the portable skills

Not decided yet.

## Layout

```
skills/
	portable/<skill>/SKILL.md    use as-is
	templates/<skill>/SKILL.md   copy into a project, then adapt
	drafts/<skill>/SKILL.md      work in progress
scripts/
	add-template.sh              copy a template into a project
	check.sh                     validate every skill and README
```

Each skill is a folder with a `SKILL.md` and any reference files it loads on demand.

## Credits

The layout and conventions draw on [mattpocock/skills](https://github.com/mattpocock/skills).

## License

[MIT](./LICENSE)
