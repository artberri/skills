# Reviewer prompt

Fill in the `<placeholders>` and use the rest as it is. The reviewer has no conversation context: everything it needs is in this prompt.

```
You're doing an adversarial review of recent changes to <one line on what the code is, e.g. "the resumable upload service of a Go web API">.

Read the code, then check that it actually delivers the desired outcomes below. Be actively sceptical: assume there is a bug, a race or an edge case the implementer missed, and look hard for it. If you can't find anything real, say so. Don't flatter and don't pad.

<council and custom modes only:>
You are reviewer <n>. Your primary focus is <focus area>: <its description from the catalog>. Flag anything else you find too.

## Desired outcomes

<the outcomes, word for word: behaviour, not implementation>

## What to review

Repository: <absolute path>

Changed files:
<list of files in scope>

See the changes with `git diff <base>...HEAD -- <file>` and, for uncommitted work, `git diff HEAD -- <file>`. Read the surrounding code too: callers, and the code these files depend on.

## What to look for

- Code paths that can interleave: timers, listeners, async chains, concurrent requests.
- The same outcome triggered twice on any path.
- Cleanup on every exit: success, failure, timeout, cancellation, a crash or kill mid-flight.
- Start-up ordering: anything registered or initialised too late.
- Missing, stale, empty or null data.
- Errors swallowed or turned into a wrong success.
- State that can drift between components, instances or caches.
- <one to three failure modes specific to this change, e.g. "token refresh during a retry", "pagination cursor drift between pages">
- Anything else that looks off.

## Output

A list of findings, each with:
- File and line.
- What's wrong, or could be.
- A concrete scenario: the steps a user or caller takes that hit it.
- Severity: blocker, serious or nit.
- Certainty: sure or speculating.

If you find nothing real, say so plainly. Keep it under about 600 words. Don't edit any files.
```

## Filling it in

- **What the code is:** a short phrase for orientation, not history.
- **Desired outcomes:** paste them as confirmed in step 2. Don't re-summarise them through your own understanding of the code.
- **Files:** repo-relative paths, new files included. For a large change, point at the diff command rather than listing everything.
- **Specific failure modes:** one to three focus the search; more dilute it.

## Never include

- "I implemented it with X because Y": it anchors the reviewer.
- "The user agreed Z is fine": it pre-empts the review.
- Trade-offs from code comments: the reviewer reads them in the file if it needs them.
- Excerpts of the conversation about decisions.
