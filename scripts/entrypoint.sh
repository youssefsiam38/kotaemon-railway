#!/bin/bash
# kotaemon-railway entrypoint.
#
#   1. validate variables (names only; values are never printed)
#   2. refuse the settings that would remove the login
#   3. hand the supplied administrator password to kotaemon and exec the application
#
# kotaemon creates its first account while the interface is being built, from
# KH_FEATURE_USER_MANAGEMENT_ADMIN and KH_FEATURE_USER_MANAGEMENT_PASSWORD, and flowsettings.py
# defaults both to "admin". `create_user` returns early once the username exists, so that credential
# is fixed at first boot and changing the variable later does nothing. The wrapper therefore insists
# on a real password before the first boot, which is the only moment it can still matter.
set -uo pipefail

# Informational lines go to stdout and only failures to stderr. Railway derives a log's severity
# from the stream it arrived on, so a start-up message written to stderr is shown to the deployer
# in red as though something had gone wrong.
log()  { printf '[kotaemon-railway] %s\n' "$*"; }
fail() { printf '[kotaemon-railway] FATAL: %s\n' "$*" >&2; exit 1; }

: "${KOTAEMON_ADMIN_USERNAME:=admin}"
: "${KH_APP_DATA_DIR:=/app/ktem_app_data}"

# kotaemon's Gradio server is the public listener; there is no proxy. Railway probes its healthcheck
# against PORT (8080 when unset), so the listener has to take that value.
PUBLIC_PORT="${PORT:-7860}"
case "$PUBLIC_PORT" in
  ''|*[!0-9]*) fail "PORT must be a number, got \"$PUBLIC_PORT\"" ;;
esac

[ -n "${KOTAEMON_ADMIN_PASSWORD:-}" ] || fail "missing required variable: KOTAEMON_ADMIN_PASSWORD. kotaemon creates its first administrator with the password \"admin\" unless it is told otherwise, and that account cannot be re-passworded afterwards from the environment. Set a password before the first start."
[ "${#KOTAEMON_ADMIN_PASSWORD}" -ge 12 ] || fail "KOTAEMON_ADMIN_PASSWORD must be at least 12 characters"
case "$KOTAEMON_ADMIN_PASSWORD" in
  admin|Admin|ADMIN|password|changeme) fail "KOTAEMON_ADMIN_PASSWORD is one of the values this wrapper exists to prevent. Choose something else." ;;
esac
[ -n "$KOTAEMON_ADMIN_USERNAME" ] || fail "KOTAEMON_ADMIN_USERNAME must not be empty"

# Three upstream settings each remove the login completely. None of them has a safe meaning on a
# public hostname, so the wrapper refuses rather than warning.
if [ "${KH_FEATURE_USER_MANAGEMENT:-true}" != "true" ]; then
  fail "KH_FEATURE_USER_MANAGEMENT is \"${KH_FEATURE_USER_MANAGEMENT}\". With user management off kotaemon has no login at all, and this deployment has a public URL. Remove the variable."
fi
if [ "${KH_DEMO_MODE:-false}" = "true" ]; then
  fail "KH_DEMO_MODE=true launches the public demo application, which sets KH_FEATURE_USER_MANAGEMENT=false and leaves the instance open. Remove the variable."
fi
if [ "${KH_GRADIO_SHARE:-false}" = "true" ]; then
  fail "KH_GRADIO_SHARE=true asks Gradio to publish a *.gradio.live tunnel to this container. That URL bypasses the platform entirely and is not something this template can protect. Remove the variable."
fi
if [ "${KH_SSO_ENABLED:-false}" = "true" ]; then
  fail "KH_SSO_ENABLED=true starts a different application (sso_app.py) whose identity provider this template does not configure. It is not supported here."
fi

# Railway mounts volumes owned by root and this image runs as root, so there is nothing to chown --
# but the directory has to exist before flowsettings.py imports and reads it.
mkdir -p "$KH_APP_DATA_DIR" || fail "cannot create $KH_APP_DATA_DIR"

# kotaemon reads its own names; the wrapper's names exist so the template can describe them.
export KH_FEATURE_USER_MANAGEMENT=true
export KH_FEATURE_USER_MANAGEMENT_ADMIN="$KOTAEMON_ADMIN_USERNAME"
export KH_FEATURE_USER_MANAGEMENT_PASSWORD="$KOTAEMON_ADMIN_PASSWORD"
export KH_DEMO_MODE=false KH_GRADIO_SHARE=false KH_SSO_ENABLED=false
export GRADIO_SERVER_NAME="${GRADIO_SERVER_NAME:-0.0.0.0}"
export GRADIO_SERVER_PORT="$PUBLIC_PORT"

log "administrator \"${KOTAEMON_ADMIN_USERNAME}\" will be created on first start (password length ${#KOTAEMON_ADMIN_PASSWORD})"
log "starting kotaemon on ${GRADIO_SERVER_NAME}:${GRADIO_SERVER_PORT}, data in ${KH_APP_DATA_DIR}"

# This is upstream's own default start path from launch.sh, minus the `ollama serve &` line: the
# lite image ships no ollama, so that line only prints "not found" into the deploy log. If upstream
# changes launch.sh, re-read it -- MAINTENANCE.md lists this as a bump-time check.
cd /app || fail "cannot enter /app"
exec .venv/bin/python app.py
