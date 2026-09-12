# Railway template configuration

The published template. Reproduce it from this file if it ever has to be rebuilt.

| | |
|---|---|
| Name | kotaemon |
| Code | `kotaemon` |
| Template id | _filled in at publication_ |
| Deploy URL | https://railway.com/deploy/kotaemon |
| Category | AI/ML |
| Image | `ghcr.io/youssefsiam38/kotaemon-railway:<version>` |
| Icon | `assets/icon.png` |
| Overview markdown | `marketplace/OVERVIEW.md` (Railway enforces its section headings) |

## Service `kotaemon` — public

| Field | Value |
|---|---|
| Source | `ghcr.io/youssefsiam38/kotaemon-railway:<version>` |
| Port | 7860 |
| Domain | generated, target port 7860 |
| Healthcheck | `/` |
| Healthcheck timeout | 600 s |
| Volume | `/app/ktem_app_data` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `KOTAEMON_ADMIN_USERNAME` | `admin` |
| `KOTAEMON_ADMIN_PASSWORD` | `${{secret(24)}}` |
| `PORT` | `7860` |
| `TZ` | `UTC` |

## Notes

- Every variable has a value or a generator, so `railway deploy -t kotaemon` works without a TTY.
- **`KOTAEMON_ADMIN_PASSWORD` only matters on the first boot.** kotaemon creates the account then
  and never re-passwords it from the environment, so the generated value has to be present in the
  very first deployment. It is, because the template generates it.
- **The healthcheck path is `/`.** kotaemon serves its login page there unauthenticated, and there
  is no separate health endpoint.
- **The healthcheck timeout has to be generous.** Importing the retrieval stack takes tens of
  seconds on a cold container.
- **`PORT` and the domain's target port must match.** Railway runs its healthcheck against the value
  of `PORT`, defaulting to 8080. The entrypoint copies `PORT` into `GRADIO_SERVER_PORT`, which is
  what the application actually reads.
- The volume must mount `/app/ktem_app_data`, the parent of the database, the uploads and the index.
- Do not add `KH_FEATURE_USER_MANAGEMENT`, `KH_DEMO_MODE`, `KH_GRADIO_SHARE` or `KH_SSO_ENABLED`.
  The wrapper refuses each of them; `SECURITY.md` explains why.
- There is no second service and nothing on the private network.
