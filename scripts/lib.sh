# shellcheck shell=bash
# Helpers shared by the scripts in this folder. Source it, don't run it.

# Prints the value of a top-level frontmatter field from a SKILL.md or an
# agent file.
frontmatter_field() {
	awk -v key="$2" '
		NR == 1 && $0 != "---" { exit }
		NR > 1 && $0 == "---" { exit }
		NR > 1 && index($0, key ":") == 1 {
			sub("^" key ":[ \t]*", "")
			print
			exit
		}
	' "$1"
}

# Prints the whole value of a top-level frontmatter field on one line, without
# a trailing newline: a ">" or "|" block with its lines joined by spaces, a
# quoted value without its quotes. Enough to measure a value, not a YAML
# parser.
frontmatter_text() {
	awk -v key="$2" '
		NR == 1 && $0 != "---" { exit }
		NR > 1 && $0 == "---" { exit }
		in_value && /^[ \t]*$/ { next }
		in_value && /^[ \t]/ {
			sub(/^[ \t]+/, "")
			text = text (text == "" ? "" : " ") $0
			next
		}
		in_value { exit }
		NR > 1 && index($0, key ":") == 1 {
			text = $0
			sub("^" key ":[ \t]*", "", text)
			if (text ~ /^[>|][-+]?[ \t]*$/) {
				block = 1
				text = ""
			}
			in_value = 1
		}
		END {
			if (!block && (text ~ /^".*"$/ || text ~ /^\047.*\047$/))
				text = substr(text, 2, length(text) - 2)
			printf "%s", text
		}
	' "$1"
}

# Prints the value of a field under the frontmatter's metadata map, without
# quotes, or nothing.
metadata_field() {
	awk -v key="$2" '
		NR == 1 && $0 != "---" { exit }
		NR > 1 && $0 == "---" { exit }
		/^metadata:[ \t]*$/ { in_meta = 1; next }
		in_meta && /^[^ \t]/ { in_meta = 0 }
		in_meta && $0 ~ "^[ \t]+" key ":" {
			sub("^[ \t]+" key ":[ \t]*", "")
			gsub(/["]/, "")
			print
			exit
		}
	' "$1"
}

# Prints each frontmatter line whose value is an unquoted one-line scalar
# containing ": " or " #". Claude Code and Codex accept these; strict YAML
# parsers, like the one Copilot CLI uses, read the first as a nested mapping
# and the second as a comment. Lines inside a ">" or "|" block are skipped.
frontmatter_unsafe_lines() {
	awk '
		NR == 1 && $0 != "---" { exit }
		NR > 1 && $0 == "---" { exit }
		NR == 1 { next }
		{
			match($0, /^[ \t]*/)
			indent = RLENGTH
		}
		in_block && (indent > block_indent || $0 ~ /^[ \t]*$/) { next }
		{ in_block = 0 }
		match($0, /^[ \t]*[A-Za-z0-9_-]+:[ \t]+/) {
			value = substr($0, RLENGTH + 1)
			if (value ~ /^[>|]/) {
				in_block = 1
				block_indent = indent
				next
			}
			if (value ~ /^["\047\[{]/) next
			if (value ~ /: / || value ~ /:$/ || value ~ / #/) print NR ": " $0
		}
	' "$1"
}

# Prints the space-separated agent names a SKILL.md lists under
# metadata.agents, or nothing.
skill_agents() {
	metadata_field "$1" agents
}

# Succeeds if the file or folder contains a CUSTOMIZE marker. Only a marker
# at the start of a line counts, so skills and agents can quote the syntax
# inline (as adapt-skill does).
has_markers() {
	grep -rqE '^[[:space:]]*<!-- CUSTOMIZE:' "$1"
}
