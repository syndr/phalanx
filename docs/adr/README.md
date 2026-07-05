# Architecture Decision Records

This directory holds **Architecture Decision Records (ADRs)** — short documents
capturing an architecturally significant decision, its context, and its
consequences. See <https://adr.github.io> for background.

## When to write one

Write an ADR when a change decides something that is costly to reverse or that
future contributors will need the *reasoning* for, not just the result — e.g.
adopting a new upstream/base image, adding a package delivery channel (COPR,
repo), a build-system or CI structural change, or a cross-repo coordination
contract. Skip it for routine package bumps and local fixes.

One decision per record. Records are immutable once accepted: to change a
decision, add a **new** ADR that supersedes the old one rather than editing it.

## Convention

- **Template:** the [Michael Nygard template][nygard] — `Status`, `Context`,
  `Decision`, `Consequences` (add a short `Status` date line).
- **Filename:** a present-tense imperative verb-noun phrase, lowercase with
  dashes, `.md` — e.g. `provide-swaylock-plugin-screensaver-lockscreen-deps.md`,
  `choose-base-image.md`. No number prefixes.
- **Status** progresses through: `Proposed` → `Accepted` → (later)
  `Deprecated` or `Superseded by <adr>`.

## Index

- [Provide swaylock-plugin screensaver lockscreen dependencies in the hyprland image](provide-swaylock-plugin-screensaver-lockscreen-deps.md)

[nygard]: https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
