# Maintenance

## Release process

1. Make the change on a branch. The `test` workflow runs the full suite on every push and pull
   request.
2. Run locally:
   ```bash
   docker compose build --pull
   tests/static.sh && tests/smoke.sh && tests/persistence.sh
   ```
3. Tag `vX.Y.Z`. The `publish-image` workflow builds an amd64 candidate, runs the smoke and
   persistence suites against that exact image, and only then pushes it to GHCR as `X.Y.Z`, `X.Y`
   and `latest`.
4. Update the Railway template to the new tag. `RAILWAY_TEMPLATE.md` records the exact
   configuration; the template pins a version tag, never a digest, because the template generator
   rejects `@sha256:` references.
5. Deploy the updated template into a scratch project and run
   `tests/railway-smoke.sh https://domain` against it before leaving it published.

## What to watch

| Source | Why |
|---|---|
| https://github.com/Cinnamon/kotaemon/commits/main | There are no release tags, so commits are the only signal. Watch `flowsettings.py` and `libs/ktem/ktem/pages/resources/user.py`. |
| `libs/ktem/ktem/pages/resources/user.py` | **The account bootstrap is the reason this template exists.** If upstream ever stops creating an account from the environment, or starts re-passwording an existing one, the wrapper's contract changes. |
| `launch.sh` | The entrypoint reproduces its default path. If that path grows a line the wrapper needs, this is where it shows up. |
| Railway's healthcheck behaviour | The probe runs against `PORT`; a platform change there breaks every template in this family at once. |

## Breaking-change checklist

Before bumping the upstream digest, confirm:

- [ ] `.venv/bin/python app.py` from `/app` is still how `launch.sh` starts the default path.
- [ ] `KH_FEATURE_USER_MANAGEMENT_ADMIN` and `KH_FEATURE_USER_MANAGEMENT_PASSWORD` are still the
      names the account bootstrap reads.
- [ ] `KH_APP_DATA_DIR` is still `/app/ktem_app_data`, or the volume mount path changes with it.
- [ ] The user table still has `username_lower` and `password` columns; `tests/lib.sh` finds the
      table by that first column name.
- [ ] Passwords are still a bare SHA-256, or the assertions comparing hashes need rewriting.
- [ ] `KH_DEMO_MODE`, `KH_GRADIO_SHARE` and `KH_SSO_ENABLED` still mean what `SECURITY.md` says.
- [ ] The image still runs as root, or the entrypoint grows a chown for the volume.

## Rolling back

Republish the template with the previous wrapper tag. The volume format has not changed between
upstream builds so far, but a rollback after a schema migration is not guaranteed: take a volume
snapshot before a bump that touches the database.

## If this repository is abandoned

The image is a thin wrapper: the Dockerfile, the entrypoint and the tests are the whole of it. Fork
it, change the `org.opencontainers.image.source` label and the GHCR path, and publish your own
template. Nothing in the design depends on this account.
