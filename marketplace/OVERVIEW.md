# Deploy and Host kotaemon on Railway

kotaemon lets you ask questions of your own documents and get answers with citations you can click
through to the page they came from. Upload contracts, papers, reports or manuals; it indexes them and
answers in plain language, showing its working. It has real accounts, so a team can share one
instance with private and shared collections. This is a community-maintained template; it is not
affiliated with the kotaemon project.

## About Hosting kotaemon

Hosting it is simple in shape: one Python service, one SQLite database, one directory holding the
uploaded files and the index that searches them. There is no companion database, cache or queue, and
the expensive part of the work is done by whichever language-model provider you point it at.

The part that needs care is the first account. kotaemon creates an administrator for you while the
interface is being built, and both the username and the password default to `admin` -- upstream's
own README says so. The account is created on the first boot and never re-passworded from
configuration afterwards, so on a platform that publishes a hostname the moment a service deploys,
the window to fix that closes before you have seen the URL. This template generates a strong password
and has it in place before the account exists, and refuses the four settings that would remove the
login again.

## Why Deploy kotaemon on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your
infrastructure so you don't have to deal with configuration, while allowing you to vertically and
horizontally scale it.

By deploying kotaemon on Railway, you are one step closer to supporting a complete full-stack
application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

Concretely, this template generates the administrator password, attaches the volume that holds the
accounts and the index, pins the listening port to the generated domain, and points the healthcheck
at the login page, so you get a working and protected instance with nothing to fill in.

## Common Use Cases

- Ask questions across a folder of contracts or policies and get the clause the answer came from.
- Give a team one searchable place for its research papers, with per-person private collections.
- Turn a product manual into something support staff can query in plain language.
- Keep a document corpus on infrastructure you control, sending only the passages needed for an
  answer to a model provider.

## Dependencies for kotaemon Hosting

- A persistent volume for the account database, the uploaded files and the index.
- An API key for a language-model provider: OpenAI, Google, Cohere, Azure OpenAI or any
  OpenAI-compatible endpoint. You can enter it in the interface after the first sign-in.
- Nothing else. No external database, cache or queue.

### Deployment Dependencies

- kotaemon upstream project and documentation: https://github.com/Cinnamon/kotaemon
- Template repository, wrapper image and tests: https://github.com/youssefsiam38/kotaemon-railway
- Published image: `ghcr.io/youssefsiam38/kotaemon-railway`
- kotaemon is Apache-2.0 licensed, which is permissive.

### Implementation Details

The wrapper adds no application code. It validates the configuration and refuses to start without an
administrator password of at least twelve characters, refuses the literal password `admin`, and
refuses the four upstream settings that each remove the login in a different way, including the one
that would publish a public tunnel straight to the container. It then hands the password to the
application through the variables the account bootstrap reads and starts it the way upstream's own
launcher does.
