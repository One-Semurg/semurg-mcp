# Semurg Memory: a plugin for Claude Code and Cursor

Your AI forgets. Semurg gives every AI agent one memory that lasts, shared across your tools and your team, with sources.

This plugin connects Claude Code or Cursor to your Semurg memory over MCP and adds a skill that tells the agent when to use it: look up what
the memory already holds before starting a task, store decisions and facts as it works, and answer with the cited source, or say plainly that
nothing is stored.

## What it runs and what it sends

The plugin runs no program. It adds one MCP server entry (HTTP) and one skill. Everything the agent remembers or asks is sent only to the
address you enter, your own Semurg memory (a fresh install serves `http://127.0.0.1:4000/v1/mcp`), with your API token. Nothing is sent to
Semurg or to anyone else.

## 1. Get a Semurg memory

On a Linux x86_64 machine you control (read the script first with the first line):

    curl -fsSL https://one.semurg.io/install | less
    curl -fsSL https://one.semurg.io/install | sudo bash

The installer prints your API token (also saved in `~/.config/semurg/token`). A Docker image is on https://one.semurg.io/develop.

## 2. Install the plugin

**Claude Code**

    /plugin marketplace add One-Semurg/semurg-mcp
    /plugin install semurg-memory@semurg

Claude Code asks for three values: your Semurg address (default `http://127.0.0.1:4000/v1/mcp`), your API token (stored in your system's
secure credential store, never in a settings file) and the memory scope (default `default`; agents that use the same scope share what is
stored). Change them later in `/config`.

**Cursor**

Install Semurg Memory from the Cursor Marketplace, then set `SEMURG_URL`, `SEMURG_API_TOKEN` and `SEMURG_SCOPE` under Plugins in the
dashboard (or at install, with Configure).

## 3. Check it works

Ask the agent: "Remember that the staging database moved to db2 on Monday because of the disk alert." Then, in a new session: "Where is the
staging database, and why?" The answer cites the passage it was stored from.

## Tools

The memory server gives the agent tools to remember, recall, ask for context, relate, forget and check the ontology (`memory_remember`,
`memory_recall`, `memory_context`, `memory_relate`, `memory_forget`, `memory_status`, and more). Every answer says its state:
`answered`, `nothing_stored` or `could_not_judge`. Full reference: https://one.semurg.io/agents

## Licence

Apache-2.0, see the repository's LICENSE.
