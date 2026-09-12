# syntax=docker/dockerfile:1
#
# kotaemon-railway: thin wrapper around the official kotaemon "lite" image.
#
# kotaemon has real multi-user accounts, and that is the problem: the first one is created for you.
# `libs/ktem/ktem/pages/resources/user.py` calls `create_user` with
# `KH_FEATURE_USER_MANAGEMENT_ADMIN` and `KH_FEATURE_USER_MANAGEMENT_PASSWORD` while the interface
# is being built, and `flowsettings.py` defaults both of those to the literal string "admin".
# Upstream's own README says so. `create_user` returns early when the username already exists, so
# the credential is fixed at first boot and changing the variable afterwards does nothing.
#
# On a platform that publishes a hostname the moment a service deploys, that is a public instance
# with a documented password. This wrapper refuses to start until a real password is supplied, and
# refuses the three settings that would take the login away again. Application code is unchanged.
#
# Upstream publishes no release tags -- only the floating `main-lite`, `main-full` and `latest` --
# so the base is pinned by digest, which is immutable even though the tag moves.
ARG KOTAEMON_IMAGE=ghcr.io/cinnamon/kotaemon:main-lite@sha256:29cffbc182dda9631b8f54f382c5711eac405ca2a2f1e8958c1da64f9f144208

FROM ${KOTAEMON_IMAGE}

ARG KOTAEMON_VERSION=main-lite
ARG WRAPPER_VERSION=0.0.0-dev
ARG VCS_REF=unknown
ARG BUILD_DATE=1970-01-01T00:00:00Z

COPY licenses/ /usr/share/licenses/kotaemon-railway/
COPY --chmod=0755 scripts/entrypoint.sh /usr/local/bin/kotaemon-railway-entrypoint

# The application is the public listener; there is no proxy in front of it, because kotaemon's own
# login is the boundary once the first account has a password worth having.
ENV KH_FEATURE_USER_MANAGEMENT=true \
    KH_FEATURE_USER_MANAGEMENT_ADMIN=admin \
    KH_DEMO_MODE=false \
    KH_GRADIO_SHARE=false \
    GRADIO_SERVER_NAME=0.0.0.0 \
    GRADIO_ANALYTICS_ENABLED=False

LABEL org.opencontainers.image.title="kotaemon-railway" \
      org.opencontainers.image.description="Community Railway wrapper for kotaemon, a self-hosted RAG interface for chatting with your documents. Replaces the default admin password. Not affiliated with the kotaemon project." \
      org.opencontainers.image.source="https://github.com/youssefsiam38/kotaemon-railway" \
      org.opencontainers.image.url="https://github.com/youssefsiam38/kotaemon-railway" \
      org.opencontainers.image.documentation="https://github.com/youssefsiam38/kotaemon-railway#readme" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${WRAPPER_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="ghcr.io/cinnamon/kotaemon:${KOTAEMON_VERSION}" \
      io.kotaemon-railway.upstream.version="${KOTAEMON_VERSION}"

EXPOSE 7860

ENTRYPOINT ["/usr/local/bin/kotaemon-railway-entrypoint"]
