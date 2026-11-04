---
name: adapt-skill
description: Install a skill template into this project, or refresh one already installed, by filling in its CUSTOMIZE markers (and those of the template agents it uses) from the project's code, config and conventions. Run it again when the project's conventions or scripts change, or the template improves. Use when the user asks to add, set up, adapt, customise or refresh a skill template (for example "set up ship", "/adapt-skill ship"), or when a skill in this project still contains `<!-- CUSTOMIZE:` markers.
argument-hint: "[template-name]"
---

# Adapt a skill template

A template is a skill with `<!-- CUSTOMIZE: ... -->` HTML comments on its project-specific parts. Each comment says what to fill in and where to look. The content under it, up to the next heading or marker, is an example of the right shape. Adapting replaces every example with what is true for this project and deletes every marker. The result lives in the project's skills folder (see step 1), and is meant to be committed.

Templates live in `../../templates/<name>/` relative to this skill's folder, and the agents they use in `../../../agents/templates/` and `../../../agents/portable/`. If `../../templates/` doesn't exist, this skill was installed on its own (for example with `npx skills add`, which leaves the templates out): make a temporary folder with `mktemp -d`, clone this skill's repo into it with `git clone --depth 1 https://github.com/artberri/skills.git <folder>/skills`, read the templates from `<folder>/skills/skills/templates/` and the agents from `<folder>/skills/agents/` instead, and delete the folder when you are done. A template folder may hold a `SETUP.md`: guidance for adapting that template (what to look for, which questions to ask and in what order). Read it and follow it alongside this skill. `SETUP.md` and `evals/` are never copied into the project.

This is a prompt-driven skill, not a script. Explore, present what you found, confirm with the user, then write.

## 1. Find the template and the project's copy

Agents look for project skills in different folders: `.claude/skills/` (Claude Code), `.agents/skills/` (Codex and others), `.github/skills/` (GitHub Copilot), `.gemini/skills/` (Gemini CLI). These are the skills folders below.

- **No name given:** list the templates in `../../templates/` (one line each, from their `description`) and the skills in the project's skills folders that still contain `<!-- CUSTOMIZE:`, and ask which one.
- **The template:** read `../../templates/<name>/`: its `SKILL.md`, every file next to it, and its `SETUP.md` if there is one. Note its `metadata.template-revision`.
- **The project's copy:** look for `<name>/` in each skills folder.
  - **None:** this is an install.
  - **One with markers left:** it was copied (for example by `scripts/add-template.sh`) but never adapted. Treat it as an install, starting from that copy.
  - **One without markers:** this is a refresh. Its content holds the earlier answers and any edits the user made by hand. A lower `template-revision` than the template's means the template has improved since.
- **Where it goes:** on a refresh, where the project's copy already is. On an install, the first that applies:
  1. The skills folder the project already keeps its other skills in. If it uses more than one, ask which, recommending the one with the most skills.
  2. The skills folder this skill is installed in, if that is inside the project.
  3. Otherwise ask, recommending `.claude/skills/` if the project has a `CLAUDE.md`, and `.agents/skills/` if it has only an `AGENTS.md`.
- **Agents:** for each name in the template's `metadata.agents`, find the agent file. Agent files are Claude Code subagents, so they go in `.claude/agents/`: install them only when the project uses Claude Code (the skill goes in `.claude/skills/`, or the project has a `.claude/` folder or a `CLAUDE.md`). Otherwise tell the user which agents the skill needs and that their agent may not support them, and carry on without them. A template agent is installed to `.claude/agents/<agent>.md` and adapted like the skill; an existing one without markers was already adapted (another skill may share it), so leave it alone unless this is a refresh and its template changed. A portable agent normally comes from the plugin: check it is available, and if it isn't (the plugin isn't installed), install it to `.claude/agents/<agent>.md` unchanged.
- **Template not found** (no templates next to this skill and the clone failed, for example offline): adapt the project's copy if there is one; otherwise tell the user why and stop.

## 2. Explore

For each marker, and everything the `SETUP.md` asks you to look at, gather the answer from the project before asking anything: the files the marker points to, `README`, `CLAUDE.md` / `AGENTS.md`, package manifests, the Makefile or task runner, CI config, git hooks, and recent git history for conventions. Note where each answer came from.

On a refresh, also note what changed since the skill was written: new scripts or checks, new docs it should reference, docs or tools it references that are gone, and what the template changed.

## 3. Confirm

Present what you found, then ask. If `SETUP.md` gives questions and an order, follow it: one question per message, then wait for the answer before the next, each led by your recommendation so the user can accept it in a word. Do this even when you found every answer yourself; if the user tells you to take your recommendations for the rest, stop asking. Otherwise show one list: each marker, the value you propose and its source, and ask about the markers you couldn't settle, all in the same message.

On a refresh, don't ask again what the existing skill already answers unless it changed; ask only about what is new.

Wait for the answers before writing anything.

## 4. Draft

- **Install:** start from the template. Replace each marker's example content with the confirmed answer, written in the same voice and level of detail as the rest of the skill, and delete the marker. If a marker doesn't apply to this project, remove the part it governs and tidy anything that referred to it.
- **Refresh:** start from the project's copy. Keep the user's hand edits, apply what changed in the project, and bring in the template's improvements, adapting any new markers.
- Keep the frontmatter `name`, and `metadata.template-revision` equal to the template's. Change `description` only if it no longer matches what the adapted skill does.

Show the user the draft: in full on an install, as a diff against the existing copy on a refresh. Then wait for their go-ahead before writing, and apply any edits they ask for. This holds even when they accepted every answer: accepting the answers is not approving the draft.

## 5. Write and verify

Write the skill to `<name>/` in the skills folder chosen in step 1, and any agents to `.claude/agents/`. Edit nothing else. Then:

- Search what you wrote for `CUSTOMIZE`: there must be no markers left.
- Check every path it links to exists in the project.

Summarise what you filled in or changed, and tell the user the files are meant to be committed so everyone working on the project gets the same skill. Don't commit them yourself.
