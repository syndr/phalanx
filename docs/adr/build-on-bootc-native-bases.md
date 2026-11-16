# Build on bootc-native bazzite bases

## Status

Accepted — 2026-11-16. Implemented on branch `fix/bootc-fc45-build`;
build-verified locally against `bazzite:stable` (Fedora 45, `45.20261105`).

## Context

`ghcr.io/ublue-os/bazzite:stable` was promoted from fc44 (`44.20261026`) to
fc45 (`45.20261103`+) on 2026-11-04. The fc45 base is **bootc-native**
("Image Mode"): the rootfs carries no ostree repo or deployment
(`/sysroot/ostree` is absent, `/ostree` a dangling symlink), the `ostree` CLI
no longer has a `container` subcommand, and `rpm-ostree` in container mode
fails with "This system was not booted via libostree".

The legacy build flow — `rpm-ostree install` / `override remove` followed by
`ostree container commit` — therefore broke all four variants at once: last
green scheduled build 2026-11-03 (fc44 base), every run from 2026-11-09
failing (fc45 base). Upstream deprecated `ostree container commit` in favor
of `bootc container lint` (bazzite #2145, bootc #2504), and independent
downstream projects hit the identical wall on the same dates and migrated to
plain dnf + lint (bsherman/bos #66, otonm/bazzite-custom #41,
malarinv/whiteblossom-os #60).

## Decision

1. **Package changes go through `dnf5`** (`install` / `remove`) directly on
   the container rootfs — plain OCI layers, no ostree staging.
2. **Replace the `ostree container commit` step** with `dnf5 clean all` plus
   removal of dnf cache/log, then `bootc container lint` (the supported
   build-time validation; non-fatal `/var`-content warnings are expected).
3. **Keep tracking the floating `bazzite:stable` tag** — UBI's stable
   channel; the fc44 images are no longer built, so pinning would freeze
   security updates.
4. **Keep behavioral gates as-is:** the hyprland Terra X removal (the fc45
   base still ships `terra-xorg-x11-server-Xwayland`) and the Qt version
   gate protecting the nvidia base's Qt stack (dnf *can* replace
   `qt6-qtbase` in the rootfs, unlike rpm-ostree, but we don't want to
   upgrade the nvidia base's Qt under it).

## Consequences

### Positive

- Builds track UBI's current stable again; the image is a standard
  bootc-native derived image.
- The derived image keeps the base's bootc metadata (config labels
  `containers.bootc`, `ostree.bootable`; manifest annotations in OCI
  format). It has no `ostree.final-diffid` config label — same as the base —
  so bootc imports it exactly as it imports the base: every layer as a
  derived rootfs layer. (`ostree container commit` images instead carried a
  stale `ostree.final-diffid` label pointing at a diffid absent from their
  squashed layers — bazzite #1892.)
- `workstation-nofun` now genuinely removes steam/lutris from the rootfs
  (previously excluded from the commit but present on disk) — smaller image.

### Negative / constraints

- **Consumer-visible:** rebasing an fc44 system is a full upgrade to
  Fedora 45; layered packages are gone (no "layered" entries in
  `rpm-ostree status`), and updates follow the image via bootc. Called out
  in the README.
- **The floating base can still move under us** — it did, breaking the
  build. A future fc bump needs another build-script pass (COPR chroots,
  package availability) before the next scheduled build.
- Lint warnings about `/var` content are expected: the dnf flow creates
  `/var` directories in an image whose base has no `/var` at all.

## References

- bazzite #2145 (deprecation), #1892 (derived-image rebase failure on the
  legacy flow); bootc #2504 (`ostree container commit` → `bootc container
  lint`); bootc docs on manifest layout and `ostree.final-diffid`.
- Downstream migrations of the same shape: bsherman/bos#66,
  otonm/bazzite-custom#41, malarinv/whiteblossom-os#60.
