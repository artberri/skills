# OCR review hook

`ocr-review-offer.sh` is an optional Claude Code `PostToolUse` hook. After `gh pr create`, or a `git push` to a PR the `ocr-review` skill has already reviewed, it tells Claude to run the review without asking. It stays quiet for pushes that only merge the base branch, and prompts once per PR head.

It needs `jq`, `gh` and, for pushes, `node`. Without them it does nothing.

## Turning it on

**From the `artberri` plugin:** the plugin registers the hook, but it stays off until `OCR_REVIEW_OFFER` is `1`. Set it in the `env` block of a `settings.json`: the project's `.claude/settings.json` for one repo, or your user settings for every repo.

```json
{
	"env": {
		"OCR_REVIEW_OFFER": "1"
	}
}
```

**From a copy of the skill:** add the hook yourself, pointing `command` at the script inside the installed skill folder. It runs unless `OCR_REVIEW_OFFER` is `0`.

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
