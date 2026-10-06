# Veshell - Fedora source RPM.
#
# Generated from packaging/templates/veshell.spec.in by
# packaging/scripts/render-recipes.py. Do not edit by hand.
#
# Same hermetic model as the Arch package: the Dart shell is compiled from
# source against the pinned official Flutter SDK and engine artifacts, then the
# Rust compositor is compiled offline from vendored crates. Nothing is fetched
# during %build.
#
# Flutter is not in Fedora, so the pinned SDK/engine inputs are carried as
# Sources (they belong in the lookaside cache). build-veshell.sh is a copy of
# packaging/scripts/build-veshell.sh and must stay in sync with it.
#
# Official Fedora review would additionally require the Flutter SDK and engine
# to be packaged separately (Flutter and the Flutter engine are not in Fedora);
# that blocker is documented in packaging/README.md. This spec is intended for
# a COPR / self-hosted repository.

%global commit f7180fe48c8ba75c08d3ae7c38e6b7bc27ea85fe
%global shortcommit f7180fe
%global flutter_version 3.47.2
%global engine_revision a804b261645ef8c13eb3d5c44a5c2fb0340c5539
%global artifact_base https://storage.googleapis.com/flutter_infra_release/flutter/%{engine_revision}
%global input_mirror https://github.com/free-explorers/veshell/releases/download/packaging-inputs-v0.1.0

%global debug_package %{nil}

# Fedora enables LTO by default. The libspa-sys build script compiles a C shim
# into a static archive; LTO objects there are not resolved by rustc's final
# (non-LTO) link. Disable LTO for this package.
%global _lto_cflags %{nil}

Name:           veshell
Version:        0.1.0
Release:        1%{?dist}
Summary:        An innovative Not-Desktop environment for Linux built with Flutter and Rust
License:        GPL-3.0-or-later
URL:            https://github.com/free-explorers/veshell
Source0:        https://github.com/free-explorers/veshell/archive/%{commit}/veshell-%{commit}.tar.gz
Source1:        build-veshell.sh
# https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_%{flutter_version}-stable.tar.xz
Source2:        flutter_linux_%{flutter_version}-stable.tar.xz
# %{artifact_base}/common/flutter_patched_sdk.zip
Source3:        flutter_patched_sdk.zip
# %{artifact_base}/common/flutter_patched_sdk_product.zip
Source4:        flutter_patched_sdk_product.zip
# %{artifact_base}/linux-x64/artifacts.zip
Source5:        linux-x64_artifacts.zip
# %{artifact_base}/linux-x64-debug/linux-x64-flutter-gtk.zip
Source6:        linux-x64-debug_flutter-gtk.zip
# %{artifact_base}/linux-x64-profile/linux-x64-flutter-gtk.zip
Source7:        linux-x64-profile_flutter-gtk.zip
# %{artifact_base}/linux-x64-release/linux-x64-flutter-gtk.zip
Source8:        linux-x64-release_flutter-gtk.zip
# https://github.com/meta-flutter/flutter-engine/releases/download/linux-engine-sdk-release-x86_64-%{engine_revision}/linux-engine-sdk-release-x86_64-%{engine_revision}.tar.gz
Source9:        linux-engine-sdk-release-x86_64-%{engine_revision}.tar.gz
Source10:       veshell-cargo-vendor-0.1.0.tar.zst
Source11:       veshell-pubcache-0.1.0.tar.zst

# Runtime dependencies (fonts, DRM/GL, session bus, audio, capture, portals).
Requires:       fontconfig
Requires:       google-roboto-fonts
Requires:       google-noto-sans-fonts
Requires:       google-noto-sans-arabic-fonts
Requires:       google-noto-sans-bengali-fonts
Requires:       google-noto-sans-devanagari-fonts
Requires:       google-noto-sans-cjk-fonts
Requires:       mesa-libgbm
Requires:       libglvnd
Requires:       libinput
Requires:       libseat
Requires:       libdisplay-info
Requires:       libxkbcommon
Requires:       systemd-libs
Requires:       pipewire
Requires:       pulseaudio-libs
Requires:       gstreamer1
Requires:       gstreamer1-plugins-base
Requires:       gstreamer1-plugins-good
Requires:       dbus
Requires:       upower
Requires:       polkit
Requires:       xorg-x11-server-Xwayland
Requires:       xdg-desktop-portal
Requires:       xdg-utils

Recommends:     NetworkManager
Recommends:     bluez
Recommends:     rtkit
Recommends:     xdg-desktop-portal-gtk

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  clang
BuildRequires:  cmake
BuildRequires:  ninja-build
BuildRequires:  pkgconf
BuildRequires:  git
BuildRequires:  unzip
BuildRequires:  zstd
BuildRequires:  xz
BuildRequires:  gtk3-devel
BuildRequires:  pulseaudio-libs-devel
BuildRequires:  libinput-devel
BuildRequires:  libseat-devel
BuildRequires:  mesa-libgbm-devel
BuildRequires:  libglvnd-devel
BuildRequires:  openssl-devel
BuildRequires:  pipewire-devel
BuildRequires:  gstreamer1-devel
BuildRequires:  gstreamer1-plugins-base-devel
BuildRequires:  libxkbcommon-devel
BuildRequires:  libdisplay-info-devel
BuildRequires:  wayland-devel
BuildRequires:  systemd-devel
BuildRequires:  vulkan-loader-devel

%description
Veshell is an innovative Not-Desktop environment for Linux made with modern
technologies like Flutter and Rust. It provides a predictable, spatially
organized workflow on top of a Wayland/drm compositor.

%prep
%autosetup -n veshell-%{commit}
mkdir -p %{_builddir}/flutter-sdk %{_builddir}/cargo-vendor %{_builddir}/pubcache
tar -xJf %{SOURCE2} -C %{_builddir}/flutter-sdk --strip-components=1
tar -xf %{SOURCE10} -C %{_builddir}/cargo-vendor
tar -xf %{SOURCE11} -C %{_builddir}/pubcache

%build
export VESHELL_SRC="%{_builddir}/veshell-%{commit}"
export FLUTTER_SDK_DIR="%{_builddir}/flutter-sdk"
export FLUTTER_ARTIFACT_DIR="%{_sourcedir}"
export ENGINE_TARBALL="%{SOURCE9}"
export CARGO_VENDOR_DIR="%{_builddir}/cargo-vendor"
export PUB_CACHE_DIR="%{_builddir}/pubcache"
export POLKIT_HELPER_PATH="/usr/lib/polkit-1/polkit-agent-helper-1"
export PREFIX="%{_prefix}"
export JOBS="$(nproc)"
bash %{SOURCE1} build

%install
export VESHELL_SRC="%{_builddir}/veshell-%{commit}"
export PREFIX="%{_prefix}"
export DESTDIR="%{buildroot}"
bash %{SOURCE1} install

%files
%license LICENSE
%{_bindir}/veshell
%{_bindir}/veshell-session
%{_bindir}/veshell-session-stop
%{_prefix}/lib/veshell/
%{_datadir}/veshell/
%{_datadir}/wayland-sessions/veshell.desktop
%{_datadir}/xdg-desktop-portal/veshell-portals.conf
%{_datadir}/xdg-desktop-portal/portals/veshell.portal
%{_userunitdir}/veshell.service
%{_userunitdir}/veshell-shutdown.target

%changelog
* Tue Oct 06 2026 Veshell packaging <packaging@example.invalid> - 0.1.0-1
- Veshell 0.1.0 (beta).
