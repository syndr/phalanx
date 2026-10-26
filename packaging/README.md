# phalanx-xserver-shim — image-build helper RPM
#
# Purpose:
#   The Bazzite fc44 base commit (ghcr.io/ublue-os/bazzite:stable) ships Terra X
#   (terra-xorg-x11-server-Xwayland). The Hyprland copr builds require
#   xorg-x11-server-Xwayland(x86-64) and pkgconfig(xwayland) — the arch-
#   qualified virtual is only provided by the classic Xorg Xwayland server
#   (and its -devel), which hard-conflicts with the Terra package in the base,
#   making the transaction unsolvable. Terra provides the *unqualified*
#   xorg-x11-server-Xwayland virtual, which does not satisfy the arch-
#   qualified requirement.
#
#   This package supplies both virtuals with no files, so the Hyprland
#   packages install on the Terra base without pulling the conflicting Xorg
#   server. Hyprland then runs on Terra's Xwayland binary (/usr/bin/Xwayland —
#   same path, drop-in). The image keeps the upstream base untouched: no
#   package removals (ostree containers only allow rpm-ostree install, not
#   remove).
#
#   The shim is inert on bases without Terra X (build.sh only installs it
#   when terra-xorg-x11-server-Xwayland is present), where the classic Xorg
#   server + devel satisfy the requirements normally.
#
# Build (rpmbuild distrobox):
#   cd / && distrobox enter --name rpmbuild -- bash -c \
#     'cd ~/ultroncore/phalanx/packaging && \
#      rpmbuild -bb phalanx-xserver-shim.spec && \
#      cp ~/rpmbuild/RPMS/noarch/phalanx-xserver-shim-*.rpm \
#         ../build/helpers/'
#
# The prebuilt RPM is committed under build/helpers/ so image builds stay
# hermetic (no external copr dependency for a package that never changes).
