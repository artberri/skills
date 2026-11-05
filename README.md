# Made-to-Measure Skills

Agent skills for Claude Code, Codex and GitHub Copilot CLI that fit the project they run in, and get refitted with every lesson a session teaches.

These are the skills I use often enough to want in every project: to plan a change, build it in small steps, get it reviewed by someone who didn't write it, ship it, and make sure the next session doesn't repeat this one's mistakes.

Process frameworks like [GSD](https://github.com/gsd-build/get-shit-done), [BMAD](https://github.com/bmad-code-org/BMAD-METHOD) and [Spec-Kit](https://github.com/github/spec-kit) give the agent a whole method: a sequence of phases, documents in their format, sometimes a cast of personas. That's a real help when you want a method handed to you, or a team to share one. The cost is that you adopt it whole, and when a step doesn't fit how your project works, you change your project or work around the method.

These skills go the other way. Each one does one job, works on its own, and stops at the decisions that are yours to make. They have opinions too (vertical slices, outside-in TDD, one topic per commit, a second reviewer who didn't write the code), but each opinion lives in one skill you can skip, edit or replace. The price is that you put the flow together yourself, though [how they fit together](#how-they-fit-together) suggests one.

They come in two kinds:

- **Portable** skills work as they are, in any project, because everything they depend on can be found out at run time. You install them once.
- **Templates** depend on how a project works: its test command, where it keeps plans, whether it ships through pull requests or straight to `main`. You install one into a project, it gets filled in from what the project already has, and from then on the project owns it.

To try them in Claude Code:

```sh
claude plugin marketplace add artberri/claude-plugins
claude plugin install artberri-skills@artberri
```

[Installing](#installing-the-portable-skills-and-agents) covers Codex, Copilot CLI and other agents.

## Why these skills exist

Most of these skills are here because an agent kept failing in the same way.

### The skill doesn't know your project

A generic skill has to guess what varies between projects. It runs `npm test` in a project that uses `make check`, or asks you for the command every time.

**The fix** is a template with a `CUSTOMIZE` marker on every project-specific part. [`/adapt-skill <skill>`](./skills/portable/adapt-skill/SKILL.md) installs it into the project and fills in each marker from the code, config and conventions it finds, asking you only about what it can't work out. Run it again when the project or the template changes: it refreshes the skill and keeps your edits.

### The agent reviews its own work

The session that wrote the code has a mental model that justifies every line. Ask it to review and it finds what it expected to find.

**The fix** is a reviewer that starts with a fresh context and knows only what the change should do:

- [`adversarial-review`](./skills/portable/adversarial-review/SKILL.md) reviews local changes before they ship, with one reviewer or a council of them, each focused on one area. Findings are ranked by how many reviewers found them independently.
- [`ocr-review`](./skills/portable/ocr-review/SKILL.md) reviews a pull request (or unpushed commits) with [Open Code Review](https://github.com/alibaba/open-code-review) in a fresh subagent, on your Claude Code or Copilot subscription, and posts the findings as a GitHub review.
- [`address-pr-comments`](./skills/portable/address-pr-comments/SKILL.md) works through the review comments one at a time, agreeing or disagreeing with a reason, instead of applying all of them.
- [`setup-review-docs`](./skills/portable/setup-review-docs/SKILL.md) writes down the patterns that look like defects but are deliberate, and the defects the project keeps getting, so reviewers stop flagging the first and start catching the second.

### The same mistake, next session

You correct the agent, it does better, and tomorrow's session makes the same mistake. An agent's personal memory keeps the lesson where only that agent, on that machine, will find it.

**The fix** is to write it into the project, where every agent and teammate reads it:

- [`capture-learnings`](./skills/portable/capture-learnings/SKILL.md) pulls the corrections, gotchas and patterns out of a conversation, checks them against what's already documented and what the code does, and writes the ones you approve into `AGENTS.md`, a skill's references or the review docs. It also corrects the docs the conversation proved wrong.
- [`retro`](./skills/portable/retro/SKILL.md) reads the last day or week of Claude Code, Codex and Copilot CLI sessions and proposes three to five concrete changes: a new skill, a rule, a workflow change.

### Too much change to review

An agent can write a thousand lines before you've read ten, and a change too big to review gets approved unread.

**The fix** is small steps, with a stop between them:

- [`create-plan`](./skills/templates/create-plan/SKILL.md) splits the work into vertical-slice phases, each shippable and small enough to review in one sitting. Nothing is written until you agree on the breakdown.
- [`execute-plan`](./skills/templates/execute-plan/SKILL.md) carries out one phase per run, with outside-in TDD and small commits, then stops and asks before the next.
- [`commit`](./skills/portable/commit/SKILL.md) makes one commit per topic, with a message that says why, and splits a file across commits when it mixes two. It never turns signing or hooks off to get a commit through.

### Rules in prose get broken

"Never force-push" in `AGENTS.md` holds until the model slips.

**The fix** is the optional [git-guardrails](./hooks/git-guardrails/README.md) hook, which turns the git rules the skills state into hard denials: staging everything, force-pushing, skipping signing or hooks. And the skills that act on their own, like [`ship`](./skills/templates/ship/SKILL.md), stop for the calls that are yours: a secret in the diff, a rebase conflict, a review finding that needs a product decision.

### Tested like code

A skill is a prompt, and prompts regress quietly. Evals run a skill in a throwaway repository, with a `gh` stub that never reaches GitHub, and grade it on the commits, branches and pull requests it leaves behind, not only on what it says. Trigger tests check that a description picks its skill over the siblings that compete for the same request. So far `commit`, `ship`, `adversarial-review` and `adapt-skill` have evals; the rest are still to come. CI validates every skill, agent and script, and behaviour in Codex and Copilot is tried in those agents, not assumed (see [what works where](#what-works-where)).

## Where this fits: harness engineering

The work these skills do has a name that caught on in 2026: harness engineering. [Mitchell Hashimoto](https://mitchellh.com/writing/my-ai-adoption-journey) describes it as engineering a fix whenever an agent makes a mistake, so that it never makes that mistake again. [Birgitta Böckeler](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html) splits a harness into guides, which steer the agent before it acts, and sensors, which catch what it got wrong afterwards. [OpenAI's Codex team](https://openai.com/index/harness-engineering/) wrote up building a whole product that way.

In those terms:

- **Guides:** the skills themselves, and the docs they keep up to date: `AGENTS.md` and the review docs.
- **Sensors:** the fresh-context reviewers in `adversarial-review` and `ocr-review`, and the git-guardrails hook. The reviewers are models, so they're slower, costlier and less predictable than a test; the hook is the only deterministic check the plugin ships.
- **The loop that improves the harness:** `capture-learnings`, `retro` and `setup-review-docs`, which turn what went wrong into a guide.
- **Templates** have the problem Böckeler raises for harness templates: project copies fall behind as the template improves. `adapt-skill` refreshes a copy and keeps the project's edits.

What the skills don't give you are the sensors that matter most: your project's tests, types and linters. `execute-plan` runs the tests at every step and `ship` runs the checks the project picks before each push, but neither can make up for checks the project doesn't have.

## How they fit together

A feature, start to finish. Each step works without the others, so use the ones you need:

1. [`research`](./skills/portable/research/SKILL.md) whether a library or approach is worth adopting, from its docs, GitHub issues, your codebase and the web.
2. [`write-acceptance-criteria`](./skills/templates/write-acceptance-criteria/SKILL.md) from the tickets, specs, designs and code, flagging the conflicts between them.
3. [`create-plan`](./skills/templates/create-plan/SKILL.md), then [`execute-plan`](./skills/templates/execute-plan/SKILL.md) phase by phase.
4. [`adversarial-review`](./skills/portable/adversarial-review/SKILL.md) before it leaves your machine.
5. [`ship`](./skills/templates/ship/SKILL.md): commit, rebase, run the checks, push, open the pull request and run the first [`ocr-review`](./skills/portable/ocr-review/SKILL.md) round.
6. [`address-pr-comments`](./skills/portable/address-pr-comments/SKILL.md) until the review is done.
7. [`capture-learnings`](./skills/portable/capture-learnings/SKILL.md) at the end, and [`retro`](./skills/portable/retro/SKILL.md) once a week.

## Skills

Templates are marked _template_.

**Plan**

- **[research](./skills/portable/research/SKILL.md)**: feasibility, integration cost and risks of adopting a library, tool or architectural change, as a structured report.
- **[write-acceptance-criteria](./skills/templates/write-acceptance-criteria/SKILL.md)** _template_: acceptance criteria cross-referenced from tickets, specs, designs and code, written back to the tickets.
- **[create-plan](./skills/templates/create-plan/SKILL.md)** _template_: a plan of vertical-slice phases, revised with finished phases locked and audited against the code.

**Build and ship**

- **[execute-plan](./skills/templates/execute-plan/SKILL.md)** _template_: one phase at a time, with outside-in TDD and small commits.
- **[commit](./skills/portable/commit/SKILL.md)**: small, focused, signed commits in the repo's style. Never pushes.
- **[ship](./skills/templates/ship/SKILL.md)** _template_: from a dirty working tree to a pull request with its first review round, or to a reviewed push to `main`, in one move.

**Review**

- **[adversarial-review](./skills/portable/adversarial-review/SKILL.md)**: fresh-context reviewers for local changes, alone or as a council.
- **[ocr-review](./skills/portable/ocr-review/SKILL.md)**: Open Code Review of a pull request or of unpushed commits, posted as a GitHub review or kept locally.
- **[address-pr-comments](./skills/portable/address-pr-comments/SKILL.md)**: evaluate, fix, reply to and resolve every open review thread.
- **[setup-review-docs](./skills/portable/setup-review-docs/SKILL.md)**: the project's known non-issues, pre-PR checklist and footguns, from its merged reviews.
- **[setup-ocr](./skills/portable/setup-ocr/SKILL.md)**: configure a repo for `ocr-review`.

**Learn**

- **[capture-learnings](./skills/portable/capture-learnings/SKILL.md)**: turn a conversation's corrections into project docs.
- **[retro](./skills/portable/retro/SKILL.md)**: a retrospective over a day or week of agent sessions.

**Templates**

- **[adapt-skill](./skills/portable/adapt-skill/SKILL.md)**: install a template into a project, or refresh it, filling in its markers from the project.

Some skills hand work to **agents** (subagents with their own prompt, tools and model). They're split into the same [portable](./agents/portable/README.md) and [template](./agents/templates/README.md) kinds, and adding a template brings in its template agents too. [Drafts](./skills/drafts/README.md) are skills in progress and are never installed.

## Installing the portable skills and agents

The repo is a plugin named `artberri-skills` that ships the portable skills and agents. Templates and drafts are not part of it. Claude Code installs it from the [artberri marketplace](https://github.com/artberri/claude-plugins), which also lists my other Claude Code plugins. Codex and GitHub Copilot CLI install it from this repo, which is its own marketplace, also named `artberri-skills`. A release reaches installs when the plugin's version changes, through each agent's update command below.

### Claude Code

```sh
claude plugin marketplace add artberri/claude-plugins
claude plugin install artberri-skills@artberri
```

Update with `claude plugin update artberri-skills@artberri`.

### Codex

```sh
codex plugin marketplace add artberri/skills
codex plugin add artberri-skills@artberri-skills
```

To update, run `codex plugin add artberri-skills@artberri-skills` again. (`codex plugin marketplace upgrade` only refreshes the marketplace, not the plugin.)

### GitHub Copilot CLI

```sh
copilot plugin marketplace add artberri/skills
copilot plugin install artberri-skills@artberri-skills
```

Update with `copilot plugin update artberri-skills@artberri-skills`.

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

### Hooks

The plugin also registers optional hooks, all off until you turn them on with an environment variable. One is [git-guardrails](./hooks/git-guardrails/README.md), which blocks the git commands the skills forbid: staging everything, force-pushing, and skipping signing or hooks.

Plugin skills keep their short names (`/commit`) unless another plugin uses the same one; then use `/artberri-skills:commit`. Agents always carry the prefix: `artberri-skills:ocr-reviewer`.

### From a checkout (Claude Code)

To load the plugin from a checkout, so edits take effect in the next session, add the checkout's path to `CLAUDE_CODE_PLUGIN_DIRS` in your `settings.json` (separate several folders with `:`):

```json
{
	"env": {
		"CLAUDE_CODE_PLUGIN_DIRS": "/path/to/skills"
	}
}
```

## Using a template in a project

From inside the project, with the plugin or the `adapt-skill` skill installed, run [`/adapt-skill <skill>`](./skills/portable/adapt-skill/SKILL.md). It installs the template into the folder where the project keeps its skills (`.claude/skills/`, `.agents/skills/`, `.github/skills/` or `.gemini/skills/`), and, for Claude Code, any template agents it uses into `.claude/agents/`. It fills in every `CUSTOMIZE` marker from what it finds in the project and asks you about anything it can't work out. Run it again later to refresh the skill when the project's conventions or scripts change, or the template improves: it keeps your own edits.

Without an agent that can run `adapt-skill`, copy the template with the script and adapt it by hand:

```sh
scripts/add-template.sh <skill> path/to/project
```

It picks the skills folder the way `adapt-skill` does: the one the project already keeps skills in, otherwise `.agents/skills/` for a project with an `AGENTS.md` and no `CLAUDE.md`, otherwise `.claude/skills/`. Choose another with `--dir`, for example `--dir .github/skills` for Copilot. Template agents are copied only into a Claude Code project's `.claude/agents/`.

## Layout

```
.claude-plugin/
	plugin.json                  the artberri-skills plugin: portable skills and agents
	marketplace.json             the artberri-skills marketplace, for Codex and Copilot CLI
.claude/skills/                skills for working on this repo, never shipped
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
docs/
	TODO.md                      work left for later
scripts/
	add-template.sh              copy a template (and its agents) into a project, without adapt-skill
	check.sh                     validate every skill, agent and README
	lib.sh                       helpers shared by the scripts
	evals/run.sh                 run a skill's evals in throwaway repositories and grade them
```

Each skill is a folder with a `SKILL.md` and any reference files it loads on demand, plus its evals in `evals/`. [AGENTS.md](./AGENTS.md) has the rules for writing and changing them.

## Credits

The layout and conventions, and this README's problem-first structure, draw on [mattpocock/skills](https://github.com/mattpocock/skills). The description checklist in `AGENTS.md` comes from [eferro/skill-factory](https://github.com/eferro/skill-factory), and two checks in `capture-learnings`, testing a convention against the code and correcting docs proved wrong, from Emilio Carrión's [`compound`](https://gist.github.com/EmilioCarrion/efdfa5487963651bf65fc491f30fbeb4) skill, which I found through it.

## License

[MIT](./LICENSE)
