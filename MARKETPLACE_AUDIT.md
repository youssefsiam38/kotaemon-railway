# Marketplace audit

Checked 2026-09-12 against Railway's template search.

## Gap

`templateSearch` returns no template named after kotaemon, and none of the loose matches is a
document-question-answering interface with its own accounts. The retrieval-adjacent templates that
do exist solve different problems:

| Existing template | Deploys | What it is | Why it does not cover this |
|---|---:|---|---|
| AnythingLLM | 1004 | A chat interface over documents | A different product; the closest competitor, and the reason to check rather than assume. |
| RAGFlow, LightRAG, R2R, Cognee | 1-23 | Retrieval engines and pipelines | Infrastructure, not an interface a non-developer opens. |
| Verba, Open Notebook, SurfSense | small | Other document chat products | Different feature sets; none is kotaemon. |
| Qdrant, ChromaDB, Weaviate | 46-325 | Vector databases | A component of a system like this, not the system. |
| Docling, MinerU, Marker | 0-44 | Document conversion APIs | They produce the text a system like this indexes. |

kotaemon is the one of that group with citation-level provenance in the interface, where an answer
links to the page and the bounding box it came from, and it is the one with 25,000 stars.

## Why kotaemon

- Apache-2.0, so redistributing a wrapper image is unencumbered.
- 25,745 stars, the largest of any candidate in this family's audit.
- Multi-user by design, with private and shared collections, which is what makes it worth hosting
  rather than running locally.
- A single container with a SQLite database and a file-backed index: no companion database, cache or
  queue.
- The `lite` image is CPU-only and modest, and the heavy work is done by whichever model provider the
  deployer configures.

## Why it needs a template rather than a raw image

Deploying `ghcr.io/cinnamon/kotaemon:main-lite` directly to Railway produces a working instance
whose administrator password is `admin`, which upstream's own README publishes. The account is
created during the first boot and `create_user` never revisits it, so the window to fix that from
configuration closes before the deployer sees the URL.

The template also settles three things that are easy to get wrong:

1. **The port.** Railway probes its healthcheck against `PORT`; kotaemon's Gradio server reads
   `GRADIO_SERVER_PORT` and ignores `PORT` entirely.
2. **The volume.** Without one, accounts, uploaded documents and the whole index are lost on every
   deploy. The mount has to be the parent directory, not the database file, because the index and
   the uploads live beside it.
3. **The settings that undo the login.** `KH_FEATURE_USER_MANAGEMENT`, `KH_DEMO_MODE`,
   `KH_GRADIO_SHARE` and `KH_SSO_ENABLED` each remove it in a different way, and the last one
   publishes a `*.gradio.live` tunnel that the platform cannot see, let alone protect.

## Category

AI/ML. Railway added that category after the earlier templates in this family were published, and it
is the right home for a retrieval-augmented question-answering interface.
