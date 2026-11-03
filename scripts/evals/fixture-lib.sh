# shellcheck shell=bash
# Helpers for eval fixtures. run.sh exports EVAL_LIB with this file's path, so
# a fixture sources it with `. "$EVAL_LIB"`. Source it, don't run it.
#
# A fixture is a script under a skill's evals/fixtures/ folder. run.sh calls it
# with one argument, an empty folder, and runs the eval in <folder>/repo. Git
# is already isolated (a throwaway global config, no signing) and `gh` is the
# stub in stubs/gh, whose state lives in $EVAL_STATE_DIR.

# eval_repo <root>: creates <root>/origin.git, a bare repository whose default
# branch is main, and <root>/repo, an empty repository on main with origin
# pointing at it.
eval_repo() {
	local root="$1"
	git init --quiet --bare --initial-branch=main "$root/origin.git"
	git init --quiet --initial-branch=main "$root/repo"
	git -C "$root/repo" remote add origin "$root/origin.git"
}

# eval_commit <repo> <message>: commits everything in the working tree.
eval_commit() {
	git -C "$1" add -A
	git -C "$1" commit --quiet -m "$2"
}

# eval_fake_pr <number> <branch> <title>: records an open pull request for
# <branch> against main, as if it had been opened on GitHub earlier.
eval_fake_pr() {
	jq -n --argjson number "$1" --arg branch "$2" --arg title "$3" '{
		number: $number,
		url: "https://github.com/example/app/pull/\($number)",
		headRefName: $branch,
		baseRefName: "main",
		title: $title,
		body: "",
		state: "OPEN"
	}' >"$EVAL_STATE_DIR/pr.json"
}
