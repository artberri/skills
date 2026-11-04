#!/usr/bin/env bash
set -euo pipefail

# A small Node HTTP API on main, all of it committed and pushed, with what
# create-plan's markers ask about easy to find: plans in docs/plans/, GitHub
# issues referenced as #<number>, and HTTP routes as its only public surface.
# No templates sit next to the installed adapt-skill, as after `npx skills add`.

# shellcheck source=scripts/evals/fixture-lib.sh
. "$EVAL_LIB"

eval_repo "$1"
cd "$1/repo"

cat >package.json <<'EOF'
{
	"name": "todo-api",
	"version": "1.0.0",
	"type": "module",
	"scripts": {
		"start": "node src/server.js",
		"test": "node --test"
	}
}
EOF
cat >AGENTS.md <<'EOF'
# todo-api

An HTTP API for to-do lists, built on Node's `http` module.

- Routes live in `src/routes/`, one file per resource. They are the only public surface: there is no UI, no events and no database schema (data is kept in memory).
- Work is tracked in GitHub issues; reference them as `#<number>` in commit subjects.
- Implementation plans live in `docs/plans/`; finished ones move to `docs/plans/done/`.
- Run the tests with `npm test`.
EOF
mkdir -p src/routes docs/plans/done
cat >src/server.js <<'EOF'
import { createServer } from "node:http";
import { todos } from "./routes/todos.js";

createServer(todos).listen(3000);
EOF
cat >src/routes/todos.js <<'EOF'
const items = [];

export function todos(req, res) {
	if (req.method === "GET" && req.url === "/todos") {
		res.setHeader("content-type", "application/json");
		res.end(JSON.stringify(items));
		return;
	}
	res.statusCode = 404;
	res.end();
}
EOF
cat >docs/plans/done/2026-10-01-list-todos.md <<'EOF'
# List to-dos (#3)

## Phase 1: GET /todos

Return every to-do as JSON.
EOF
eval_commit . "feat: list to-dos with GET /todos (#3)"

git push --quiet -u origin main
