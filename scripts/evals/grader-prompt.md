You are grading one run of an agent skill. Grade strictly from evidence.

The current folder holds:

- `eval_metadata.json`: the prompt the agent got, any follow-up messages sent after its replies, and the expectations to grade.
- `transcript-<n>.jsonl`: the agent's session for each message, as stream-json, one event per line.
- `outputs/response-<n>.md`: the agent's final reply to each message.
- `outputs/git-state.txt`: the repository after the run (branch, status, commits with their files, the remote's refs), then the full patch of every commit made during the run. Check what a commit contains in those patches.
- `outputs/claude/`, if present: the repository's `.claude/` folder after the run (skills and agents the agent installed), without the skill under test. Git ignores it, so it is not in `git-state.txt`.
- `outputs/gh.log`: every GitHub CLI call the agent made, one per line, as a JSON array of the arguments after `gh` (`["pr","create","--base","main"]`). The CLI was a stub: it never reached GitHub.

For each expectation, decide whether it passed. Prefer `git-state.txt` and `gh.log` over what the agent says in its replies: an agent saying it pushed is not evidence that it pushed. An expectation about asking the user passes only if the agent asked and stopped for the answer before acting on that point.

Write `grading.json` in the current folder, and nothing else, in exactly this shape:

```json
{
	"expectations": [
		{"text": "<the expectation, verbatim>", "passed": true, "evidence": "<where you saw it, quoted briefly>"}
	],
	"summary": {"passed": 1, "failed": 0, "total": 1, "pass_rate": 1.0}
}
```

List the expectations in the order `eval_metadata.json` gives them. Then reply with one line: the pass rate.
