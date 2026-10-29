# OCR review hook

`ocr-review-offer.sh` is an optional Claude Code `PostToolUse` hook. After `gh pr create`, or a `git push` to a PR the `ocr-review` skill has already reviewed, it tells Claude to run the review without asking. It stays quiet for pushes that only merge the base branch, and prompts once per PR head.

It needs `jq`, `gh` and, for pushes, `node`. Without them it does nothing.

## Turning it on

Add it to a `settings.json`: the project's `.claude/settings.json` for one repo, or your user settings for every repo. Point `command` at the script inside the installed skill folder, for example:

```json
{
	"hooks": {
		"PostToolUse": [
			{
				"matcher": "Bash",
				"hooks": [
					{
						"type": "command",
						"command": "~/.claude/skills/ocr-review/hooks/ocr-review-offer.sh"
					}
				]
			}
		]
	}
}
```

Set `OCR_REVIEW_OFFER=0` in the environment to turn it off without editing settings.
