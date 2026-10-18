<!-- Generated from the Semurg source of release r11.111.20261018.98f63cd. The canonical, always-current copy is https://one.semurg.io/llms.txt -->
# Semurg

> The memory layer for AI agents: knowledge graph, vectors and graph RAG on one engine, written from scratch. Run it on your own hardware. This file is for coding agents: how to install a node, how to connect a coding agent, the memory tools an agent calls over MCP or HTTP, the same calls in each client, what Semurg publishes, and the rules an app built on a node follows. Every command, tool, route and client call named here is read from the source, checked against it before this file is published, and the commands are run against each published release.

## Install a node

Before you install: Semurg runs on Intel and AMD x86_64 processors with AVX2 or newer, on Linux directly, or on Windows through WSL2 or Docker. There is no Mac or ARM build yet (a Mac version is coming); on a Mac, run the node on a Linux machine you can reach. The installer needs root.

One command, on a Linux machine you control. The first line shows the script without running it.

    curl -fsSL https://one.semurg.io/install | less
    curl -fsSL https://one.semurg.io/install | sudo bash

The installer ends with a SUCCESS banner that prints the node's API token. The data directory must sit on a local ext4 or xfs filesystem; the installer checks this and stops if it does not. One node needs no licence key.

Put the token in your shell, then prove the gate is on (401 without the token, 200 with it):

    TOKEN=$(sudo grep '^SEMURG_API_TOKEN=' /etc/semurg/semurg.env | cut -d= -f2-)
    curl -si http://127.0.0.1:4000/v1/whoami | head -1
    curl -si -H "Authorization: Bearer $TOKEN" http://127.0.0.1:4000/v1/whoami | head -1

## Connect a coding agent

Claude Code: one user-scope entry, written by Claude Code's own command. Run it in the shell that starts Claude Code; the entry holds only a reference to the variable, never the token itself. The address is the one a fresh node serves; behind your own TLS proxy use its https address.

    export SEMURG_API_TOKEN=<the API token your node printed at install>
    claude mcp add-json --scope user semurg '{"type":"http","url":"http://127.0.0.1:4000/v1/mcp","headers":{"Authorization":"Bearer ${SEMURG_API_TOKEN}","X-Semurg-Scope":"default"}}'
    # Claude Code reads the token from the SEMURG_API_TOKEN environment variable when it starts

Connected on release r11.101.20261016.3097008: Claude Code's own client listed every memory tool that release served.

Claude Desktop: it runs on macOS and Windows and Semurg runs on Linux x86_64, so the node is reached at 127.0.0.1:4000 one of two ways: on a Windows machine, run the node on the same machine under WSL2 (Ubuntu 24.04) or with the Docker image; otherwise run it on a Linux machine and forward its port to the desktop with ssh -N -L 4000:127.0.0.1:4000 you@your-node, so the token never crosses the network over plain HTTP. A remote node over HTTPS with sign-in (OAuth) is not covered here yet. Claude Desktop starts only local (stdio) MCP servers, so the mcp-remote bridge, run by npx (it needs Node.js), carries it to the node's streamable HTTP door. Put this in claude_desktop_config.json (macOS: ~/Library/Application Support/Claude/; Windows: %APPDATA%\Claude\), put your token in place of <token>, and restart Claude Desktop. The file then holds the token: keep it private.

    {
      "mcpServers": {
        "semurg": {
          "command": "npx",
          "args": ["-y", "mcp-remote", "http://127.0.0.1:4000/v1/mcp",
                   "--header", "Authorization:${SEMURG_AUTH}",
                   "--header", "X-Semurg-Scope:default"],
          "env": { "SEMURG_AUTH": "Bearer <token>" }
        }
      }
    }

Results pending. Any other MCP client: streamable HTTP at POST /v1/mcp on your node, the header Authorization: Bearer <token>, and an optional X-Semurg-Scope header. Each agent's own configuration: https://one.semurg.io/agents

## Agent memory over MCP

Endpoint: POST /v1/mcp on your node. It speaks streamable HTTP and takes the node's API token as a bearer token. An optional X-Semurg-Scope header sets the default scope for the connection.

Every tool except comms_bind_address takes `scope`: Namespace. Agents on the same node using the same scope share these facts; another scope is private. Optional when the connection sets the X-Semurg-Scope header.

