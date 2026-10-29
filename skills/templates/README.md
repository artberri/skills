# Templates

Skills to install into a project and adapt there. Each one has `CUSTOMIZE` markers on the parts that depend on the project (see [AGENTS.md](../../AGENTS.md#customize-markers)), and may have a `SETUP.md` with guidance for adapting it.

To install one, or refresh it later, run `/adapt-skill <skill>` inside the project. Without Claude Code, copy it with `scripts/add-template.sh <skill> path/to/project` and fill in the markers by hand.

- **[ship](./ship/SKILL.md)**: Take finished work to shipped in one move: commit, rebase, push and, for projects that ship through pull requests, open the PR and run the first review round.
