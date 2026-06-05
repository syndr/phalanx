# swaylock-plugin Screensaver Lockscreen — phalanx (image) plan

## Scope

phalanx provides the **system-level runtime dependencies** in the **`hyprland`
variant image** so the swaylock-plugin xscreensaver lockscreen works out of the
box. This is one of three coordinated pieces:

| Piece | Repo / task | Provides |
|---|---|---|
| **This (phalanx)** | `~/ultroncore/phalanx` | the RPMs + xscreensaver hacks + `/var/lib/xkb` + PAM in the image |
| Hyprland config | `syndr/hyprland-wm-config` @ `feat/swaylock-screensaver-lockscreen` | lock wiring (`hypridle` `lock_cmd`), the lock launcher, rofi hack picker |
| RPM build | CI on `syndr/swaylock-plugin` (separate task) | F44 RPMs for `swaylock-plugin` (+ `windowtolayer`) |

phalanx must ensure these exist in the image (binaries on `PATH` in `/usr/bin`,
hacks in `/usr/libexec/xscreensaver/`, `/var/lib/xkb` writable at boot, PAM
service present). It does **not** ship the Hyprland config (that's the dotfiles
repo, deployed by `copy.sh`).

---

## What phalanx must add (hyprland variant)

1. **`swaylock-plugin` + `windowtolayer` RPMs** (from the fork's build — see
   "Dependency" below).
2. **xscreensaver hacks incl. GL** — Fedora repos:
   `xscreensaver-extras xscreensaver-extras-gss xscreensaver-gl xscreensaver-gl-base`
   (the GL hacks like `glmatrix` are in `xscreensaver-gl`). The heavy `ldd` tree
   (ffmpeg/samba/glycin/...) is already in the Bazzite base, so this is light.
3. **`/var/lib/xkb`** created at boot via `systemd-tmpfiles` (see the ostree note
   — this is the easy-to-get-wrong part).
4. **PAM** `/etc/pam.d/swaylock-plugin` — should come from the RPM; verify.
5. Keep `hyprlock` (already installed) — the config uses it as the `lock_cmd`
   fallback.

---

## Dependency: the swaylock-plugin / windowtolayer RPMs (COPR)

**Channel: COPR** (decided). A Fedora COPR project owned by `syndr` builds and
serves the F44 RPMs; phalanx consumes them with the same `dnf copr enable` +
`rpm-ostree install` pattern `build/hyprland/build.sh` already uses for five
other repos. Only the COPR owner needs a (free) Fedora account — the image build
and any user enable/install anonymously.

- **Source: the fork `git@github.com:syndr/swaylock-plugin.git` (`main`)** — NOT
  upstream `mstoeckl`. The fork carries three required fixes, most critically a
  **`SIGCHLD` reset** without which Xwayland-hosted hacks fail to start
  (`XKB: Couldn't compile keymap`). See the fork's git log / README.
- **`windowtolayer`** (separate Rust project,
  `https://gitlab.freedesktop.org/mstoeckl/windowtolayer`) is packaged in the
  **same COPR**.

### Build trigger: GitHub releases → COPR

