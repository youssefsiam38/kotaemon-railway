# Third-party notices

This image redistributes software written by other people. Its licence is shipped inside the image
at `/usr/share/licenses/kotaemon-railway/` and vendored in `licenses/` here.

## Shipped inside the wrapper image

| Component | Licence | Source | Notice |
|---|---|---|---|
| kotaemon (`main-lite`) | Apache-2.0 | https://github.com/Cinnamon/kotaemon | `licenses/KOTAEMON-LICENSE` |

The upstream image itself contains further components, among them Gradio (Apache-2.0), LlamaIndex
(MIT), LangChain (MIT), SQLModel (MIT), LanceDB (Apache-2.0), ChromaDB (Apache-2.0), PDF.js
(Apache-2.0), unstructured (Apache-2.0) and, on amd64, GraphRAG (MIT). Their notices travel in the
layers upstream publishes; this wrapper does not repackage or relink any of them.

Embedding models are not shipped. They are downloaded at runtime from Hugging Face and are covered
by their own terms.

## Licence obligations

Apache-2.0 requires that the licence, the copyright notice and any NOTICE file accompany the
software, and that modified files be marked. No upstream file is modified here; the wrapper adds an
entrypoint alongside them. Copying the licence into the image satisfies the notice requirement for
anyone who pulls the image without reading this repository.

## Trademarks and artwork

"kotaemon" is a project of Cinnamon AI. It is not affiliated with and does not endorse this
template. The template icon in `assets/` was made for this repository and is not an upstream logo.

## This repository

The wrapper, its entrypoint, its tests and its documentation are MIT licensed. See `LICENSE`.