### memory_status (read-only)

Report whether shared memory is on for this node and which of YOUR scopes hold facts. Pass `scope` to also get that scope's ontology summary: how many entity types and relation types it holds, its biggest classes (up to 50) with their member count (`members_bound` says "exact": the live members, measured to drop by one with every forget, also over 64 members) on their members, the relation types it already uses (reuse them spelled EXACTLY as listed in `spellings`), and the name-merge mode. Read-only. Call it first when another memory call fails.

Parameters:
- user_id (string): Optional END USER inside your key (one app, many end users): every scope you name is then that end user's own, and two end users never meet. App-level separation, as mem0's user_id; a per-user token stays the security boundary. When the connection sets the X-Semurg-User header, that header IS the end user and a different user_id is refused. No ':', at most 256 bytes.

### memory_remember (writes)

Store memory for agents. YOU ARE THE EXTRACTOR: whenever you store text (`content` or `messages`), send the entities and relations you found in it as `facts` in the SAME call. They are stored at once, and you extract better and faster than this node's local model, which reads text sent WITHOUT facts only in the background and slowly on a CPU (or not at all when none is installed). `content`: raw text (a note, a document), stored NOW: it is cut into passages of about 100-200 words at sentence ends, and each passage is linked to the entities it names that are already stored or that you send beside it as `facts`; the reply says `extraction` (agent_facts when you sent facts, known_names_only when not), how many passages no entity reaches (`unlinked_passages`) and `meaning`: queued when this node has an embedding model (the passages' vectors are written right behind the reply; `memory_status` says when), not_armed when it has none (the passages are embedded when one is installed). Without `facts`, the node's installed extraction model reads the stored text AFTER the reply and adds its entities, types and relations, each relation cited to the passage it was found in: `model_extraction` says pending (waiting on disk), done (already extracted), failed (a passage failed 3 attempts, named), other_model (extracted by another model), not_installed, not_serving or could_not_judge, by name; with `facts` no model runs. `messages`: a conversation [{role, content}], stored as one text, one line per turn, never a passage across two turns; otherwise exactly like `content`. `facts`: entities [{name, type}] and relations [{source, target, type}] that you extract yourself, for example type WORKS_AT; types are classes, matched letter case aside. `passages`: text to find again, [{text, mentions, key?}], stored NOW with no model: `mentions` names the entities the text is about (each is stored under the name as sent, and must appear in the text, letter case aside, or the passage is refused by name), and memory_context returns the passage WHOLE when it reaches one of them. `content` and `passages` cannot ride in one call. `date` (ISO 8601, for example 2026-10-01) is when this was said: it is kept with the call's source and returned with what it sourced. Storing the same thing again with the same date changes nothing (content-addressed; it answers `already`). Per call: at most 1000 entities and 5000 relations, 1048576 bytes of content, 1000 passages holding 1048576 bytes of text and 1000 mentions in all, each passage at most 65536 bytes; every name, mention and key at most 1024 bytes. `source` is an optional provenance label returned with the fact when it is recalled. Before you invent a type or a relation, call memory_status with your scope and reuse a class from ontology.top_classes and a relation from ontology.relations, spelled EXACTLY as listed in its spellings (a different spelling is a different relation, and the same fact stored twice). List both ends of every relation in `entities` in each remember call, including entities you stored earlier.

