#!/usr/bin/env bash
# shellcheck disable=SC2015
# Persistence: accounts, settings and indexed data live on the volume and survive a recreate. This
# also pins down the fact the wrapper exists for -- once the first administrator exists, changing
# the password variable does not change the account -- so that it is a documented property rather
# than a surprise.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
umask 077
LOCAL_PASSWORD='local-test-only-kotaemon-password'

section "fresh stack"
compose down -v --remove-orphans >/dev/null 2>&1 || true
compose up -d --no-build
wait_for_code "$BASE_URL/" 200 600 || die "not ready"
for _ in $(seq 1 40); do [ "$(user_count)" = "1" ] && break; sleep 3; done
assert_eq "the administrator was created" "1" "$(user_count)"
assert_eq "with the supplied password" "1" "$(password_matches "$(sha256_of "$LOCAL_PASSWORD")")"

section "the database is on the volume"
mounts=$(docker inspect "$(compose ps -q kotaemon)" --format '{{range .Mounts}}{{.Destination}} {{end}}')
assert_contains "the application data directory is mounted" "/app/ktem_app_data" "$mounts"
files=$(compose exec -T kotaemon sh -c 'ls -1 /app/ktem_app_data/user_data' | tr -d '\r')
assert_contains "the account database is there" "sql.db" "$files"

section "recreate the container on the same volume"
compose down >/dev/null; compose up -d --no-build
wait_for_code "$BASE_URL/" 200 600 || die "not ready after recreate"

section "verify"
assert_eq "the account survived" "1" "$(user_count)"
assert_eq "and is still an administrator" "admin|1" "$(admin_row)"
assert_eq "the password is unchanged" "1" "$(password_matches "$(sha256_of "$LOCAL_PASSWORD")")"
assert_eq "no second account was created on the second boot" "1" "$(user_count)"

section "a changed password variable does not re-password the account"
# create_user returns early when the username already exists, so the variable is read only on the
# boot that creates the account. This is why the wrapper insists on a real password up front rather
# than letting a deployer fix it later.
compose down >/dev/null
img=$(compose config --images | head -1)
vol=$(docker volume ls -q --filter name=kotaemon-railway-test | head -1)
docker rm -f kota-rotate >/dev/null 2>&1 || true
docker run -d --name kota-rotate -e "KOTAEMON_ADMIN_PASSWORD=a-completely-different-password" \
  -e PORT=7870 -p 127.0.0.1:7870:7870 -v "${vol}:/app/ktem_app_data" "$img" >/dev/null
for _ in $(seq 1 200); do [ "$(http_code --max-time 5 "http://127.0.0.1:7870/" || true)" = "200" ] && break; sleep 3; done
rotated=$(docker exec kota-rotate python3 -c "
import sqlite3
con = sqlite3.connect('/app/ktem_app_data/user_data/sql.db')
tables = [r[0] for r in con.execute(\"select name from sqlite_master where type='table'\")]
t = next(t for t in tables if any(c[1]=='username_lower' for c in con.execute(f'pragma table_info({t})')))
print(list(con.execute(f'select count(*) from {t} where password=?', ('$(sha256_of "$LOCAL_PASSWORD")',)))[0][0])
" 2>/dev/null | tr -d '\r')
assert_eq "the original password still opens the account" "1" "$rotated"
docker rm -f kota-rotate >/dev/null
compose up -d --no-build; wait_for_code "$BASE_URL/" 200 600 || die "did not come back"
assert_eq "and the stack still works afterwards" "1" "$(user_count)"
summary
