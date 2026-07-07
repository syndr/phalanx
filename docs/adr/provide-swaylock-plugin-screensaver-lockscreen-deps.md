# Provide swaylock-plugin screensaver lockscreen dependencies in the hyprland image

## Status

Accepted — 2026-07-04.

Implemented on branch `feat/swaylock-screensaver-lockscreen` (commit `d402c9a`)
and build-verified locally against `bazzite:stable` (Fedora 43).

## Context

The `hyprland` variant should offer an xscreensaver-style **screensaver
lockscreen**: [swaylock-plugin] is a fork of `swaylock` that runs xscreensaver
"hacks" (e.g. `glmatrix`) as the lock background. Making this work out of the box
requires system-level runtime dependencies in the image.

This is one of **three coordinated pieces**; phalanx owns only the first:

| Piece | Repo | Provides |
|---|---|---|
| **This (phalanx image)** | `ultroncore/phalanx` | the RPMs + xscreensaver hacks + `/var/lib/xkb` + PAM in the `hyprland` image |
| Hyprland config | `syndr/hyprland-wm-config` @ `feat/swaylock-screensaver-lockscreen` | lock wiring (`hypridle` `lock_cmd`), the lock launcher, the rofi hack picker |
| RPM build | COPR on `syndr/swaylock-plugin` | F43/F44 RPMs for `swaylock-plugin` (+ `windowtolayer`) |

Forces shaping the decision:

- **The upstream locker does not work under Xwayland unmodified.** swaylock-plugin's
  seatless wallpaper path spawns a nested Xwayland per output; each compiles its
  core keyboard via `xkbcomp`. Upstream `mstoeckl` fails to start Xwayland-hosted
  hacks (`XKB: Couldn't compile keymap`) without a **`SIGCHLD` reset**. The
  `syndr` fork carries that fix plus a multi-output use-after-free crash fix.
- **`xkbcomp` writes `/var/lib/xkb/server-N.xkm`.** Bazzite ships Xwayland
  *without* `xorg-x11-server-common`, so that directory is absent and the compile
  fails. Xwayland runs rootless, so the directory must be world-writable.
- **ostree nuance: `/var` is not in the image.** It is machine-local state
  populated at boot, so a `mkdir` in `build.sh` (or under `ostree container
  commit`) does not persist.
- **Established phalanx pattern.** `build/hyprland/build.sh` already enables five
  COPRs via a `copr_repos` array + `rpm-ostree install`, and ships files with
  `install -Dm644`. A new dependency should mirror this rather than invent a new
  delivery mechanism.

## Decision

Ship the system-level runtime dependencies in the `hyprland` variant image
(`build/hyprland/build.sh`):

1. **Distribution channel: COPR.** Enable `syndr/swaylock-plugin` in `copr_repos`
   and `rpm-ostree install swaylock-plugin windowtolayer`. This matches the
   existing pattern; only the COPR owner needs a (free) Fedora account, while the
   image build and end users consume the repo anonymously.
   *Amended 2026-07-07:* also install `swaylock-plugin-screensaver` (subpackage,
   >= 1.8.6.2) — the canonical lock launcher / rofi hack picker / thumbnail
   generator upstreamed from the dotfiles (fork PR #7), plus
   `xorg-x11-server-Xvfb` for the thumbnail generator (ImageMagick was already
   in the image). The dotfiles' script copies become thin wrappers over the
   packaged `/usr/bin` tools.
2. **Source: the `syndr` fork, not upstream `mstoeckl`.** The fork's `SIGCHLD`
   reset is mandatory for the lockscreen to function; the RPM is built from it.
3. **xscreensaver hacks, including GL, from Fedora:** `xscreensaver-extras`,
   `xscreensaver-extras-gss`, `xscreensaver-gl`, `xscreensaver-gl-base` (GL hacks
   such as `glmatrix` resolve via `xscreensaver-gl-extras`).
4. **Create `/var/lib/xkb` at boot with `systemd-tmpfiles`, not `mkdir`.** Ship
   `build/hyprland/files/tmpfiles.d/swaylock-plugin-xkb.conf` containing
   `d /var/lib/xkb 1777 root root -` and install it to `/usr/lib/tmpfiles.d/`.
   Mode **1777** (sticky, world-writable like `/tmp`) is required because the
   rootless Xwayland instances must write there.
5. **PAM is owned by the RPM.** The `swaylock-plugin` RPM ships
   `/etc/pam.d/swaylock-plugin` as `%config(noreplace)`. `build.sh` writes a
   fallback (`auth include login`) **only if the file is absent**, so it never
   conflicts with the RPM-owned file.
6. **Keep `hyprlock` installed** as the `hypridle` `lock_cmd` fallback.
7. **Scope: the `hyprland` variant only.**

The `example_xwayland_wrapper.py` referenced by the config repo is also
RPM-owned, at `/usr/libexec/swaylock-plugin/example_xwayland_wrapper.py`, so
`hyprland-wm-config` should **reference that path rather than vendor the script**.

## Consequences

### Positive

- The screensaver lockscreen works out of the box on the `hyprland` image;
  dependencies are declarative and update atomically with the image.
- No file-ownership conflicts: the conditional PAM guard and the RPM-owned
  wrapper/PAM keep phalanx's responsibilities and the RPM's cleanly separated.
- Build-verified: binaries on `PATH`, 301 xscreensaver hacks incl. `glmatrix`,
  the tmpfiles rule, the RPM PAM file, and the wrapper are all present in the
  image.

### Negative / constraints

- **Fedora-release coupling.** The COPR must publish a chroot matching the base
  image's Fedora release. `bazzite:stable` is currently **Fedora 43**, and
  `dnf copr enable` resolves `$releasever`→43; an F44-only COPR fails the image
  build at enable-time (`Chroot not found in the given Copr project
  (fedora-43-x86_64)`). **Mitigation:** keep both `fedora-43` and `fedora-44`
  chroots built so the image build survives the eventual bazzite F43→F44 bump.
- **Cross-repo coordination.** The image build is gated on the fork's COPR
  producing RPMs (release-triggered). A version bump on the fork requires a new
  release before it reaches the image.
- **GL × multi-monitor cost.** swaylock-plugin's `--command-each` runs one
  Xwayland per output; GL hacks are heavier. This is a config-side default, but
  the image enables the possibility.

### Follow-ups

- Validate GL hacks under Xwayland on the `-nvidia` matrix image (a *runtime*
  check on booted NVIDIA hardware — not verifiable at container-build time).
- `/var/lib/xkb` only materializes on a booted system; confirm post-deploy.

## References

- swaylock-plugin fork (RPM source): `https://github.com/syndr/swaylock-plugin`
  (`main`) — carries the mandatory `SIGCHLD` reset + multi-output fix.
- windowtolayer: `https://gitlab.freedesktop.org/mstoeckl/windowtolayer`.
- COPR: `syndr/swaylock-plugin` (packages `swaylock-plugin`,
  `swaylock-plugin-screensaver`, `windowtolayer`;
  chroots `fedora-43-{x86_64,aarch64}`, `fedora-44-{x86_64,aarch64}`).
- Config half: `syndr/hyprland-wm-config` @ `feat/swaylock-screensaver-lockscreen`.
- ostree `/var` + tmpfiles: <https://coreos.github.io/rpm-ostree/container/>,
  `tmpfiles.d(5)`.
- Pattern mirrored: `build/hyprland/build.sh` (`copr_repos`, `rpm-ostree
  install`, `install -Dm644`).

[swaylock-plugin]: https://github.com/syndr/swaylock-plugin
