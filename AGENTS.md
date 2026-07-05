# AGENTS.md

Canonical, tool-agnostic instructions for AI coding agents working in this
repository (Claude Code, Cursor, Copilot, Aider, etc.). Tool-specific instruction
files (e.g. `CLAUDE.md`) should defer to this file for working conventions.

For what the project *is* and how to build it, see [`README.md`](README.md) and
[`CLAUDE.md`](CLAUDE.md).

## Architecture Decision Records (ADRs)

This project records architecturally significant decisions as ADRs under
[`docs/adr/`](docs/adr/).

- **Before** making an architecturally significant change — adopting a new
  upstream/base image, adding a package delivery channel (COPR, third-party
  repo), a structural build/CI change, or a cross-repo coordination contract —
  add or update an ADR in `docs/adr/`.
- Follow the convention in [`docs/adr/README.md`](docs/adr/README.md): the
  Michael Nygard template, and a present-tense verb-noun filename. Add the new
  record to that file's index.
- Don't edit an accepted ADR to reverse it — add a new ADR that supersedes it.
- Routine work (package bumps, local fixes) does not need an ADR.

When a change lands that implements a decision, reference the ADR in the commit
or PR, and set the ADR's `Status` to `Accepted` with the date.
