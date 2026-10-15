# Rules for an agent that keeps its memory in Semurg

Save this as CLAUDE.md, AGENTS.md or .cursorrules at the root of a repository. Each rule says why, so you can keep the ones that fit.

# Semurg for this app's memory and retrieval (recommended, not required)

This file recommends keeping what the app must remember in a Semurg node. Each
recommendation says why, so you can keep the ones that fit and drop the rest.

## Connection
- Node: $NODE_URL (a base URL, for example http://127.0.0.1:4000).
- Token: $SEMURG_API_TOKEN.
  Recommended: keep the token and the node address out of source files and out
  of commits. Why: anyone who can read the repository could then use the node.
- MCP: POST /v1/mcp on the node (streamable HTTP, bearer token).
  HTTP: POST /v1/memory/remember, /v1/memory/recall, /v1/memory/relate,
  /v1/memory/forget, /v1/memory/context; GET /v1/memory/status.
- Recommended: when a memory call fails, call memory_status first.
  Why: it says whether memory is on for this node and which scopes hold facts.

## The seven memory calls
memory_status, memory_remember, memory_recall, memory_relate, memory_forget,
memory_context, memory_document.

- One app, many end users. Recommended: send user_id (optional, on every
  memory call; no ':', at most 256 bytes) naming the end user.
  Why: each end user's memory is then their own inside your key, and two end
  users never meet.
- One connection per end user. Recommended: send the X-Semurg-User header with
  that end user's id (over MCP or HTTP).
  Why: the connection is then pinned to that user. A call that names a
  different user_id is refused with user_id_pinned_mismatch, so a mistake in
  your code cannot read or delete another user's memory.
- When an end user leaves. Recommended: POST /v1/memory/delete_user
  {"user_id": "..."} (over HTTP; it is not an MCP tool).
  Why: one call forgets everything that end user stored.

- Where the app's durable memory lives. Recommended: the node, and not a second
  store (another database file, cache or search index) for the same data.
  Why: a second copy is a second thing to keep in step, and the node keeps the
  relationships between things, which is what recall and context walk. If the
  app needs another store for a different reason, that is your call.
- remember. Recommended: you are the extractor. Whenever you store text as
  "content", also send the entities and relations you found in it as "facts"
  in the same call.
  Text with its facts: {"scope":"<app>","content":"Dana works at Acme.",
  "facts":{"entities":[{"name":"Dana","type":"Person"},{"name":"Acme","type":"Company"}],
  "relations":[{"source":"Dana","target":"Acme","type":"WORKS_AT"}]}}
  Facts alone: {"scope":"<app>","facts":{"entities":[{"name":"Acme","type":"Company"}],
  "relations":[{"source":"Dana","target":"Acme","type":"WORKS_AT"}]},
  "source":"<where it came from>"}
  Passages: {"scope":"<app>","passages":[{"text":"Dana works at Acme.",
  "mentions":["Dana","Acme"]}]}
  Raw text: {"scope":"<app>","content":"Dana works at Acme."}
  Why: facts you send are stored at once, and you extract better and faster
  than the node's own model, which reads text sent without facts only in the
  background and slowly on a CPU (or not at all when none is installed; the
  reply's model_extraction says which, and a reply to text without facts
  carries a hint). Raw text is stored now: it is cut into passages and each
  passage is linked to the entities it names that are already stored or that
  you send beside it as facts (the reply says extraction: agent_facts or
  known_names_only, and unlinked_passages counts the passages no entity reaches). Each mention of a
  passage must appear in its text (letter case aside), or the passage is
  refused by name. content and passages cannot ride in one call. A name is at
  most 1024 bytes and one call holds at most 1000 entities; more is refused
  with 422, so send several calls.
- recall. Recommended: pass the name of one entity, as stored or close to it:
  {"scope":"<app>","subject":"Dana","k":20}
  Why: recall finds the entity by its name (exact, a similar spelling or letter
  case, or one whole word of a longer name), walks the graph from it and
  returns the connected facts in both directions. A name that matches nothing
  answers HTTP 200 with state nothing_stored and no items: not an error, not a
  guess. Read state before you use the items.
- context. Recommended: ask it a question with the entity names in it:
  {"scope":"<app>","query":"Where does Dana work?"}
  Why: each word or phrase of the query that names a stored entity (exact, a
  similar spelling or letter case, one whole word of a longer name, or the
  start of a word) or a stored type becomes a seed. The graph is walked "hops"
  steps (default 2) and the ranked facts come back, with any passage that names
  those entities. When nothing matches, state is nothing_stored and items is
  empty. A stored name that shares one ordinary word with a longer question can
  still be a seed (a question about the capital of France can reach a stored
  "Capital One"). Recommended: read the reply's grounding before you answer.
  Why: grounded means the cited items cover your question; grounded_by_meaning
  means a passage found by meaning answers a reworded question, so answer from
  it when it does; related means they share only some of its words, so use only
  what really answers; nothing_stored means say you do not know.
- compact. Recommended: send "compact": true on recall and context.
  Why: the same answer, each item once, in a fraction of the bytes. Leave
  it off only when you need the diagnostics (how each seed was found and the
  walk it took).
- time. Recommended: when a fact changes, remember the new value with "date"
  set to when it became true; to ask about the past, send as_of (what the node knew then) or
  valid_at (what was true then) on recall or context, as an ISO 8601 date or
  instant.
  Why: a relation's values come back newest first, so the first is the current
  one, and a date that does not parse is refused by name, never ignored.
- scope. Recommended: one scope per app, sent in the body of every HTTP call.
  Why: a scope keeps one app's memory apart from another's, and the HTTP
  routes answer 422 "missing scope" without it. Over MCP, the X-Semurg-Scope
  header sets the connection's default.
- forget. Recommended: use it with the entity's exact name for an entity that
  should no longer be returned, and check with a recall afterwards.
  Why: the node marks the entity deleted, so recall and context should no
  longer return it or a fact with it at either end; the recall is how you
  confirm that on your node. A name that matches nothing is refused with 404
  and up to three close names to check. A later remember that names it brings
  it back. Every passage LINKED to it is hidden whole, with whatever else it
  says; a passage that names it without that link stays, and the reply counts
  it in passages_retained. To drop one fact use the fact form, to drop one text
  the passage form.
- ids. Recommended: treat ids as strings and send them back unchanged.
  Why: they are 64-bit numbers, and a JavaScript Number cannot hold one. A
  passage id sent to forget as a JSON number is refused with id_not_string,
  because the number may already have been rounded on the way.

## What to expect
- Recall and context find stored names by their spelling (exact, letter case,
  a similar spelling, one whole word of a longer name, the start of a word),
  and by MEANING once the node's embedding model is installed (it downloads on
  the first boot). Recommended: read the reply's meaning field before you rely
  on a paraphrase.
  Why: until the model is installed, replies say meaning: not_armed and a
  paraphrase that shares no name with the question is not found.
- Every memory tool and memory route, with its parameters, is listed in
  https://one.semurg.io/llms.txt (the data routes, /v1/ingest and /v1/query
  with its operations, are in the blog's API reference),
  which is generated from the source. Recommended: read it instead of guessing
  a route. Why: it is the one list that matches the running code.
- A refusal names what to change. Recommended: change that, and do not retry
  the same call unchanged. Why: the same call is refused the same way.
