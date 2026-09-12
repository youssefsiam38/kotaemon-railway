# Upstream provenance

## kotaemon

| | |
|---|---|
| Project | https://github.com/Cinnamon/kotaemon |
| Licence | Apache-2.0 (`LICENSE.txt`) |
| Image | `ghcr.io/cinnamon/kotaemon:main-lite` |
| Digest | `sha256:29cffbc182dda9631b8f54f382c5711eac405ca2a2f1e8958c1da64f9f144208` |
| Repository commit at audit | `9ad3e4e`, 2026-05-30 |
| Latest release tag | `v0.12.0` |

**Upstream publishes no versioned image tags.** The registry carries only `main-lite`, `main-full`
and `latest`, all of which move. The base is therefore pinned by digest, which is immutable even
though the tag it was resolved from is not, and the repository commit is recorded above so a bump
has something to diff against.

The `lite` image is used. `main-full` additionally bundles ollama and a local model, which triples
the size and needs a GPU to be worth anything; a static check in `tests/static.sh` fails if it is
ever pinned here.

## What this repository changes

It adds two things and removes none:

1. `scripts/entrypoint.sh` as the image entrypoint, replacing `sh /app/launch.sh`, whose default
   path it reproduces.
2. The upstream licence at `/usr/share/licenses/kotaemon-railway/`.

It also sets environment defaults in the image: `KH_FEATURE_USER_MANAGEMENT=true`,
`KH_FEATURE_USER_MANAGEMENT_ADMIN=admin`, `KH_DEMO_MODE=false`, `KH_GRADIO_SHARE=false`,
`GRADIO_SERVER_NAME=0.0.0.0` and `GRADIO_ANALYTICS_ENABLED=False`. No password is baked in, and a
static check asserts that.

No Python file is patched and no dependency is changed.

### Why the entrypoint does not call `launch.sh`

`launch.sh` has three paths. The demo and SSO paths are both refused by this wrapper, so only the
default one is reachable, and it is two lines:

```sh
ollama serve &
.venv/bin/python app.py
```

The `lite` image ships no ollama, so the first line writes `ollama: not found` into the deploy log on
every start and nothing else. The wrapper runs the second line directly. `MAINTENANCE.md` lists
re-reading `launch.sh` as a bump-time check, because that is the one place this shortcut could go
stale.

## Licence obligations

Apache-2.0 requires the licence and notices to travel with the software. It is vendored in
`licenses/` and copied into the image. `THIRD_PARTY_NOTICES.md` records what is shipped.

The wrapper itself is MIT. Redistributing the wrapper image redistributes the upstream image, which
is why the notice is inside it rather than only in this repository.

## Bumping the upstream version

There are no release tags to follow, so a bump is deliberate rather than automatic:

1. Read the commits on `main` since the recorded commit, in particular `flowsettings.py` for
   renamed settings and `libs/ktem/ktem/pages/resources/user.py` for the account bootstrap.
2. Resolve the current digest:
   `docker buildx imagetools inspect ghcr.io/cinnamon/kotaemon:main-lite`
3. Update `KOTAEMON_IMAGE` in the Dockerfile, the digest assertion in `tests/static.sh`, and the
   commit recorded in the table above.
4. Run the full suite locally, then tag a release. CI rebuilds, retests against the candidate image
   and pushes.
