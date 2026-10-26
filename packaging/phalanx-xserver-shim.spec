Name:           phalanx-xserver-shim
Version:        1
Release:        1%{?dist}
Summary:        Xwayland virtuals for Hyprland on Terra X bases (Phalanx image build helper)
License:        MIT
URL:            https://github.com/syndr/phalanx
BuildArch:      noarch
# Installs no files. Supplies the two virtuals the Hyprland copr builds
# require, which are otherwise only provided by xorg-x11-server-Xwayland
# (and its -devel) — a package that hard-conflicts with the Terra X server
# shipped in the Bazzite fc44 base commit. See packaging/README.md.
Provides:       xorg-x11-server-Xwayland(x86-64)
Provides:       pkgconfig(xwayland)

%description
Phalanx image build helper. Provides xorg-x11-server-Xwayland(x86-64) and
pkgconfig(xwayland) without files, so Hyprland installs on Bazzite bases that
ship Terra X (terra-xorg-x11-server-Xwayland, which conflicts with the
classic Xorg Xwayland server). Installs nothing and is only used by
build/hyprland/build.sh when the base carries Terra X.

%files
