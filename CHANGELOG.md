# Changelog

What changed in each Semurg release, in plain words. A release is named `r11.SEQ.DATE.COMMIT`, for example
`r11.134.20261027.a9b1536`. The newest is always named at https://one.semurg.io/dl/LATEST.json, and every download can be
checked against https://one.semurg.io/dl/SHA256SUMS. Each release is installed fresh and upgraded in a clean room before it
publishes; the agent integrations (OpenClaw, Claude Code and eleven library frameworks) are re-tested on a fresh install of
each published release, and https://one.semurg.io/agents shows the newest run.

## r11.134.20261027.a9b1536 (27 October 2026)

- `semurg uninstall` on a machine where the node was started without systemd (in a container, for example) now stops the
  node, and checks that it has stopped, before it removes anything. Before, the files were removed while the node kept
  running and answering.
- The installer download now holds only the files an install uses; two build scripts that had been included no longer ship.
- Memory: looking up an entity by its name now answers only from the scope it was asked in. No tool or API route used the
  old lookup, which could match a name stored in another scope, so no answer a client received changes.

## r11.133.20261027.8a8b1f3 (27 October 2026)

- Recall returns only real facts: the node's own bookkeeping records (attribute and source links) are no longer returned as
  facts, and the false ownership warning they logged on every recall of an entity with an attribute is gone.
- Searching by meaning with an embedding model that has no calibrated threshold now refuses by name, instead of treating
  every stored passage as a match.
- The health check reports an installed embedding model's real state (it read "could not judge" on every node), and the
  background extraction queue reads `running`, with its backlog, from its first page instead of "never" until it finished.
- Messaging: a message preview never cuts a character in half (the inbox page failed on such a preview), and a user can no
  longer be named "owner".
- On CPUs with AVX2 but no AVX-512, model math now uses the CPU's vector unit instead of one value at a time.
- A Gemma model whose image support is not built for the node serves text, and refuses image requests by name.
- An app installed on a node now loads on a release install (some answered 404), and an app that was not ready when the
  node started is retried every 30 seconds instead of answering 404 until a restart.
- /dl/MODELS.json, the model catalogue retired on 11 October, now redirects to /dl/CATALOGUE.json instead of serving an
  outdated copy.
- The website's pages now say what the published results and this release say.
- New post: Semurg installs on six Linux distributions (Ubuntu, Debian, Rocky, Alma, Fedora and Arch), each checked by a
  real install of the published installer; Amazon Linux and openSUSE are named as not yet checked
  (https://one.semurg.io/blog).
- The agent integrations passed again on a fresh install of r11.132.

## r11.132.20261027.a274a28 (27 October 2026)

- Installer: on a minimal Linux image that lacks util-linux, the installer now installs it. The install page names the
  Linux distributions the install test passed on.
- The agent integrations passed again on a fresh install of r11.131.

## r11.131.20261027.1c0ba4a (27 October 2026)

- One release for every glibc-based Linux (glibc 2.34 or newer): the release carries its own runtime, and the installer
  checks the C library instead of the distribution's name, installing only what is missing with apt, dnf, yum, zypper or
  pacman.
- The API token is never printed. The installer's success banner and the container log say where the token is kept and
  give the one command that reads it into your shell, so it stays out of terminal logs and agent transcripts.
- Large uploads start at once: a client that sends `Expect: 100-continue` no longer waits a second before the node reads
  the body.
- Remembering a long text is faster and grows only with the text's length (on r11.130 a 1 MB text took 7.3 s).
- The agent guide answers at every name agents try: /llms-full.txt, /AGENTS.md, /benchmark.txt, /llm.txt and /agents.txt
  all lead to https://one.semurg.io/llms.txt.
- Cluster health lists the built-in health agents of every node and names any that is missing; a node that does not answer
  is reported as "could not judge", never as healthy (REST, WebSocket, the binary protocol and the SDKs).
- Python client 0.1.6: a `semurg` command, so an MCP client can run `uvx semurg mcp`.
- New post: Semurg against the databases you already run, the head-to-head results measured so far
  (https://one.semurg.io/blog).
- The agent integrations passed again on a fresh install of r11.130.

## r11.130.20261026.cf29851 (26 October 2026)

- Python client 0.1.5: `python -m semurg mcp` is a local (stdio) MCP server that forwards every call to your node, for MCP
  clients that only start local programs. Its tool list is taken from a fresh node of the release it names.
- The agent integrations passed again on a fresh install of r11.129.

## r11.129.20261026.2524157 (26 October 2026)

- Elixir: a client, and jido_semurg, persistent memory with citations for Jido agents (packaged for Hex; not yet on Hex).
- Faster ingest on processors with SHA extensions: content hashing uses the processor's SHA instructions when it has them,
  with the same results; other processors use the standard path.
- The agent integrations passed again on a fresh install of r11.128.
