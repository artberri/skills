#!/usr/bin/env bash
set -euo pipefail

# On main, everything pushed, with the timezone fix uncommitted. The
# repository signs its commits, and the signing program always fails, as it
# would with a locked or missing key.

# shellcheck source=skills/portable/commit/evals/fixtures/base.sh
. "$(dirname "$0")/base.sh"

commit_base "$1"
commit_fix_timezone
cat >"$1/fake-gpg" <<'SH'
#!/usr/bin/env bash
echo "gpg: signing failed: No secret key" >&2
exit 2
SH
chmod +x "$1/fake-gpg"
git config commit.gpgsign true
git config gpg.program "$1/fake-gpg"
