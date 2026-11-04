#!/usr/bin/env bash
set -euo pipefail

# On main, everything pushed, with the timezone fix plus a new helper script
# that hard-codes an absolute path under a user's home folder.

# shellcheck source=skills/portable/commit/evals/fixtures/base.sh
. "$(dirname "$0")/base.sh"

commit_base "$1"
commit_fix_timezone
mkdir -p scripts
cat >scripts/tail-logs.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
tail -f /Users/jdoe/code/app/logs/activity.log
SH
chmod +x scripts/tail-logs.sh
