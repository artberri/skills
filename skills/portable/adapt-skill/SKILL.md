---
name: adapt-skill
description: Install a skill template into this project, or refresh one already installed, by filling in its CUSTOMIZE markers (and those of the template agents it uses) from the project's code, config and conventions. Run it again when the project's conventions or scripts change, or the template improves. Use when the user asks to add, set up, adapt, customise or refresh a skill template (for example "set up ship", "/adapt-skill ship"), or when a skill in this project still contains `<!-- CUSTOMIZE:` markers.
argument-hint: "[template-name]"
---

# Adapt a skill template

A template is a skill with `<!-- CUSTOMIZE: ... -->` HTML comments on its project-specific parts. Each comment says what to fill in and where to look. The content under it, up to the next heading or marker, is an example of the right shape. Adapting replaces every example with what is true for this project and deletes every marker. The result lives in the project, at `.claude/skills/<name>/`, and is meant to be committed.

Templates live in `../../templates/<name>/` relative to this skill's folder, and the agents they use in `../../../agents/templates/` and `../../../agents/portable/`. A template folder may hold a `SETUP.md`: guidance for adapting that template (what to look for, which questions to ask and in what order). Read it and follow it alongside this skill. `SETUP.md` and `evals/` are never copied into the project.

This is a prompt-driven skill, not a script. Explore, present what you found, confirm with the user, then write.

## 1. Find the template and the project's copy

- **No name given:** list the templates in `../../templates/` (one line each, from their `description`) and the skills in `.claude/skills/` that still contain `<!-- CUSTOMIZE:`, and ask which one.
- **The template:** read `../../templates/<name>/`: its `SKILL.md`, every file next to it, and its `SETUP.md` if there is one. Note its `metadata.template-revision`.
- **The project's copy:** look in `.claude/skills/<name>/`, then `.agents/skills/<name>/`.
  - **None:** this is an install.
  - **One with markers left:** it was copied (for example by `scripts/add-template.sh`) but never adapted. Treat it as an install, starting from that copy.
  - **One without markers:** this is a refresh. Its content holds the earlier answers and any edits the user made by hand. A lower `template-revision` than the template's means the template has improved since.
- **Agents:** for each name in the template's `metadata.agents`, find the agent file. A template agent is installed to `.claude/agents/<agent>.md` and adapted like the skill; an existing one without markers was already adapted (another skill may share it), so leave it alone unless this is a refresh and its template changed. A portable agent comes from the plugin: just check it is available.
- **Template not found** (this skill was copied without the rest of its repo): adapt the project's copy if there is one; otherwise tell the user and stop.

## 2. Explore

For each marker, and everything the `SETUP.md` asks you to look at, gather the answer from the project before asking anything: the files the marker points to, `README`, `CLAUDE.md` / `AGENTS.md`, package manifests, the Makefile or task runner, CI config, git hooks, and recent git history for conventions. Note where each answer came from.

On a refresh, also note what changed since the skill was written: new scripts or checks, new docs it should reference, docs or tools it references that are gone, and what the template changed.

## 3. Confirm

Present what you found, then ask. If `SETUP.md` gives questions and an order, follow it: one question, one answer, then the next, each led by your recommendation so the user can accept it in a word. Otherwise show one list: each marker, the value you propose and its source, and ask about the markers you couldn't settle, all in the same message.

On a refresh, don't ask again what the existing skill already answers unless it changed; ask only about what is new.

Wait for the answers before writing anything.

## 4. Draft

- **Install:** start from the template. Replace each marker's example content with the confirmed answer, written in the same voice and level of detail as the rest of the skill, and delete the marker. If a marker doesn't apply to this project, remove the part it governs and tidy anything that referred to it.
- **Refresh:** start from the project's copy. Keep the user's hand edits, apply what changed in the project, and bring in the template's improvements, adapting any new markers.
- Keep the frontmatter `name`, and `metadata.template-revision` equal to the template's. Change `description` only if it no longer matches what the adapted skill does.

Show the user the draft: in full on an install, as a diff against the existing copy on a refresh. Let them edit it before writing.

## 5. Write and verify

Write the skill to `.claude/skills/<name>/` (or where the project's copy already is) and any template agents to `.claude/agents/`. Edit nothing else. Then:

- Search what you wrote for `CUSTOMIZE`: there must be no markers left.
- Check every path it links to exists in the project.

Summarise what you filled in or changed, and tell the user the files are meant to be committed so everyone working on the project gets the same skill. Don't commit them yourself.