Parameters:
- content (string): Raw text to remember, stored now and cut into sentence-bounded passages. Send the entities and relations you found in it as `facts` in the same call.
- date (string): When this was said or true, ISO 8601 (2026-10-01 or 2026-10-01T09:30:00Z). Optional.
- facts (object): Entities and the relations between them that YOU extracted from what you are storing: stored at once, no model runs.
- messages (array): A conversation to remember as one text, one line per turn. Not beside content or passages.
- passages (array): Text to find again later, stored now. Each passage names the entities it is about.
- source (string): Optional source label (e.g. a file name). It is shown as the source name in each citation. Facts you send later under the same label (and without a "date") are attached to the document(s) you stored under it, so their citations quote that text; a label nothing was stored under, a call with a "date", or a label that names more than 8 documents (a file stored as many passages) keeps its own source (the reply's source_label_state says which: attached, new_source, dated_own_source, many_documents_not_attached).
- user_id (string): Optional END USER inside your key (one app, many end users): every scope you name is then that end user's own, and two end users never meet. App-level separation, as mem0's user_id; a per-user token stays the security boundary. When the connection sets the X-Semurg-User header, that header IS the end user and a different user_id is refused. No ':', at most 256 bytes.

### memory_recall (read-only)

Recall what is stored about ONE entity: finds the entity named `subject` by its name, exact or a similar spelling or letter case ("paris" finds Paris, "Dan" finds Dana), or one whole word of a longer name ("Priya" finds Priya Raman; small English words such as "the" or "of" never match on their own), walks the graph from it and returns the connected facts in both directions (`direction` outbound or inbound), each with its `citation` (`citation.source`: `kind` document, or asserted for a fact an agent sent without text; the `doc_id` of the document it was read from; the `name` label it was stored under; `ingested_at`. `citation.span`: the sentence quoted from that document, `start` and `end` in Unicode code points of its full text, checked before it is served, or null with `span_state` saying why. `citation.found_by`: how it was found), its `source_date` when one was stored, and the seed that found it (`seed`: exact, name or type). Always current: a fact stored a moment ago is visible. A fact with `direction` derived (`derived: true`) was not stored: it follows from stored facts by its relation's meaning (symmetric: married_to, spouse_of, sibling_of; inverse: parent_of and child_of, owns and owned_by, employs and employed_by, manages and managed_by; transitive, up to 6 links: part_of, located_in, contained_in), and `citation.found_by.reasoning` names the rule and the stored facts it rests on, each one recallable on its own. The reply carries `state`: answered, nothing_stored (the name matched nothing: an explicit empty answer, never an invented one) or could_not_judge (a stage could not run, named in `detail`); `seeding` says what each stage did, and `meaning` reads not_armed until an embedding model is armed (searching by meaning is not available until then). `source_id` is the id of the node the item is made from (a passage: its chunk; a fact: the entity at its other end; an entity or type: itself), NOT of the document that sources it: that is `citation.source.doc_id`. Read-only. Ids (`source_id`, `seed_id`, `citation.source.doc_id`) are decimal STRINGS of a 64-bit unsigned integer: send them back unchanged and never convert them to a number (a JavaScript Number cannot hold one).

Parameters:
- as_of (string): Read the memory as it was KNOWN at this instant (ISO 8601 date or date-time; a bare date is the end of that day UTC): a fact stored after it is not visible. Leave it out for now.
- attribute (object): Find entities BY an attribute's current value, instead of by name: {"key": "ndis_number", "value": "430000001"} (optionally "type"). Only this scope is searched, the end user's own when user_id is set. Send it instead of subject.
- compact (boolean): true: each item ONCE (text, kind, the fact's subject / relation / object, doc_id, source, date, score, seed) without the retrieval diagnostics (chunks, seeds, seeding, traversal): a fraction of the bytes. Leave it out for the full reply.
- k (integer 1 to 1000): Most facts to return.
- subject (string): The entity name to recall from: exact, or a similar spelling or letter case.
- user_id (string): Optional END USER inside your key (one app, many end users): every scope you name is then that end user's own, and two end users never meet. App-level separation, as mem0's user_id; a per-user token stays the security boundary. When the connection sets the X-Semurg-User header, that header IS the end user and a different user_id is refused. No ':', at most 256 bytes.
- valid_at (string): Read what was TRUE at this instant (ISO 8601), whatever was known since. With as_of: as known at as_of, true at valid_at.

### memory_relate (writes)

Add ONE typed edge between two entities in a scope, for example from Alice to Bob with type MENTORS. Entities that are new are created. Returns whether the edge is physically present.

Parameters:
- from (string, required)
- to (string, required)
- type (string, required): The relationship, for example WORKS_AT.
- attributes (object): Typed attributes of THIS relationship, stored on it (role, frequency, valid_from / valid_to as ISO dates), by the same rules as an entity's attributes: {"role": "guardian_nominee", "valid_from": "2026-03-01"}.
- user_id (string): Optional END USER inside your key (one app, many end users): every scope you name is then that end user's own, and two end users never meet. App-level separation, as mem0's user_id; a per-user token stays the security boundary. When the connection sets the X-Semurg-User header, that header IS the end user and a different user_id is refused. No ':', at most 256 bytes.

### memory_forget (writes)

Forget something in a scope, ONE thing per call (send exactly one of `subject`, `fact`, `passage`, `source`, `all`, `attribute`). `subject`: an entity by its exact name: the entity, its place in the scope, its type memberships, every fact with it at either end AND every stored passage that names it are deleted (tombstoned), so recall, context, type lookups and passage search no longer return them; the reply counts `passages_hidden` and names `documents_retained`, the stored documents whose other text stays, and `passages_retained` (with `passages_retained_why`): how many live passages still contain a word of the name but were never linked to it; those stay until forgotten by the passage or source form. `fact`: {from, to, type}: just that one fact; both entities stay. `passage`: the `doc_id` that the remember verb returned: that stored document whole (its chunks, envelope and catalogue entries); the facts and entities it named stay. `source`: the label the documents were stored under (the `source` of a remember): every document filed under it, whole, as the passage form does one; the facts they asserted stay (`facts_kept: true`), and a source that was never stored is 404. `all`: send `all: true` with the `scope` to forget the WHOLE scope: every entity, fact, document and passage in it and the scope itself, in one call (the reply counts them and says what is kept); a scope that never existed is 404. An entity name is exact: with no match the call is refused with 404 and up to three close names to check ("Did you mean"); a close match is only suggested, never forgotten. Forgetting is idempotent: forgetting what is already forgotten answers the SAME 200 with `already_forgotten: true` and writes nothing; a thing that never existed is 404. A later remember that names it brings it back. The deleted records stay on disk as dead records (nothing is rewritten in place): forgotten data is unreachable through every door of this node, but it is NOT physically erased today, because the reclaim phase that removes dead bytes has not shipped; until it does, anyone with access to the node's disk or a backup can still read the bytes. `reason` is accepted and not stored.

Parameters:
- all (boolean): Scope form: true forgets the WHOLE scope named by scope, every entity, fact, document and passage in it, and the scope itself. A scope that never existed is 404; the same call again answers already_forgotten.
- attribute (object): Attribute form: {"subject": "<exact entity name>", "key": "<attribute key>"}: forgets that one attribute (every value of a multi key); the entity and its other attributes stay.
- fact (object): Fact form: the one fact to forget, spelled as memory_relate took it. Both entities stay.
- passage (string): Passage form: the `doc_id` the remember verb returned for the stored document, as its decimal STRING, exactly as the reply gave it (an id is a 64-bit integer: as a JSON number above 2^53 it has already lost digits in most clients).
- reason (string)
- source (string): Source form: the label the documents were stored under; every document filed under it is forgotten whole. The facts those documents asserted stay.
- subject (string): Entity form: the exact entity name to forget (a close spelling is suggested in the 404, never forgotten).
- user_id (string): Optional END USER inside your key (one app, many end users): every scope you name is then that end user's own, and two end users never meet. App-level separation, as mem0's user_id; a per-user token stays the security boundary. When the connection sets the X-Semurg-User header, that header IS the end user and a different user_id is refused. No ':', at most 256 bytes.

### memory_context (read-only)

Retrieve what the memory holds that is relevant to a question or a few words, ranked, each item with its `citation` (GraphRAG over one scope; the citation names the document that sources the item and the sentence it quotes). Every word or phrase of `query` that names a stored entity (exact, a similar spelling or letter case, one whole word of a longer name such as "Priya" for Priya Raman, or the start of a word such as "Pri") or a stored type ("which companies") becomes a seed; small English words such as "the", "of", "is", "who", "tell", "me" or "about" never match on their own. The graph is walked `hops` steps out from the seeds, and the ranked facts and the passages that mention them come back with their text, `citation` (`citation.source`: `kind` document, or asserted for a fact an agent sent without text; the `doc_id` of the document it was read from; the `name` label it was stored under; `ingested_at`. `citation.span`: the sentence quoted from that document, `start` and `end` in Unicode code points of its full text, checked before it is served, or null with `span_state` saying why. `citation.found_by`: how it was found), `source_date` and the seed that found each. No model is called: YOU write the answer from what comes back and cite `citation.source.doc_id` (quote `citation.span.text`). When nothing matches, `state` is nothing_stored and `items` is empty (`seeding` says what each stage did); could_not_judge names the stage that could not run. A fact with `direction` derived (`derived: true`) was not stored: it follows from stored facts by its relation's meaning (symmetric: married_to, spouse_of, sibling_of; inverse: parent_of and child_of, owns and owned_by, employs and employed_by, manages and managed_by; transitive, up to 6 links: part_of, located_in, contained_in), and `citation.found_by.reasoning` names the rule and the stored facts it rests on, each one recallable on its own. `meaning` reads not_armed until an embedding model is armed: a paraphrase that shares no name with the question is not found until then. Once armed, the question is embedded and scored against this scope's passages beside the name and word sources (`seeding.meaning` says ran, with `coverage` incomplete while passages still wait for their vectors). Two limits, by name: entity names (labels) and the sentences of facts are not embedded, so a fact you stored without a passage is not found by meaning; and the meaning search is exact up to 10,000 passages per scope, above which it answers could_not_judge naming the count, never a partial list, until the per-scope index lands. A match by meaning ALONE must clear the embedding model's calibrated cosine floor: a subject nothing holds answers nothing_stored, never the nearest passage. A stored name that shares ONE ordinary word with a longer question can come back as if it answered it ("capital" in a question about France matches a stored "Capital One"): read the reply's `grounding` before relying on them: grounded means ONE cited item covers every content word of your question (words covered only across several items are `related`, reason `covered_only_across_items`); grounded_by_meaning means a cited passage found by MEANING answers a REWORDED question, one that names no stored entity exactly and no name the passage lacks (the words it does not share are listed as `uncovered`; a meaning hit about a thing the question names is `related`, because being about it is not stating the answer): read it, and answer from it when it does answer; related (with the `uncovered` words, and the stored names that matched as `related`), uncited, nothing_stored and could_not_judge mean the facts do NOT answer the question, so say so instead of answering from them. `source_id` is the id of the node the item is made from (a passage: its chunk; a fact: the entity at its other end; an entity or type: itself), NOT of the document that sources it: that is `citation.source.doc_id`. Read-only. Ids (`source_id`, `seed_ids`, `citation.source.doc_id`) are decimal STRINGS of a 64-bit unsigned integer: send them back unchanged and never convert them to a number (a JavaScript Number cannot hold one).

Parameters:
- query (string, required): A question or a few words; the entity names and type words inside it are what is matched (exact, a close spelling or letter case, one whole word of a longer name, or the start of a word); small English words such as "the" or "of" are not matched on their own.
- as_of (string): Read the memory as it was KNOWN at this instant (ISO 8601 date or date-time; a bare date is the end of that day UTC): a fact stored after it is not visible. Leave it out for now.
- compact (boolean): true: each item ONCE (text, kind, the fact's subject / relation / object, doc_id, source, date, score, seed) without the retrieval diagnostics (chunks, seeds, seeding, traversal): a fraction of the bytes. Leave it out for the full reply.
- hops (integer 0 to 3): How far to walk from the matched entities (default 2).
- k (integer 1 to 100): Most facts to return (default 8).
- user_id (string): Optional END USER inside your key (one app, many end users): every scope you name is then that end user's own, and two end users never meet. App-level separation, as mem0's user_id; a per-user token stays the security boundary. When the connection sets the X-Semurg-User header, that header IS the end user and a different user_id is refused. No ':', at most 256 bytes.
- valid_at (string): Read what was TRUE at this instant (ISO 8601), whatever was known since. With as_of: as known at as_of, true at valid_at.

### memory_document (writes)

Store a DOCUMENT (a PDF, a Word .docx, an HTML page or a UTF-8 text file) as memory in one call: its bytes land in this node's customs, its text is parsed (paragraphs, headings and list items in order; PDF paragraphs are rebuilt from the page layout, not one per line), stored exactly as the remember verb stores `content`, read back byte for byte, and only then is the file deleted from customs. The reply carries `doc_id` (the source id every later citation names, a decimal STRING), the parsed `text` (citation offsets index it) and `blocks` (each block's page, paragraph and byte span in the text) when the text is at most 16384 bytes (over that, `text_bytes` and `block_count` instead: the text is stored whole and found by recall and context), and `customs.emptied`. Send the file as `content_base64` (standard base64), at most 5000000 bytes once decoded; `name` is the label stored with it (optional). The kind is read from the file's own first bytes, never from its name. A file that is not a document of those kinds is refused before anything is stored (415); a truncated or corrupt document is refused BY NAME (document_corrupt, 422) and nothing is stored; an encrypted or scanned PDF is document_not_readable (422).

Parameters:
- content_base64 (string, required): The document's bytes, standard base64.
- name (string): The document's name, stored as its provenance label (optional).
- user_id (string): Optional END USER inside your key (one app, many end users): every scope you name is then that end user's own, and two end users never meet. App-level separation, as mem0's user_id; a per-user token stays the security boundary. When the connection sets the X-Semurg-User header, that header IS the end user and a different user_id is refused. No ':', at most 256 bytes.

### comms_bind_address (writes)

Bind an address `name@<cluster domain>` to YOU (your token's identity, or the end user you name with `user_id`), so humans and agents on this cluster can message you by name. Humans and agents bind through the identical call; `kind` says which you are (`user`, the default, or `agent`). Idempotent: binding the same address again answers `bound: "already"`. Refused by name: `address_invalid` (ASCII letters, digits, `.`, `-`, `_`, `+` only, exactly one `@`), `domain_not_ours` (the cluster's domains are listed in the fix), `address_taken` (bound to someone else), `kind_invalid`. A write: it needs an API token.

Parameters:
- address (string, required): The address to bind, `name@<cluster domain>`; case folds (Alice@Acme.com = alice@acme.com).
- kind (string): What the bound principal is: `user` (a human; the default) or `agent`.
- user_id (string): Optional END USER inside your key (one app, many end users): the address is then that end user's. When the connection sets the X-Semurg-User header, that header IS the end user and a different user_id is refused.

## The same verbs over HTTP

Each route takes a JSON body with the same fields as the tool of the same name, and the header `Authorization: Bearer <token>`.

    GET /v1/memory/status
    POST /v1/memory/remember
    POST /v1/memory/recall
    POST /v1/memory/relate
    POST /v1/memory/forget
    POST /v1/memory/context
    POST /v1/memory/document
    POST /v1/memory/delete_user

Both examples ran against a fresh node on release r11.83.20261013.c03a884, and each answer was read back; they have not been re-run on r11.101. They use http://localhost:4000, the address a fresh node serves; behind your own TLS proxy use its https address instead. Set SEMURG_API_TOKEN to your node's API token.

    curl -sS http://127.0.0.1:4000/v1/memory/remember \
      -H "Authorization: Bearer $SEMURG_API_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"scope":"demo","facts":{"entities":[{"name":"Acme","type":"Company"},{"name":"Dana","type":"Person"}],"relations":[{"source":"Dana","target":"Acme","type":"WORKS_AT"}]},"source":"curl example"}'

    curl -sS http://127.0.0.1:4000/v1/memory/recall \
      -H "Authorization: Bearer $SEMURG_API_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"scope":"demo","subject":"Dana"}'

## The clients

Eleven languages in one archive, https://one.semurg.io/dl/clients.tar.gz, with CONNECTING.md, the guide to pointing a client at your node. A client takes the base URL of your node and its token. The memory calls each client defines, in its own spelling:

- Python (clients/python/semurg/client.py): memory_status, remember, recall, relate, forget, context
- Go (clients/go/semurg/client.go): MemoryStatus, Remember, Recall, Relate, Forget, Context
- Java (clients/java/src/main/java/io/semurg/client/SemurgClient.java): memoryStatus, remember, recall, relate, forget, context
- C# (clients/csharp/Semurg.Client/SemurgClient.cs): MemoryStatus, Remember, Recall, Relate, Forget, Context
- F# (clients/fsharp/Semurg.Client.FSharp/Client.fs): memoryStatus, remember, recall, relate, forget, context
- Elixir (clients/elixir/lib/semurg/client.ex): memory_status, remember, recall, relate, forget, context
- Erlang (clients/erlang/src/semurg_client.erl): memory_status, remember, recall, relate, forget, context
- Rust (clients/rust/src/client.rs): memory_status, remember, recall, relate, forget, memory_context
- Julia (clients/julia/src/client.jl): remember, recall, context
- C++: no memory calls in this client yet; it reaches them over HTTP (checked in clients/cpp/src/client.cpp)
- OCaml (clients/ocaml/lib/client.ml): memory_status, remember, recall, relate, forget, context

Download it and check it against the release's own checksums:

    curl -fsSLO https://one.semurg.io/dl/clients.tar.gz
    curl -fsSLO https://one.semurg.io/dl/SHA256SUMS
    sha256sum -c --ignore-missing SHA256SUMS

## Packages: what exists

Everything Semurg publishes comes from one.semurg.io: the installer (https://one.semurg.io/install, the bundle https://one.semurg.io/dl/semurg-r11-installer.tar.gz, checked against https://one.semurg.io/dl/SHA256SUMS) and the clients archive above. The MCP server is built into the node (POST /v1/mcp above): there is nothing to install for it.

Semurg publishes no package on PyPI, npm, crates.io, NuGet, Hex, Maven Central, the Go module proxy, the Julia General registry, opam and the MCP registry today. A package on these registries that claims to be Semurg's is not ours: do not install it.

## Building an app on a node

There are two kinds of app. An EXTERNAL app, in any language and any web framework, keeps its data in a node through the node's public API (the memory routes, /v1/ingest, /v1/query and its operations, the MCP tools, or a client): the node is its store, and nothing below applies to it. Build this kind today. An IN-NODE app is an Elixir extension that runs inside the node on the capabilities the node ships with, which Semurg calls packs; it will be published through the Marketplace only when the composition check passes (the check exists today; the publish and install path for in-node apps is still being built). Each rule below is one the check enforces, for IN-NODE apps only:

- An app brings no database of its own: the node is the store, and the app reaches it only through the node's public read and write API.
- An app builds only on packs: never on another app or on the node's own internals, and no chain of apps and packs ever loops back on itself.
- Across packs, an app uses only what a pack declares it exposes.
- A web interface is Phoenix LiveView. A controller-only or JSON-only surface is refused.

## Pages

- https://one.semurg.io/: Semurg is the memory layer for AI agents and agent frameworks: one shared memory over MCP or plain HTTP that outlives the session, with a knowledge graph, vector search and graph RAG built in, bigger than RAM, on your own hardware. One engine, written from scratch, for ten data domains, each measured in the open. The first node is free, forever.
- https://one.semurg.io/agents: A shared memory for AI agents: remember, recall, relate and forget facts and relationships through MCP or plain HTTP, in the same store that serves your graph, vector and retrieval work.
- https://one.semurg.io/develop: Build vector and graph RAG on one engine: vectors and graph on one copy of your data, relationships written as you write the data, and no new query language to learn.
- https://one.semurg.io/commands: Every command Semurg tells you or your coding agent to run, read from the source and run against each published release. This file, as a page.
- https://one.semurg.io/blog: The Semurg blog: announcements, how-to guides for agents and developers, engineering deep dives and thought leadership, every number linked to its record.
- https://one.semurg.io/models: Open language and retrieval models, each with the speed one user sees and the total across many users, generated from the release record.
- https://one.semurg.io/scale: Start on a free first node with no time limit, then licence more nodes for capacity. A node is a node: the licence does not change with its cores, memory or disks.
- https://one.semurg.io/performance: Write, read, traverse and scan, measured on the whole cluster at every release, with the machine, the door, the concurrency, the utilisation and where the data was served from behind each figure, and its trend across releases.
- https://one.semurg.io/benchmark: Re-measuring every domain on new hardware, in RAM and bigger than RAM together; results land domain by domain. Each result will name the release and the machine it was measured on.
- https://one.semurg.io/pricing: A flat licence per node: bought once for the life of that hardware, or annually at the lifetime price spread over a five-year working life. The first node is free, forever. Support is optional at 20% of the lifetime list price per year, and updates are free from the Marketplace.
- https://one.semurg.io/consulting: We build an organisation's enterprise in a box on Semurg: its databases, object stores and documents synced into one knowledge graph with an ontology, and persistent agents working on it, on your own hardware. Priced on request; the node licences are bought separately.
- https://one.semurg.io/install: Download the installer, check it against the published checksums, and run a node on your own machine. The first node is free, forever. No account, no upload, no call home.
- https://one.semurg.io/contact: Talk to the two people who built Semurg. Email semurg@semurg.org: a real person reads every message, and replies. Tell us what you are working on and what you need the engine to do.
