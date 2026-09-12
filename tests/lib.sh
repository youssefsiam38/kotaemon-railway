#!/usr/bin/env bash
# shellcheck disable=SC2015  # `cond && pass || fail` is intentional; pass/fail always succeed
# Shared helpers for kotaemon-railway tests. Source this file; do not execute it.
# Secrets are never echoed. Only names, lengths, and pass/fail results are printed.

: "${BASE_URL:=http://127.0.0.1:7860}"
: "${TEST_TIMEOUT:=300}"

TEST_TMP="${TEST_TMP:-$(mktemp -d)}"
export TEST_TMP
_PASS=0; _FAIL=0

pass() { _PASS=$((_PASS+1)); printf '  PASS  %s\n' "$*"; }
fail() { _FAIL=$((_FAIL+1)); printf '  FAIL  %s\n' "$*" >&2; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
section() { printf '\n== %s ==\n' "$*"; }
summary() { printf '\n%d passed, %d failed\n' "$_PASS" "$_FAIL"; [ "$_FAIL" -eq 0 ]; }

# here-strings, not pipes: `grep -q` exits on the first match and a pipe writer would get SIGPIPE,
# which `pipefail` reports as failure when the haystack is larger than the pipe buffer
assert_eq() { if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1: expected [$2] got [$3]"; fi; }
assert_contains() { if grep -q -- "$2" <<<"$3"; then pass "$1"; else fail "$1: missing [$2]"; fi; }
assert_not_contains() { if grep -q -- "$2" <<<"$3"; then fail "$1: found forbidden [$2]"; else pass "$1"; fi; }

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$@"; }

wait_for_code() {
  local url=$1 want=$2 timeout=${3:-$TEST_TIMEOUT} start code
  start=$(date +%s)
  while :; do
    code=$(http_code "$url" || true)
    [ "$code" = "$want" ] && return 0
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then printf 'timed out waiting for %s -> %s (last %s)\n' "$url" "$want" "$code" >&2; return 1; fi
    sleep 3
  done
}

wait_for_log() {
  local pattern=$1 service=${2:-kotaemon} timeout=${3:-180} start
  start=$(date +%s)
  while :; do
    compose logs --no-color "$service" 2>/dev/null | grep -q -- "$pattern" && return 0
    [ $(( $(date +%s) - start )) -ge "$timeout" ] && return 1
    sleep 2
  done
}

# kotaemon stores users in SQLite with a bare SHA-256 of the password, so the account table is where
# "is the documented default still in use?" can be answered exactly. The hash is computed here and
# compared inside the container; neither the password nor the hash is ever printed.
sha256_of() { printf '%s' "$1" | sha256sum | cut -d' ' -f1; }

# users_query SQL -> rows, run against the application's own database inside the container. The
# user table's name comes from SQLModel's class-name default, so it is discovered rather than
# assumed: any table carrying a `username_lower` column is the one.
users_query() {
  compose exec -T kotaemon python3 -c "
import sqlite3, sys
con = sqlite3.connect('/app/ktem_app_data/user_data/sql.db')
tables = [r[0] for r in con.execute(\"select name from sqlite_master where type='table'\")]
target = next((t for t in tables
               if any(c[1] == 'username_lower' for c in con.execute(f'pragma table_info({t})'))), None)
if target is None:
    sys.exit('no user table')
for row in con.execute(sys.argv[1].replace('USERS', target)):
    print('|'.join('' if v is None else str(v) for v in row))
" "$1" 2>/dev/null | tr -d '\r'
}

user_count() { users_query "select count(*) from USERS"; }
admin_row()  { users_query "select username, admin from USERS where username_lower='admin'"; }
# password_matches HASH -> the number of accounts with that hash. The hash itself is not printed.
password_matches() { users_query "select count(*) from USERS where password='$1'"; }

compose() { docker compose -f "$REPO_ROOT/compose.yaml" "$@"; }
