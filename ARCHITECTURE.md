# Architecture

## Service graph

One service, one volume. There is no proxy and no separate database.

```
internet --> Railway edge (TLS) --> :PORT  kotaemon (Gradio)
                                             |
                                             +-- /app/ktem_app_data (volume)
                                                   sql.db, files, docstore, vectorstore
```

## Why a wrapper image, and why no proxy

Every other template in this family puts Caddy in front of an application that has no login.
kotaemon has one, with accounts, roles and private collections, and that login is the product: the
reason to deploy it is to give several people their own view of a shared corpus. Putting a single
shared password in front of it would break exactly that.

What kotaemon does not do is choose a first password. From
`libs/ktem/ktem/pages/resources/user.py`:

```python
usn = flowsettings.KH_FEATURE_USER_MANAGEMENT_ADMIN
pwd = flowsettings.KH_FEATURE_USER_MANAGEMENT_PASSWORD
is_created = create_user(usn, pwd)
```

and from `flowsettings.py`, both of those default to `"admin"`. `create_user` returns `False`
without touching anything when the username already exists, so the password is decided on the boot
that creates the account and never again.

That is the whole vulnerability, and it is a first-boot one, which is exactly what a template
controls. The wrapper therefore validates and supplies the password, and otherwise stays out of the
way.

## Boot sequence

1. Validate the environment. Names of missing or wrong variables are printed; values never are.
2. Refuse the four settings that remove the login: `KH_FEATURE_USER_MANAGEMENT=false`,
   `KH_DEMO_MODE=true`, `KH_GRADIO_SHARE=true`, `KH_SSO_ENABLED=true`.
3. Create the data directory, which `flowsettings.py` reads at import time.
4. Export `KH_FEATURE_USER_MANAGEMENT_ADMIN` and `KH_FEATURE_USER_MANAGEMENT_PASSWORD` from the
   wrapper's own variables, and re-export the four refused settings at their safe values so a later
   change cannot reach the application.
5. `exec` the application. kotaemon builds its interface, and the administrator is created during
   that build, before the listener accepts anything.

Step 5 is upstream's own default path from `launch.sh`, minus one line: `launch.sh` starts
`ollama serve` first, and the `lite` image ships no ollama, so that line only writes "not found"
into the deploy log.

## Ports

| Port | Listener | Reachable from |
|---|---|---|
| `PORT` (7860) | kotaemon's Gradio server | the internet |

The entrypoint sets `GRADIO_SERVER_PORT` from `PORT`. Railway runs its healthcheck against the value
of `PORT`, not against the domain's target port, so the two must agree or a service that serves the
public domain perfectly is still reported unhealthy.

## Health

The healthcheck path is `/`. kotaemon answers it with the login page, unauthenticated, from the
moment the server is up, which is what a probe needs. There is no separate health endpoint.

Start-up is a Python import of the whole retrieval stack, so it takes tens of seconds; the template
sets a generous healthcheck timeout for that.

## State

Everything is under `/app/ktem_app_data`:

| Path | Holds |
|---|---|
| `user_data/sql.db` | Accounts, conversations, settings, issue reports |
| `user_data/files` | Uploaded documents |
| `user_data/docstore`, `user_data/vectorstore` | The index those documents are searched through |
| `huggingface` | Embedding models downloaded on demand |
| `markdown_cache_dir`, `chunks_cache_dir`, `zip_cache_dir` | Conversion scratch space |

One volume covers all of it, which is why the mount is the parent directory rather than the database
alone.
