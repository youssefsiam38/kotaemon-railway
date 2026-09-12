#!/usr/bin/env bash
# shellcheck disable=SC2015
# Local smoke test. Run `docker compose build` first (CI does), or set KOTAEMON_RAILWAY_IMAGE.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
mkdir -p "$REPO_ROOT/test-output"; METRICS="$REPO_ROOT/test-output/metrics.txt"
LOCAL_PASSWORD='local-test-only-kotaemon-password'
umask 077

section "fresh stack (empty volume)"
compose down -v --remove-orphans >/dev/null 2>&1 || true
t0=$(date +%s); compose up -d --no-build
wait_for_code "$BASE_URL/" 200 600 && pass "the interface answers" || { compose logs --no-color kotaemon | tail -40; die "never became ready"; }
cold=$(( $(date +%s) - t0 )); echo "cold_start_seconds=$cold" | tee "$METRICS"

section "start-up"
wait_for_log "administrator" kotaemon 120 || true
logs=$(compose logs --no-color kotaemon)
assert_contains "the administrator was announced" "administrator \"admin\" will be created on first start" "$logs"
assert_contains "only the password's length was reported" "password length ${#LOCAL_PASSWORD}" "$logs"
assert_not_contains "password not in logs" "$LOCAL_PASSWORD" "$logs"
assert_not_contains "no ollama noise from the upstream launcher" "ollama: not found" "$logs"

section "the documented default password is not in use"
# This is the whole point of the wrapper. flowsettings.py defaults both the administrator's name and
# password to "admin", and upstream's README documents it, so a stock deployment on a public URL has
# a published login. kotaemon stores a bare SHA-256 of the password, so the question can be answered
# exactly, without the password or the hash ever being printed.
wait_for_log "administrator" kotaemon 60 || true
for _ in $(seq 1 40); do [ "$(user_count)" = "1" ] && break; sleep 3; done
assert_eq "exactly one account exists" "1" "$(user_count)"
assert_eq "and it is an administrator named admin" "admin|1" "$(admin_row)"
assert_eq "the supplied password is the one that works" "1" "$(password_matches "$(sha256_of "$LOCAL_PASSWORD")")"
assert_eq "the default password \"admin\" does not" "0" "$(password_matches "$(sha256_of admin)")"

section "what a stranger can and cannot reach"
# Gradio ships the whole interface definition to every visitor and then hides tabs client-side from
# server-side state, so every tab label is in the page whether or not anyone has signed in. That is
# a property of the framework, not a data leak, and SECURITY.md says so plainly. These assertions
# pin down the part that matters: the definition is public, the data is not.
home=$(curl -s --max-time 30 "$BASE_URL/")
assert_eq "the interface is served" "200" "$(http_code "$BASE_URL/")"
assert_contains "the page is kotaemon's own interface" "gradio" "$home"
assert_not_contains "no password reaches the page" "$LOCAL_PASSWORD" "$home"
assert_eq "gradio's own config endpoint answers" "200" "$(http_code "$BASE_URL/config")"
# An event call carries no session, which is what an unauthenticated caller has, and the handlers
# work against a user id that is then empty.
api=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 -X POST -H 'Content-Type: application/json' \
  --data '{"data":[],"fn_index":0,"session_hash":"probe"}' "$BASE_URL/api/predict" || true)
case "$api" in 200) fail "an unauthenticated event call succeeded" ;; *) pass "an unauthenticated event call is refused ($api)" ;; esac

section "fail-fast validation"
img=$(compose config --images | head -1)
run_img() { docker run --rm "$@" "$img" >"$TEST_TMP/ff.log" 2>&1; }
if run_img; then fail "should fail without a password"; else pass "exits without KOTAEMON_ADMIN_PASSWORD"; fi
assert_contains "explains why the password matters before the first start" "cannot be re-passworded afterwards" "$(cat "$TEST_TMP/ff.log")"
if run_img -e KOTAEMON_ADMIN_PASSWORD=short; then fail "should reject a short password"; else pass "rejects a short password"; fi
assert_contains "states the length rule" "at least 12 characters" "$(cat "$TEST_TMP/ff.log")"
if run_img -e KOTAEMON_ADMIN_PASSWORD=admin; then fail "should reject the default password"; else pass "rejects the password \"admin\""; fi
if run_img -e "KOTAEMON_ADMIN_PASSWORD=$LOCAL_PASSWORD" -e KH_FEATURE_USER_MANAGEMENT=false; then fail "should refuse to disable user management"; else pass "refuses KH_FEATURE_USER_MANAGEMENT=false"; fi
assert_contains "explains the login rule" "kotaemon has no login at all" "$(cat "$TEST_TMP/ff.log")"
if run_img -e "KOTAEMON_ADMIN_PASSWORD=$LOCAL_PASSWORD" -e KH_DEMO_MODE=true; then fail "should refuse demo mode"; else pass "refuses KH_DEMO_MODE=true"; fi
if run_img -e "KOTAEMON_ADMIN_PASSWORD=$LOCAL_PASSWORD" -e KH_GRADIO_SHARE=true; then fail "should refuse the public tunnel"; else pass "refuses KH_GRADIO_SHARE=true"; fi
assert_contains "explains the tunnel rule" "bypasses the platform entirely" "$(cat "$TEST_TMP/ff.log")"
if run_img -e "KOTAEMON_ADMIN_PASSWORD=$LOCAL_PASSWORD" -e KH_SSO_ENABLED=true; then fail "should refuse SSO mode"; else pass "refuses KH_SSO_ENABLED=true"; fi
if run_img -e "KOTAEMON_ADMIN_PASSWORD=$LOCAL_PASSWORD" -e PORT=not-a-port; then fail "should reject a non-numeric port"; else pass "rejects a non-numeric PORT"; fi
assert_not_contains "no secret echoed" "$LOCAL_PASSWORD" "$(cat "$TEST_TMP/ff.log")"

section "graceful shutdown (SIGTERM)"
# Gradio does not unwind on its own, so the entrypoint gives it a grace period and then stops it.
# Without that the runtime sends SIGKILL and every ordinary stop is recorded as exit 137.
t1=$(date +%s); compose stop -t 40 kotaemon; dur=$(( $(date +%s)-t1 ))
code=$(docker inspect --format '{{.State.ExitCode}}' "$(compose ps -a -q kotaemon)")
[ "$dur" -lt 40 ] && pass "stopped in ${dur}s without SIGKILL" || fail "stop took ${dur}s"
case "$code" in 0|143) pass "exit status after SIGTERM is $code" ;; *) fail "unexpected exit status $code" ;; esac
compose start kotaemon; wait_for_code "$BASE_URL/" 200 600 && pass "restarted" || die "did not restart"

section "image metadata"
assert_eq "architecture" "amd64" "$(docker image inspect "$img" --format '{{.Architecture}}')"
labels=$(docker image inspect "$img" --format '{{json .Config.Labels}}')
for l in org.opencontainers.image.source org.opencontainers.image.revision org.opencontainers.image.version io.kotaemon-railway.upstream.version; do
  assert_contains "label $l" "\"$l\"" "$labels"
done
assert_contains "upstream licence shipped" "Apache License" "$(compose exec -T kotaemon head -1 /usr/share/licenses/kotaemon-railway/KOTAEMON-LICENSE | tr -d '\r')"

section "metrics"
{ echo "image_bytes=$(docker image inspect "$img" --format '{{.Size}}')"
  docker stats --no-stream --format '{{.Name}} mem={{.MemUsage}}' | grep kotaemon-railway-test | sed 's/^/mem_/'; } | tee -a "$METRICS"
summary
