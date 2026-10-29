---
name: adapt-skill
description: Adapt a skill template that was copied into this project, and the template agents it uses, by filling in their CUSTOMIZE markers from the project's code, config and conventions. Use when the user asks to adapt or customise a skill, or when a skill in this project still contains `<!-- CUSTOMIZE:` markers.
argument-hint: <skill-name>
---

# Adapt a skill template

A template is a skill with `<!-- CUSTOMIZE: ... -->` HTML comments on its project-specific parts. Each comment says what to fill in and where to look. The content under it, up to the next heading or marker, is an example of the right shape. Your job is to replace every example with what is true for this project and delete every marker.

## 1. Find the skill

Look for the skill named in the arguments in `.claude/skills/<name>/`, then `.agents/skills/<name>/`. If no name was given, find the skills in those folders that still contain `<!-- CUSTOMIZE:` and ask which one to adapt. Include every file in the skill's folder, not only `SKILL.md`.

If the skill's frontmatter lists agents under `metadata.agents`, include each one found at `.claude/agents/<agent>.md` that still contains `<!-- CUSTOMIZE:`. An agent without markers was already adapted (another skill may share it); leave it alone.

## 2. Investigate

For each marker, gather the answer from the project before asking anything: the files the marker points to, `README`, `CLAUDE.md` / `AGENTS.md`, package manifests, the Makefile or task runner, CI config, and recent git history for conventions. Note where each answer came from.

## 3. Confirm

Show the user one list: each marker, the value you propose, and its source. Ask about the markers you could not settle, all in the same message. Wait for their answers before editing anything.

## 4. Rewrite

- Replace each marker's example content with the confirmed answer, written in the same voice and level of detail as the rest of the skill.
- Delete the marker comment.
- If a marker turns out not to apply to this project, remove the part it governs, and tidy anything that referred to it.
- Leave the frontmatter `name` as it is. Change `description` only if it no longer matches what the adapted skill does.
- Edit only files inside the skill's folder and the agent files from step 1.

## 5. Verify

Search the skill's folder and those agent files for `CUSTOMIZE`. Done when there are no matches. Then summarise what you filled in for each marker.
