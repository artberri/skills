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
