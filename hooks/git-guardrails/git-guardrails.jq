# Reads a PreToolUse(Bash) hook payload and prints a deny decision when the
# command runs git in a way the skills forbid. Prints nothing otherwise.
#
# This catches slips, not someone set on getting round it: a git command
# hidden in a variable, `eval` or `bash -c "..."` is not seen.

def falsy: test("^(false|no|off|0)$"; "i");

# Drops the body of every heredoc, so a commit message or file written with
# `<<EOF` can mention the forbidden options.
def strip_heredocs:
	reduce split("\n")[] as $line ({out: [], delims: []};
		if (.delims | length) > 0 then
			if ($line | sub("^\\t+"; "")) == .delims[0] then .delims |= .[1:] else . end
		else
			.out += [$line]
			| .delims += [$line | scan("(?<!<)<<(?!<)-?\\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\\1") | .[1]]
		end)
	| .out | join("\n");

# A quoted string with whitespace in it is a message or a nested script, not
# an option, so it becomes a placeholder. One without (`"commit.gpgsign=false"`)
# loses its quotes and is checked like any other word.
def unquote:
	gsub("'(?<a>[^']*)'|\"(?<b>(?:[^\"\\\\]|\\\\.)*)\"";
		(.a // .b) as $s | if $s == "" or ($s | test("\\s")) then "_" else $s end);

def strip_comments: gsub("(?m)(^|\\s)#.*$"; "");

def segments:
	strip_heredocs | gsub("\\\\\\n"; " ") | unquote | strip_comments
	| [splits("[;&|()\\n`]+")]
	| map([splits("\\s+")] | map(select(. != "")))
	| map(select(length > 0));

# Drops what can come before the program name: variable assignments and
# wrappers like `env` or `sudo`.
def program_words:
	until(length == 0 or (((.[0] | test("^[A-Za-z_][A-Za-z0-9_]*=")) or (.[0] | IN("env", "command", "exec", "time", "nohup", "sudo"))) | not); .[1:]);

# Splits a git call into {config: [-c values], sub, args}.
def parse_git:
	{config: [], rest: .[1:]}
	| until((.rest | length) == 0 or (.rest[0] | startswith("-") | not);
		if .rest[0] == "-c" then .config += [.rest[1] // ""] | .rest |= .[2:]
		elif .rest[0] | IN("-C", "--git-dir", "--work-tree", "--namespace", "--config-env", "--super-prefix") then .rest |= .[2:]
		else .rest |= .[1:] end)
	| {config, sub: (.rest[0] // ""), args: (.rest[1:] // [])};

# True when a short option cluster (`-vA`) holds the letter $flag before any
# letter in $takes_value, whose value would be the rest of the cluster.
def short_has($flag; $takes_value):
	test("^-[A-Za-z]+$") and
	(.[1:] | split("") | until(length == 0 or .[0] == $flag or (.[0] as $c | $takes_value | contains($c)); .[1:]) | length > 0 and .[0] == $flag);

def reasons:
	.config as $config | .sub as $sub | .args as $args
	| (if any($config[]; test("^commit\\.gpgsign(=|$)"; "i") and (sub("^[^=]*=?"; "") | falsy))
		or any($args[]; . == "--no-gpg-sign")
		or ($sub == "config" and (
			(any($args[]; IN("--unset", "--unset-all")) and any($args[]; test("^commit\\.gpgsign$"; "i")))
			or any(range(0; $args | length); . as $i | ($args[$i] | test("^commit\\.gpgsign$"; "i")) and (($args[$i + 1] // "") | falsy))))
		then "Commits must be signed: don't pass --no-gpg-sign or turn commit.gpgsign off. If signing fails, stop and tell the user."
		else empty end),
	(if any($args[]; . == "--no-verify") or ($sub == "commit" and any($args[]; short_has("n"; "mFCct")))
		then "Don't skip git hooks with --no-verify (or git commit -n): fix what the hook reports, or tell the user."
		else empty end),
	(if $sub == "add" and any($args[]; IN("-A", "--all", "--no-ignore-removal", ".", "./", ":/", ":/.", "*") or short_has("A"; ""))
		then "Stage files by explicit path: git add -A, --all, . and :/ can sweep in secrets and unrelated changes."
		else empty end),
	(if $sub == "push" and any($args[]; . == "--force" or short_has("f"; "o") or startswith("+"))
		then "Don't force-push with --force, -f or a +refspec: use --force-with-lease, so commits you haven't seen are not overwritten. If the push is rejected, stop and ask the user."
		else empty end);

[.tool_input.command // "" | segments[] | program_words
	| select(length > 0 and (.[0] | test("(^|/)git$")))
	| parse_git | reasons]
| unique
| if length > 0 then {
	hookSpecificOutput: {
		hookEventName: "PreToolUse",
		permissionDecision: "deny",
		permissionDecisionReason: ((["Blocked by the git-guardrails hook."] + . + ["If the user explicitly wants this, ask them to run the command themselves."]) | join(" "))
	}
} else empty end