The RPM packaging + build automation lives in the fork (separate task — see the
fork's `docs/rpm-copr-packaging-plan.md`); summarized here so the phalanx side
knows what it consumes:

- COPR project `syndr/swaylock-plugin`, chroot `fedora-44-x86_64` (+ `aarch64` if
  the image matrix needs it), holding two packages: `swaylock-plugin`,
  `windowtolayer`.
- A GitHub Actions workflow on the fork fires on `release: [published]`, builds
  the SRPM(s), and submits them to COPR via `copr-cli build` (COPR API token in a
  GH secret). COPR builds in clean chroots, signs, and publishes repodata.
- So: tag a release on the fork → new RPMs in COPR → phalanx's next image build
  pulls the latest. (Release-gated via Actions gives explicit version control vs
  COPR's push-triggered auto-rebuild.)

---

## Changes to `build/hyprland/build.sh`

Mirror the existing structure (COPR array + `rpm-ostree install` + `install -Dm644`
for shipped files):

```bash
# in copr_repos=( ... )
    syndr/swaylock-plugin        # swaylock-plugin (+ windowtolayer) F44 RPMs

# in hyprland_packages=( ... )
    # Screensaver lockscreen (swaylock-plugin + xscreensaver hacks)
    swaylock-plugin windowtolayer
    xscreensaver-extras xscreensaver-extras-gss
    xscreensaver-gl xscreensaver-gl-base
```

(Keep `hyprlock hypridle` as-is.)

---

## `/var/lib/xkb` — MUST use systemd-tmpfiles (ostree nuance)

**`/var` is not shipped in the image.** A `mkdir /var/lib/xkb` in `build.sh`
(or `ostree container commit`) will NOT persist — `/var` is machine-local state
populated at boot. Create the directory with a tmpfiles.d entry instead.

Why it's needed: under swaylock-plugin's nested (seatless) compositor, each
Xwayland (one per output) compiles its core keyboard via `xkbcomp`, which writes
`/var/lib/xkb/server-N.xkm`. Bazzite ships Xwayland **without**
`xorg-x11-server-common`, so the directory is absent and the compile fails
(`Failed to activate virtual core keyboard`). Mode **1777** (sticky,
world-writable like `/tmp`) is required because Xwayland runs rootless and the
normal `0755 root` dir would be unwritable.

Ship a tmpfiles config (store it in-repo, e.g.
`build/hyprland/files/tmpfiles.d/swaylock-plugin-xkb.conf`):

```
# Xwayland compiled-keymap output dir, needed by swaylock-plugin's seatless
# Xwayland wallpaper path. /var is not in the image, so create it at boot.
d /var/lib/xkb 1777 root root -
```

Install it in `build.sh`:

```bash
install -Dm644 "${SCRIPT_DIR}/files/tmpfiles.d/swaylock-plugin-xkb.conf" \
    /usr/lib/tmpfiles.d/swaylock-plugin-xkb.conf
```

(Verify whether simply installing `xorg-x11-server-common` is preferable — but
its dir is `0755 root`, so a tmpfiles override to `1777` is still needed for the
rootless write. The explicit tmpfiles entry is the reliable, self-contained fix.)

---

## PAM

`/etc/pam.d/swaylock-plugin` must exist with `auth include login`. The
swaylock-plugin RPM **should** ship it (Meson installs `pam/swaylock-plugin` to
`sysconfdir/pam.d`; with a `/usr` prefix `sysconfdir=/etc` → `/etc/pam.d`). In
ostree, RPM-shipped `/etc` files land in `/usr/etc` and merge at boot — fine.

If the RPM does NOT ship it, add it in `build.sh` during image build (writing to
`/etc/pam.d/swaylock-plugin` in the build persists via `/usr/etc`). **Confirm
with the CI/RPM task** which side owns this.

---

## Background (cross-reference — handled by the RPM/config, don't re-derive here)

- **Runs on the host** from `/usr/bin` (the RPM target); PAM auth + the nested
  compositor's inherited fd both require host execution, not a container.
- **The fork's fixes are mandatory in the RPM** — `SIGCHLD` reset (critical),
  multi-output use-after-free crash fix, `__DATE__` cosmetic.
- **Hacks** live in `/usr/libexec/xscreensaver/` (not `/usr/lib/...`). GL + 2D
  once `xscreensaver-gl` is layered.
- **GL × multi-monitor perf:** `--command-each` runs one Xwayland per output (4
  on this host); GL hacks are heavier — validate before defaulting to one.
- The **Hyprland config** (lock wiring, rofi picker, preview) is in
  `hyprland-wm-config`; phalanx only guarantees the deps exist.

---

## Tasks (phalanx)

1. **(Provided by the fork's COPR task)** the `syndr/swaylock-plugin` COPR exists
   with `swaylock-plugin` + `windowtolayer` built for `fedora-44`,
   release-triggered. phalanx is unblocked once it does.
2. `build/hyprland/build.sh`: add `syndr/swaylock-plugin` to `copr_repos`; add `swaylock-plugin
   windowtolayer xscreensaver-extras xscreensaver-extras-gss xscreensaver-gl
   xscreensaver-gl-base` to `hyprland_packages`.
3. Add `build/hyprland/files/tmpfiles.d/swaylock-plugin-xkb.conf` and install it
   to `/usr/lib/tmpfiles.d/` in `build.sh`.
4. Verify the PAM file ships from the RPM; if not, add it in `build.sh`.
5. Build locally and verify:
   ```
   podman build -f Containerfile --build-arg VARIANT=hyprland -t phalanx-hyprland .
   ```
   Check: `swaylock-plugin`/`windowtolayer` present; `/usr/libexec/xscreensaver/`
   populated incl. `glmatrix`; `/usr/lib/tmpfiles.d/swaylock-plugin-xkb.conf`
   present; `/etc/pam.d/swaylock-plugin` present. (tmpfiles only materializes
   `/var/lib/xkb` on a booted system — confirm post-deploy.)
6. Mind the NVIDIA matrix build — confirm GL hacks work under Xwayland on the
   `-nvidia` image (GLX/EGL via the proprietary stack).

---

## Open questions

- **Does the RPM ship the PAM file and `example_xwayland_wrapper.py`?** Affects
  whether phalanx adds PAM and whether `hyprland-wm-config` vendors the wrapper
  or references an RPM path.
- **windowtolayer packaging owner** — same fork CI/COPR, or separate?
- **`/var/lib/xkb` mode** — `1777` (matches the working ad-hoc fix); confirm
  acceptable vs a narrower scheme.
- **Variant scope** — `hyprland` only (yes). Keep `hyprlock` (yes, fallback).

## References / related work

- swaylock-plugin fork (RPM source): `git@github.com:syndr/swaylock-plugin.git`
  (`main`) — fixes + `contrib/build-env.sh` + expanded README.
- windowtolayer: `https://gitlab.freedesktop.org/mstoeckl/windowtolayer`.
- Config half (the other plan): `syndr/hyprland-wm-config` @
  `feat/swaylock-screensaver-lockscreen` →
  `docs/swaylock-screensaver-lockscreen-plan.md`.
- RPM build (separate task on the fork): COPR `syndr/swaylock-plugin`,
  release-triggered via GitHub Actions → see the fork's
  `docs/rpm-copr-packaging-plan.md`.
- Pattern to mirror: `build/hyprland/build.sh` (`copr_repos`, `rpm-ostree
  install`, `install -Dm644` for `60-custom.just`).
- ostree `/var` + tmpfiles:
  `https://coreos.github.io/rpm-ostree/container/` and
  `systemd-tmpfiles`/`tmpfiles.d(5)`.
