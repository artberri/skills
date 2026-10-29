<One paragraph: what this repository is, its main languages and frameworks, and anything about its data or users that raises the stakes of a defect.>

Before raising any finding, read these files:

- <path to KNOWN_NON_ISSUES.md>: settled conventions. A finding that matches an entry there is not a defect; do not raise it.
- <path to PRE_PR_REVIEW.md>: the defect types this repo prioritises. The "Always" list applies to every change.

Check these against the diff: scan their headings and read only the entries for areas the change touches.

- <path to FOOTGUNS.md>: runtime pitfalls that pass review and type checks.

Conventions from <AGENTS.md or CLAUDE.md> that look like defects to an outside reviewer but are deliberate: <short list>.
