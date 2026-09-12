#!/usr/bin/env bash
# shellcheck disable=SC2015
# Static validation: shell syntax, shellcheck, compose config, Dockerfile pins.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
cd "$REPO_ROOT"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

section "shell syntax"
for f in scripts/*.sh tests/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "parses: $f"; else fail "syntax error: $f"; fi
done

section "shellcheck"
if command -v shellcheck >/dev/null; then
  if shellcheck -s bash scripts/*.sh; then pass "shellcheck scripts"; else fail "shellcheck scripts"; fi
  if shellcheck -x -s bash tests/*.sh; then pass "shellcheck tests"; else fail "shellcheck tests"; fi
else
  echo "  SKIP  shellcheck not installed"
fi

section "compose"
if docker compose -f compose.yaml config >/dev/null; then pass "compose config"; else fail "compose config"; fi

section "dockerfile pins"
df=$(cat Dockerfile)
# Upstream publishes no release tags, so the digest is the only immutable reference there is.
assert_contains "upstream pinned by digest" 'ghcr.io/cinnamon/kotaemon:main-lite@sha256:' "$df"
assert_contains "entrypoint is the wrapper" 'ENTRYPOINT \["/usr/local/bin/kotaemon-railway-entrypoint"\]' "$df"
assert_contains "user management on by default in the image" 'KH_FEATURE_USER_MANAGEMENT=true' "$df"
assert_contains "the public gradio tunnel is off in the image" 'KH_GRADIO_SHARE=false' "$df"
assert_contains "demo mode is off in the image" 'KH_DEMO_MODE=false' "$df"
if grep -qE '^\s+KH_FEATURE_USER_MANAGEMENT_PASSWORD=' Dockerfile; then
  fail "a password is baked into the image"
else
  pass "no password in the image"
fi
if grep -qE '^\s+PORT=' Dockerfile; then fail "PORT must not be baked in; it would shadow the platform's PORT"; else pass "public port left to the entrypoint"; fi
# The "full" image bundles ollama and a local model; it is several times larger and needs a GPU to
# be worth anything.
if grep -E '^ARG KOTAEMON_IMAGE=' Dockerfile | grep -q 'main-full'; then fail "the full image is pinned; the lite image is the one that fits a CPU plan"; else pass "the lite image is pinned"; fi

section "the login cannot be configured away"
ep=$(cat scripts/entrypoint.sh)
assert_contains "requires an administrator password" 'missing required variable: KOTAEMON_ADMIN_PASSWORD' "$ep"
assert_contains "rejects the documented default" 'one of the values this wrapper exists to prevent' "$ep"
assert_contains "refuses to disable user management" 'With user management off kotaemon has no login' "$ep"
assert_contains "refuses demo mode" 'KH_DEMO_MODE=true launches the public demo application' "$ep"
assert_contains "refuses the public gradio tunnel" 'gradio.live tunnel' "$ep"
assert_contains "refuses SSO mode" 'KH_SSO_ENABLED=true starts a different application' "$ep"
assert_contains "forces the settings it validated" 'export KH_FEATURE_USER_MANAGEMENT=true' "$ep"
# Railway colours a log line by the stream it arrived on, so routine start-up messages written to
# stderr are shown to the deployer as errors.
if grep -q '^log()' scripts/entrypoint.sh && ! grep '^log()' scripts/entrypoint.sh | grep -q '>&2'; then
  pass "routine logs go to stdout"
else
  fail "log() writes to stderr; Railway would show every start-up line as an error"
fi
if grep '^fail()' scripts/entrypoint.sh | grep -q '>&2'; then
  pass "failures go to stderr"
else
  fail "fail() does not write to stderr"
fi

section "workflows"
# a stale image-override name from a copied workflow makes CI test the wrong image, and the failure
# looks like a missing local build rather than a configuration mistake
override=$(grep -oE '[A-Z_]*_RAILWAY_IMAGE' compose.yaml | head -1)
for wf in .github/workflows/*.yml; do
  if grep -q 'candidate' "$wf" && ! grep -q "$override" "$wf"; then
    fail "$wf tests a candidate image but never sets $override"
  else
    pass "image override name matches compose in $wf"
  fi
done
for wf in .github/workflows/*.yml; do
  if grep -qE 'uses: .*@[0-9a-f]{40}' "$wf" && ! grep -qE 'uses: .*@v[0-9]+\s*$' "$wf"; then
    pass "actions pinned by SHA in $wf"
  else
    fail "unpinned action in $wf"
  fi
done

section "no tracked secrets"
if git rev-parse --git-dir >/dev/null 2>&1; then
  if git grep -nIE '(BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|xox[baprs]-|sk-[A-Za-z0-9]{32,})' -- . >/dev/null 2>&1; then
    fail "credential pattern in tracked files"
  else
    pass "no credential patterns in tracked files"
  fi
  if git ls-files --error-unmatch .env >/dev/null 2>&1; then fail ".env is tracked"; else pass ".env not tracked"; fi
else
  echo "  SKIP  not a git checkout"
fi
summary
