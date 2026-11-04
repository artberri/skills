#!/usr/bin/env bash
set -euo pipefail

# A Node project on main, with a feature/discount branch that adds discount().
# The branch has a planted bug for the reviewer to find: a percent above 100
# isn't capped, so the total goes negative, though the outcomes say it never
# should. Everything is committed and pushed; nothing is left uncommitted.

# shellcheck source=scripts/evals/fixture-lib.sh
. "$EVAL_LIB"

eval_repo "$1"
cd "$1/repo"

cat >package.json <<'JSON'
{
	"name": "shop",
	"version": "1.0.0",
	"type": "module",
	"scripts": {
		"test": "node --test"
	}
}
JSON
mkdir -p src
cat >src/cart.js <<'JS'
export function total(items) {
	return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
JS
eval_commit . "feat: add cart total"
git push --quiet -u origin main

git switch --quiet -c feature/discount
cat >>src/cart.js <<'JS'

export function discount(amount, percent) {
	if (percent < 0) {
		throw new RangeError("percent must not be negative");
	}
	return amount - (amount * percent) / 100;
}
JS
eval_commit . "feat: add percentage discounts"
git push --quiet -u origin feature/discount
