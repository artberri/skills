# To do

Work left for later, and things to come back to. Remove an item in the commit that finishes it.

## Add evals to the remaining skills, then make check.sh fail without them

These have no `evals/evals.json` yet: `address-pr-comments`, `ocr-review`, `execute-plan`, `create-plan`, `write-acceptance-criteria`, `capture-learnings`, `research`, `retro`, `setup-ocr` and `setup-review-docs`.

Once each has one, or is exempted explicitly (the user-invoked setup skills are the likeliest), turn the missing-evals warning in `scripts/check.sh` into a failure.
