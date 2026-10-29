---
name: retro
description: Retrospective analysis of Claude Code sessions in this project, to surface strategic insights, skill proposals, workflow improvements and recurring friction by reading past session transcripts. Two scopes, day (today's sessions) and week (last 7 days, the default), or a custom window. Use when the user asks for a retrospective, wants to review what happened this week, find cross-session patterns, propose new skills or workflow changes, or wants the big picture on how things are going. Trigger phrases include "retro", "retrospective", "what happened this week", "weekly retro", "any patterns", "review sessions", "how's the workflow going", "what should we change", "/retro", "/retro day", "/retro week".
---

# Retro

A real retrospective, not a documentation audit. The goal is to surface what's working, what's not, where the workflow is leaking time, and what concrete changes (skills, process, communication) would make the next two weeks better than the last.

It is bidirectional: not only "what should the agent do better", but also "what could the user do to make sessions more efficient". A good retro is honest in both directions.

## Scope

| Scope | Reads | Focus |
|-------|-------|-------|
| `day` | All of today's sessions in this project | Tactical: patterns across today's work, repeated corrections |
| `week` | The last 7 days of sessions | Strategic: recurring patterns, skill proposals, workflow changes, ways of working |

Parse the scope from the invocation: `/retro` is `week` (the default), `/retro day` is `day`, `/retro week` is `week`. The user may ask for a custom window ("last two weeks", "last 3 days"): use `--days`.

## Workflow

### Step 1: Extract session data

Run from the project's root (needs Python 3.9 or later):

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/extract_sessions.py --scope <day|week> --compact
```

For a custom window, add `--days <n>` to `--scope week`. `--date YYYY-MM-DD` moves the window's last day; days are local days.

The script reads this project's `.jsonl` transcripts from `$CLAUDE_CONFIG_DIR/projects/` (or `~/.claude/projects/`) and returns a JSON array of session summaries: title, branch, date, duration, user prompts, assistant summaries, corrections, skills used, files edited and read, commits, tool usage and prompt count. If it reports no transcripts for the project, check you are in the project's root (or pass `--cwd`), and tell the user if there are none.

**For 8 or more sessions:** start one general-purpose subagent per 3-4 sessions, each with a fresh context, to analyse in parallel. Give each its batch of session summaries and the brief below. Collect their outputs before synthesising.

### Step 2: Analyse

Give each subagent (or analyse directly, for a small batch) the session summaries and this brief:

> Analyse these Claude Code session summaries. For each category below, identify the most significant findings. Cite specific sessions and quote user prompts where relevant.
>
> **Category 1: What went well**
> - Skills or workflows that clearly saved time or caught real issues
> - Patterns the user and agent fell into that worked (for example parallel investigation, fork and hand over, plan → implement → ship)
> - Sessions that were notably efficient: what made them work?
> - Moments where the agent proactively did the right thing without being asked
>
> **Category 2: What went wrong**
> - Sessions that went off the rails: excessive prompt counts, wrong direction, wasted time
> - Root causes, not just "the session was long" but why (missing docs? a wrong assumption? the agent didn't check something? the user gave incomplete context?)
> - Repeated debugging patterns: the same class of bug or investigation happening several times
> - Corrections the user had to make more than once (across sessions, not just within one)
>
> **Category 3: What can be improved (ways of working)**
> - Process changes: pre-implementation checks, post-implementation gates, hooks or guards that would prevent classes of issues
> - Communication patterns, honest in both directions:
>   - **Agent side**: where did the agent make avoidable assumptions, fail to check something, or go too far before validating?
>   - **User side**: where could the user have saved time by giving more context upfront, being clearer about constraints, linking relevant docs, or giving a brief instead of incremental corrections? Frame these as observations with evidence, not blame: "sessions where X was provided upfront went 3x faster than sessions where it emerged through corrections"
> - Workflow bottlenecks: steps that take disproportionate time, manual procedures that should be automated
> - Skills that should have triggered but didn't, or triggered but produced poor results
>
> **Category 4: Proposals**
> For each concrete proposal, give:
> - **Type**: `new-skill`, `skill-improvement`, `new-doc`, `workflow-change`, `rule`, `reinforcement`
> - **What**: a one-line description
> - **Why**: the evidence from the sessions: which sessions, what happened
> - **How**: the concrete next step (create the skill, edit a `SKILL.md`, add to `AGENTS.md` or `CLAUDE.md`, create a doc, add a hook or setting)
>
> Prioritise impact over volume: 3 "whoa" insights beat 10 incremental tweaks. Leave granular doc patches to the `capture-learnings` skill; this is about strategic changes.

### Step 3: Synthesise (multiple batches only)

When several subagents return findings:

1. **Deduplicate**: merge findings that describe the same pattern from different sessions.
2. **Amplify cross-batch patterns**: a finding that appears independently in 2 or more batches is stronger evidence than one from a single batch.
3. **Resolve contradictions**: if one batch says "X worked well" and another says "X caused problems", investigate the difference (likely different contexts).

### Step 4: Verify against the existing docs

Before presenting proposals, check whether each finding is already covered:

1. Read the file where the change would go (`AGENTS.md`, `CLAUDE.md`, a skill, a doc).
2. Search it for existing coverage.
3. Classify as `skip` (already covered), `amend` (partly covered, needs an update) or `add` (new).

Drop `skip` items silently. Present `amend` items as updates to existing rules or docs.

### Step 5: Present the retro

Start with a summary paragraph: how many sessions, what areas were touched, the overall mood, and the single biggest takeaway. Then four sections.

**What went well**
- 2-4 highlights with specific evidence.
- Name each pattern so it can be referred to later ("parallel investigation with scoped subagents").
- For each: why it worked, and whether it should be reinforced or formalised.

**What went wrong**
- 2-4 lowlights with root-cause analysis.
- For each: the sessions, the prompt count or time spent, what went wrong and why.
- Be direct: "the 128-prompt session happened because X was undocumented", not "there were some challenges".

**What can be improved**
- 2-4 ways-of-working changes, covering both sides:
  - Agent side: "when investigating an API-dependent bug, check the backend's response shape first: it would have saved three sessions of corrections".
  - User side: "sessions where a brief or ticket link was given upfront averaged 15 prompts; sessions where the context emerged through corrections averaged 40 or more".
- Frame user-side feedback as observations with evidence, not prescriptions. The user decides whether to change their approach.

**Proposals**

Present them as a table:

```
| # | Type | Proposal | Evidence | Next step |
|---|------|----------|----------|-----------|
| 1 | new-skill | `/release-check`: the release-branch checklist | 4 sessions on one release, each rediscovering the same constraints | create the skill |
| 2 | new-doc | `docs/ARCHITECTURE.md`: how the sync worker fits together | a 128-prompt session whose root causes were all undocumented | create the doc |
| 3 | workflow-change | A pre-push hook blocking direct pushes to release branches | the user corrected this mid-session | add the hook |
```

For a skill proposal, add below the table:
- the proposed name and a one-line description;
- the sessions where the procedure was carried out by hand;
- the inputs, outputs and steps it would automate;
- whether it is new or an improvement to an existing skill.

**Aim for 3-5 proposals, not 20.** The user wants "whoa" insights, not a changelog.

**Wait for the user's confirmation** before applying anything.

### Step 6: Apply

For the confirmed proposals:
- **Rule changes and description edits:** apply them directly.
- **New skills:** suggest creating them with the `skill-creator` skill, if available.
- **Workflow changes and hooks:** apply the `AGENTS.md` or `CLAUDE.md` change, or suggest the `update-config` skill (if available) for hooks and settings.
- **New docs:** create a skeleton and reference it from `AGENTS.md` or `CLAUDE.md`.
- **Reinforcements:** strengthen the relevant skill description or project rule.

## Rules

- Proposals go into the project (`AGENTS.md`, `CLAUDE.md`, its skills and docs), where everyone working on it gets them, never into the agent's private memory.
- Leave granular doc patches to the `capture-learnings` skill, if available. Retro is for strategic changes: workflow, skills, process, communication.
- A single-session retrospective belongs to `capture-learnings`. Retro is for multi-session analysis (`day`, `week` or wider).
- For `week` or wider, always start with the summary paragraph that sets the scene.
- Be honest in both directions. Sugarcoating user-side feedback defeats the purpose, but frame it as evidence ("sessions with X went faster"), not judgement ("you should do X").
- Skill proposals are first-class outputs, not afterthoughts. If a procedure was carried out by hand 2 or more times, propose a skill.
