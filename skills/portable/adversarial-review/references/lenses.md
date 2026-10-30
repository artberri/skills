# Focus areas

Each council reviewer gets one focus area. It decides where the reviewer digs deepest; every reviewer still reports anything else it finds.

## Catalog

### 1. Concurrency and races

Timers, listeners, subscriptions, async chains, concurrent requests, jobs and workers. Look for: code that assumes sequential execution but can interleave, missing locks or guards, closures holding stale state, handlers that fire during teardown, the same operation triggered twice.

### 2. Edge cases and boundaries

Missing data, null or empty values, first run against steady state, boundary values, type coercion. Look for: assumptions about data shape that nothing checks, off-by-one errors, behaviour when optional fields are absent, a new user's path against a returning user's.

### 3. Lifecycle and cleanup

Start-up, shutdown, cancellation, timeouts, restarts, a process or app killed mid-flight. Look for: subscriptions, timers, connections or files opened and never released, cleanup missing on one exit path (success, failure, timeout, cancel), state left behind by a crash, behaviour when something restarts quickly.

### 4. Error handling and recovery

Error paths, retries, fallbacks, error states shown to users. Look for: errors caught and swallowed, retries without backoff or a limit, failures that leave things half done, an error state the user can't get out of.

### 5. State coordination

State shared across components, services or instances; caches; optimistic updates; derived data. Look for: copies of state that drift apart, cache invalidation gaps, optimistic updates that don't roll back on failure, derived values that don't update when their source changes.

### 6. Data integrity and contracts

API contracts, types at boundaries, transformations, serialisation, migrations. Look for: responses that may not match the expected shape, transformations that lose data, serialisation that doesn't round-trip, casts that skip real validation, a schema change that breaks existing data or callers.

### 7. Performance and resource use

Hot paths, unbounded growth, expensive work repeated. Look for: queries in loops, collections that grow and are never pruned, heavy computation on every call or render, memory or handle leaks, missing pagination or limits.

### 8. Security and input validation

User input, authentication and authorisation, trust boundaries. Look for: unvalidated input reaching queries, shells, file paths or HTML; missing permission checks on protected paths; secrets in logs or responses; data crossing a trust boundary without sanitising.

### 9. Cross-references and consistency

For skills, prompts and docs. Look for: references to files, skills, sections or commands that don't exist or were renamed; descriptions that contradict the instructions; step numbers that skip or repeat; two places in the same file that disagree.

### 10. Completeness and gaps

For skills, prompts and docs. Look for: instructions that assume context the agent won't have (a subagent has no conversation), flags or modes mentioned but never wired into the steps, tools or scripts used with no fallback when missing, no answer for what happens when the user says no or gives unexpected input.

### 11. Triggering

For skills. Look for: common phrasings that should trigger the skill but aren't in its description, descriptions so broad they steal from other skills, overlapping triggers where the wrong skill fires, a description that promises what the steps don't deliver.

## Choosing areas

- **Code:** always include edge cases and boundaries, the area that finds the most. A state machine gets concurrency, state coordination and edge cases; an API integration gets data integrity, error handling and edge cases.
- **Skills, prompts and docs:** always include cross-references and consistency, the most common failure. Add completeness and triggering.
- **More reviewers:** with four or five, add one or two areas that are less obvious, to catch surprises. With six or more, overlap is fine: independent agreement is a strong signal.
