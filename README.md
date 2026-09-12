# kotaemon on Railway

A community Railway template for [kotaemon][upstream], an open-source interface for asking questions
of your own documents. Upload PDFs, reports or notes; it indexes them, answers with citations you
can click through to the exact page, and supports several people with their own private and shared
collections. It is not affiliated with the kotaemon project.

It has real accounts. The problem is the first one. `libs/ktem/ktem/pages/resources/user.py` creates
an administrator while the interface is being built, using `KH_FEATURE_USER_MANAGEMENT_ADMIN` and
`KH_FEATURE_USER_MANAGEMENT_PASSWORD`, and `flowsettings.py` defaults both to the string `admin`.
Upstream's README says so plainly. `create_user` returns early once the username exists, so that
password is fixed at first boot and changing the variable afterwards does nothing.

On a platform that publishes a hostname the moment a service deploys, that is a public instance with
a documented login. This repository publishes a thin wrapper image that will not start until a real
password is supplied, and that refuses the settings which would remove the login again.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/kotaemon)

## What you get

- The official upstream `lite` image, pinned by digest, with no application changes.
- A password you never have to invent: the template generates one, and it is in place before the
  first account exists.
- Fail-fast validation. The container refuses to start with no password, a password under twelve
  characters, the password `admin`, `KH_FEATURE_USER_MANAGEMENT=false`, `KH_DEMO_MODE=true`,
  `KH_GRADIO_SHARE=true` or `KH_SSO_ENABLED=true`.
- A persistent volume holding the account database, settings, uploaded files and the vector index.

## First run

1. Deploy the template. Railway generates `KOTAEMON_ADMIN_PASSWORD` for you.
2. Copy that value out of the service variables. It is the password for user `admin`.
3. Open the domain and sign in. The first screen after that is kotaemon's setup wizard, which asks
   for a language-model key: OpenAI, Google, Cohere or anything OpenAI-compatible.
4. Upload a document, wait for indexing, and ask a question.

Add colleagues from the Resources tab once you are in. Their accounts are kotaemon's own, not
Railway's.

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `KOTAEMON_ADMIN_PASSWORD` | none, required | Password for the first administrator. At least 12 characters, and not `admin`. **Read before the first boot only.** |
| `KOTAEMON_ADMIN_USERNAME` | `admin` | Name of the first administrator. |
| `OPENAI_API_KEY` | unset | Optional. Set it and the setup wizard is pre-filled; leave it and enter a key in the interface. |
| `OPENAI_CHAT_MODEL` | `gpt-4o-mini` | Model used for answers. |
| `OPENAI_API_BASE` | OpenAI's | Point at any OpenAI-compatible endpoint. |
| `PORT` | `7860` | Public port. Railway sets this and probes its healthcheck against it. |

`GOOGLE_API_KEY`, `COHERE_API_KEY`, `VOYAGE_API_KEY`, the `AZURE_OPENAI_*` family and the rest of
kotaemon's settings are passed through untouched.

Four variables are refused rather than passed through, because each one removes the login:
`KH_FEATURE_USER_MANAGEMENT=false`, `KH_DEMO_MODE=true`, `KH_GRADIO_SHARE=true` and
`KH_SSO_ENABLED=true`. `SECURITY.md` explains each.

## Persistent paths

| Path | Holds |
|---|---|
| `/app/ktem_app_data` | Accounts, settings, conversations, uploaded files, the document store and the vector index. |

Everything the instance knows is under that one directory.

## Local development

```bash
docker compose build
tests/static.sh
tests/smoke.sh
tests/persistence.sh
```

`tests/railway-smoke.sh https://your-domain` checks a deployed instance.

## Documentation

| File | Covers |
|---|---|
| `ARCHITECTURE.md` | Service graph, the account bootstrap, boot sequence, ports, health. |
| `SECURITY.md` | What the login does and does not cover, and the settings this wrapper refuses. |
| `UPSTREAM.md` | Provenance, what the wrapper changes, how to bump the version. |
| `MAINTENANCE.md` | Release process, what to watch, rollback. |
| `THIRD_PARTY_NOTICES.md` | Licences shipped in the image. |
| `MARKETPLACE_AUDIT.md` | Why this template exists. |
| `RAILWAY_TEMPLATE.md` | The exact published template configuration. |

## Licence

The wrapper is MIT. kotaemon is Apache-2.0, and its licence travels inside the image at
`/usr/share/licenses/kotaemon-railway/`.

[upstream]: https://github.com/Cinnamon/kotaemon
