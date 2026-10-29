# Templates

Skills to copy into a project and adapt there. Each one has `CUSTOMIZE` markers on the parts that depend on the project (see [AGENTS.md](../../AGENTS.md#customize-markers)).

To use one:

```sh
scripts/add-template.sh <skill> path/to/project
```

then run `/adapt-skill <skill>` inside the project.

- **[ship](./ship/SKILL.md)**: Take finished work to shipped in one move: commit, rebase, push and, for projects that ship through pull requests, open the PR and run the first review round. Set it up with `/setup-ship`, which also refreshes it later.
