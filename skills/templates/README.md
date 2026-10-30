# Templates

Skills to install into a project and adapt there. Each one has `CUSTOMIZE` markers on the parts that depend on the project (see [AGENTS.md](../../AGENTS.md#customize-markers)), and may have a `SETUP.md` with guidance for adapting it.

To install one, or refresh it later, run `/adapt-skill <skill>` inside the project. Without Claude Code, copy it with `scripts/add-template.sh <skill> path/to/project` and fill in the markers by hand.

- **[create-plan](./create-plan/SKILL.md)**: Plan a feature, refactor or fix as vertical-slice phases in the project's plans folder: a plan folder per task, or a board with one plan per ticket. Revises plans with completed phases locked, and audits them against the code.
- **[execute-plan](./execute-plan/SKILL.md)**: Carry out a plan one phase at a time, with outside-in TDD and small commits, and archive it to `done/` with a date prefix when the last phase is done. Works through boards plan by plan.
- **[ship](./ship/SKILL.md)**: Take finished work to shipped in one move: commit, rebase, push and, for projects that ship through pull requests, open the PR and run the first review round.
- **[write-acceptance-criteria](./write-acceptance-criteria/SKILL.md)**: Write acceptance criteria for a feature by cross-referencing its tickets, specs, designs, discussions and the code, flag conflicts and gaps, and write the approved criteria back to the tickets. Also revises existing criteria.
