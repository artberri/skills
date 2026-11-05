# Git guardrails hook

`git-guardrails.sh` is an optional `PreToolUse` hook for Claude Code and GitHub Copilot CLI. Codex doesn't run a plugin's hooks, so it doesn't apply there. It turns the git rules the skills state in prose into hard denials, so they hold even when the model slips. It blocks a Bash command that:

- stages everything: `git add -A`, `--all`, `.`, `:/` or `*`. Stage by explicit path instead.
- force-pushes: `git push --force`, `-f` or a `+refspec`. `--force-with-lease` is allowed.
- skips signing: `--no-gpg-sign`, `-c commit.gpgsign=false`, or `git config` turning `commit.gpgsign` off or unsetting it.
- skips hooks: `--no-verify`, or `git commit -n`.

The denial tells Claude why, and to ask you to run the command yourself if you really want it (type `! <command>` in the prompt).

It looks only at the git commands themselves: a commit message, heredoc or comment that mentions these options is fine. It catches slips, not someone set on getting round it: a git command inside `bash -c "..."`, `eval` or a variable is not checked.

"Don't commit or push unless asked" stays a written rule: a hook can't tell whether you asked.

It needs `jq`. Without it the hook does nothing. Run `test.sh` after changing `git-guardrails.jq`.

## Turning it on

**From the `artberri-skills` plugin:** the plugin registers the hook, but it stays off until `ARTBERRI_GIT_GUARDRAILS` is `1`. In Claude Code, set it in the `env` block of a `settings.json`: the project's `.claude/settings.json` for one repo, or your user settings for every repo. In Copilot CLI, export it in the shell you start `copilot` from.

```json
{
	"env": {
		"ARTBERRI_GIT_GUARDRAILS": "1"
	}
}
```

**From a copy of this folder:** add the hook yourself, pointing `command` at the script. It runs unless `ARTBERRI_GIT_GUARDRAILS` is `0`.

```json
{
	"hooks": {
		"PreToolUse": [
			{
				"matcher": "Bash",
				"hooks": [
					{
						"type": "command",
						"command": "~/.claude/hooks/git-guardrails/git-guardrails.sh"
					}
				]
			}
		]
	}
}
```
