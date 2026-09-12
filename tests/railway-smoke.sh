#!/usr/bin/env bash
# shellcheck disable=SC2015
# Public smoke test against a deployed instance.
#   tests/railway-smoke.sh https://your-app.up.railway.app
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
BASE_URL=${1:?usage: railway-smoke.sh https://domain}; BASE_URL=${BASE_URL%/}; export BASE_URL
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
host=${BASE_URL#https://}

section "TLS and routing"
# Railway's edge serves 404 for a few seconds while a deployment takes over, so wait rather than
# racing the cutover when this runs straight after a deploy.
wait_for_code "$BASE_URL/" 200 600 || true
assert_eq "the interface answers over https" "200" "$(http_code "$BASE_URL/")"
assert_contains "valid certificate" "SSL certificate verify ok" "$(curl -sv -o /dev/null "$BASE_URL/" 2>&1 || true)"
assert_contains "http -> https" "https://$host" "$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 20 "http://$host/")"

section "a stranger sees a login page and nothing else"
home=$(curl -s --max-time 30 "$BASE_URL/")
assert_not_contains "no upload panel is rendered" "Upload and Index" "$home"
assert_not_contains "no file collection is named" "File Collection" "$home"
api=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 -X POST -H 'Content-Type: application/json' \
  --data '{"data":[],"fn_index":0,"session_hash":"probe"}' "$BASE_URL/api/predict" || true)
case "$api" in 200) fail "an unauthenticated event call succeeded" ;; *) pass "an unauthenticated event call is not served ($api)" ;; esac

section "no gradio tunnel was published"
# KH_GRADIO_SHARE would print a *.gradio.live URL into the page and the logs. The wrapper refuses
# the variable, so nothing should reference that host.
assert_not_contains "no public gradio tunnel in the page" "gradio.live" "$home"
summary
