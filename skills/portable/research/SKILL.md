---
name: research
description: Research the feasibility, integration cost and risks of adopting a library, tool, platform feature or architectural change, before committing to a plan. Use this skill whenever the user asks "what would it take to…", "is it feasible to…", "can we integrate X", "research X", "how hard would it be to…", or wants to evaluate a technology choice, understand a migration path, or assess integration effort. Also use it when the user asks you to look into a library's docs and known issues together: it combines doc lookup, GitHub issue search and codebase analysis into one structured workflow, so the user doesn't have to prompt for each one.
argument-hint: "<topic> [--no-doc]"
---

# Research

Produce a structured feasibility report by pulling from several sources in parallel: library documentation, GitHub issues, the project's codebase and the web. The output is a report, not an implementation plan. It answers "what would it take?" so the user can decide whether to go ahead.

## Input

The arguments are free text describing what to research. For example:

- "migrate from Express 4 to Express 5"
- "can we replace our hand-rolled date handling with Temporal"
- "what would it take to add offline support to the mobile app"
- "integrate OpenTelemetry tracing into the API"

If the topic is too broad ("improve performance"), ask the user to narrow it to a specific technology or change before going on.

Flags:

- `--no-doc`: don't write the report to a file; present the findings inline only.

## Workflow

### 1. Break down the research question

Before fetching anything, split the topic into concrete sub-questions. They decide which sources to query and keep the search focused.

Typical sub-questions:

- What does the library or tool provide? (capabilities, API surface)
- What does this project already have in place? (existing integrations, versions, config)
- What are the known issues or gotchas? (bugs, platform-specific problems, breaking changes)
- What's the migration or integration path? (steps, config changes, code changes)
- What are the risks? (compatibility, performance, maintenance burden)

Show the sub-questions briefly ("Here's what I'll look into: …. Anything else you want covered?"), then carry on without waiting unless the user jumps in.

### 2. Gather information (in parallel)

Each source answers different sub-questions, so query them in parallel.

#### 2a. Library documentation

If the Context7 MCP tools are available, use them for up-to-date docs on each library involved:

1. Resolve the library ID with `resolve-library-id`.
2. Query the topics from step 1 (setup, configuration, migration guides, API reference) with `query-docs`.

One query per focused area gives better results than one broad query. Without Context7, use web search for the official documentation.

#### 2b. GitHub issues and discussions

Search the library's repository for known problems, migration experiences and community solutions:

```bash
gh search issues "<core topic keywords>" --repo <owner/repo> --limit 10 --sort updated
gh search issues "<specific integration or migration terms>" --repo <owner/repo> --limit 10 --sort updated
```

Read the 3-5 most relevant results in full:

```bash
gh issue view <number> --repo <owner/repo> --comments
```

If the research spans several libraries ("integrate X with Y"), search each repository. Also look for blockers and for pull requests with migration or integration context:

```bash
gh search issues "<topic> blocker OR breaking OR regression" --repo <owner/repo> --limit 5 --sort updated
gh search prs "<topic>" --repo <owner/repo> --limit 5 --sort updated
```

If `gh` isn't available or authenticated, search the issues through the web instead, and say so in the report.

#### 2c. Codebase analysis

Scan the project for existing integration points, versions and patterns:

- **Versions:** the project's manifests and lock files (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, Gradle or CocoaPods files, whatever the project uses) for the current versions of the libraries involved.
- **Config:** existing configuration files for the tool or its ecosystem (build, bundler, framework and CI config).
- **Usage:** search the source for imports and uses of the library or tool.
- **Affected areas:** which modules, packages or features would change. `AGENTS.md`, `CLAUDE.md` or the README often map the project's structure.
- **Platform layers:** native, infrastructure or deployment code, when the change reaches them.

#### 2d. Web search (when needed)

Use web search for:

- recent write-ups of migration experiences;
- release notes and changelogs for major versions;
- platform compatibility (OS, runtime or browser version requirements);
- community guides that go beyond the official docs.

Skip it if the docs and GitHub issues already answer every sub-question.

### 3. Synthesize the findings

Cross-reference what the sources say. Look for:

- **Contradictions:** the docs say one thing, but the issues show it doesn't work that way.
- **Gaps:** questions none of the sources answer.
- **Existing foundation:** what the project already has that makes the change easier, or harder.

### 4. Write the report

Unless `--no-doc` was passed, save the report as `{kebab-topic-name}.md` in the project's research folder. Use the one the project already has (`docs/research/`, `.ai/research/`, `research/` or a folder its `AGENTS.md` / `CLAUDE.md` names). If it has none, ask once where reports should go, recommending `docs/research/`.

Use this structure:

```markdown
# Research: {Topic}

**Date:** {YYYY-MM-DD}
**Status:** {Feasible | Feasible with caveats | Needs further investigation | Not recommended}

## Summary

{2-3 sentences: what was researched, the key finding, and the overall recommendation.}

## Current state

{What the project already has in place: versions, config, existing integrations, affected areas.}

## Findings

### {Sub-question 1}

{What the docs say, what the community reports, any version requirements or constraints.}

### {Sub-question 2}

{Same structure.}

## Known issues and risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| {risk} | High/Medium/Low | {what can be done about it} |

## Integration path (high level)

{What would need to happen, in order: not a detailed plan, but enough to estimate the effort. Think chapters, not steps.}

1. {First major change}
2. {Second major change}

## Open questions

- {Questions the available sources couldn't answer}
- {Things that need hands-on testing or a team discussion}

## Sources

- {Links to the docs, issues, PRs and posts consulted}
```

### 5. Present it and suggest next steps

Show the findings. With `--no-doc`, present them inline in the same structure, without creating a file. Then suggest a next step that fits the status:

- **Feasible:** offer to turn the integration path into an implementation plan.
- **Feasible with caveats:** name the main risk and ask whether to dig deeper into it or move on to planning.
- **Needs further investigation:** say what couldn't be answered from docs and issues alone, and suggest a spike or prototype.
- **Not recommended:** explain why clearly, and suggest any alternatives that came up.
