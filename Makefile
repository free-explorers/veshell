# Final runtime paths; DESTDIR is only a copy destination.
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/veshell
SHAREDIR ?= $(PREFIX)/share/veshell
SESSIONDIR ?= $(PREFIX)/share/wayland-sessions
PORTALDIR ?= $(PREFIX)/share/xdg-desktop-portal
SYSTEMD_USER_DIR ?= $(PREFIX)/lib/systemd/user

PROFILE ?= release
FLUTTER_MODE ?= $(if $(filter dev,$(PROFILE)),debug,$(PROFILE))
ARCH ?= $(shell uname -m)
ifeq ($(ARCH),x86_64)
ARCH_DIR ?= x64
else ifeq ($(ARCH),aarch64)
ARCH_DIR ?= arm64
endif
CARGO_TARGET_DIR ?= build/target
TARGET ?= $(CARGO_BUILD_TARGET)
RUST_PROFILE = $(if $(filter debug,$(PROFILE)),dev,$(PROFILE))
OUTPUT_PROFILE = $(if $(filter debug dev,$(PROFILE)),debug,$(PROFILE))

# Existing build outputs or independently supplied artifacts.
BIN ?= $(CARGO_TARGET_DIR)/$(if $(TARGET),$(TARGET)/)$(OUTPUT_PROFILE)/veshell
ENGINE_LIB ?= extra/third_party/flutter_engine/$(FLUTTER_MODE)/libflutter_engine.so
APP_LIB ?= src/shell/build/linux/$(ARCH_DIR)/$(FLUTTER_MODE)/bundle/lib/libapp.so
SHELL_LIB_DIR ?= $(shell dirname $(call quote,$(APP_LIB)))
DATA_DIR ?= src/shell/build/linux/$(ARCH_DIR)/$(FLUTTER_MODE)/bundle/data
ASSETS_DIR ?= extra/assets
SETTINGS_DIR ?= extra/settings
INSTALL_ENGINE ?= 1
SERVICE_TEMPLATE ?= $(ASSETS_DIR)/veshell.service.in
SERVICE_OUTPUT ?= build/veshell.service
STAGING_DIR ?= build/package-root

quote = '$(subst ','"'"',$(1))'

.PHONY: all build check-config service package install install-local stage deb rpm uninstall clean

all: build

check-config:
	@case $(call quote,$(FLUTTER_MODE)) in debug|profile|release) ;; *) \
		printf '%s\n' 'Set FLUTTER_MODE=debug, profile, or release for this Rust PROFILE.' >&2; exit 1;; esac
	@if [ -z $(call quote,$(ARCH_DIR)) ] && \
		{ [ -z $(call quote,$(DATA_DIR)) ] || [ $(call quote,$(origin DATA_DIR)) = file ] || \
		  { [ $(call quote,$(origin APP_LIB)) = file ] && [ $(call quote,$(origin SHELL_LIB_DIR)) = file ]; }; }; then \
		printf '%s\n' 'Unsupported ARCH: set ARCH=x86_64/aarch64, ARCH_DIR, or explicit APP_LIB and DATA_DIR.' >&2; exit 1; fi
	@case $(call quote,$(INSTALL_ENGINE)) in 0|1) ;; *) printf '%s\n' 'INSTALL_ENGINE must be 0 or 1.' >&2; exit 1;; esac

build: check-config
	VESHELL_LIB_DIR=$(call quote,$(LIBDIR)) \
	VESHELL_DATA_DIR=$(call quote,$(SHAREDIR)/data) \
	VESHELL_DEFAULT_CONFIG_DIR=$(call quote,$(SHAREDIR)/settings/default) \
	VESHELL_FLUTTER_MODE=$(call quote,$(FLUTTER_MODE)) \
	CARGO_TARGET_DIR=$(call quote,$(CARGO_TARGET_DIR)) \
	cargo build --profile=$(call quote,$(RUST_PROFILE)) $(if $(TARGET),--target=$(call quote,$(TARGET)))

# Always regenerate: a previous install may have used another final prefix.
service:
	@mkdir -p "$$(dirname $(call quote,$(SERVICE_OUTPUT)))"
	@bindir=$$(printf '%s' $(call quote,$(BINDIR)) | sed 's/[\\"]/\\&/g; s/[$$%]/&&/g'); \
	bindir=$$(printf '%s' "$$bindir" | sed 's/[\\&|]/\\&/g'); \
	sed -E "s|@bindir@/([^ ]*)|\"$$bindir/\1\"|g" $(call quote,$(SERVICE_TEMPLATE)) > $(call quote,$(SERVICE_OUTPUT))

package: install

install: check-config
	@test -f $(call quote,$(BIN)) && test -d $(call quote,$(SHELL_LIB_DIR)) && test -d $(call quote,$(DATA_DIR))
	@if [ $(call quote,$(FLUTTER_MODE)) = debug ]; then \
		test -f $(call quote,$(DATA_DIR)/flutter_assets/kernel_blob.bin); \
	else test -f $(call quote,$(APP_LIB)); fi
	@if [ $(call quote,$(INSTALL_ENGINE)) = 1 ]; then test -f $(call quote,$(ENGINE_LIB)); fi
	$(MAKE) service
	install -Dm755 $(call quote,$(BIN)) $(call quote,$(DESTDIR)$(BINDIR)/veshell)
	install -Dm755 $(call quote,$(ASSETS_DIR)/veshell-session) $(call quote,$(DESTDIR)$(BINDIR)/veshell-session)
	install -Dm755 $(call quote,$(ASSETS_DIR)/veshell-session-stop) $(call quote,$(DESTDIR)$(BINDIR)/veshell-session-stop)
	install -Dm644 $(call quote,$(ASSETS_DIR)/veshell.desktop) $(call quote,$(DESTDIR)$(SESSIONDIR)/veshell.desktop)
	# Exec argument escaping precedes desktop-entry string escaping.
	@bindir=$$(printf '%s' $(call quote,$(BINDIR)) | sed 's/[\\"$$`]/\\&/g; s/\\/\\\\/g; s/%/%%/g'); \
	bindir=$$(printf '%s' "$$bindir" | sed 's/[\\&|]/\\&/g'); \
	sed "s|^Exec=veshell-session$$|Exec=\"$$bindir/veshell-session\"|" $(call quote,$(ASSETS_DIR)/veshell.desktop) > $(call quote,$(DESTDIR)$(SESSIONDIR)/veshell.desktop)
	install -Dm644 $(call quote,$(ASSETS_DIR)/veshell-portals.conf) $(call quote,$(DESTDIR)$(PORTALDIR)/veshell-portals.conf)
	install -Dm644 $(call quote,$(ASSETS_DIR)/veshell.portal) $(call quote,$(DESTDIR)$(PORTALDIR)/portals/veshell.portal)
	install -Dm644 $(call quote,$(SERVICE_OUTPUT)) $(call quote,$(DESTDIR)$(SYSTEMD_USER_DIR)/veshell.service)
	install -Dm644 $(call quote,$(ASSETS_DIR)/veshell-shutdown.target) $(call quote,$(DESTDIR)$(SYSTEMD_USER_DIR)/veshell-shutdown.target)
	install -d -m755 $(call quote,$(DESTDIR)$(LIBDIR))
	@set -eu; for lib in $(call quote,$(SHELL_LIB_DIR))/*; do \
		[ -e "$$lib" ] || [ -L "$$lib" ] || continue; \
		case "$${lib##*/}" in libflutter_engine.so|libflutter_linux_gtk.so|libapp.so) continue;; esac; \
		cp -a "$$lib" $(call quote,$(DESTDIR)$(LIBDIR))/; \
	done
	@if [ $(call quote,$(INSTALL_ENGINE)) = 1 ]; then \
		install -Dm644 $(call quote,$(ENGINE_LIB)) $(call quote,$(DESTDIR)$(LIBDIR)/libflutter_engine.so); fi
	@if [ $(call quote,$(FLUTTER_MODE)) != debug ]; then \
		install -Dm644 $(call quote,$(APP_LIB)) $(call quote,$(DESTDIR)$(LIBDIR)/libapp.so); fi
	install -d -m755 $(call quote,$(DESTDIR)$(SHAREDIR)/data) $(call quote,$(DESTDIR)$(SHAREDIR)/settings)
	cp -a $(call quote,$(DATA_DIR))/. $(call quote,$(DESTDIR)$(SHAREDIR)/data)/
	cp -a $(call quote,$(SETTINGS_DIR))/. $(call quote,$(DESTDIR)$(SHAREDIR)/settings)/

install-local: build
	sudo $(MAKE) install $(foreach var,PREFIX BINDIR LIBDIR SHAREDIR SESSIONDIR PORTALDIR SYSTEMD_USER_DIR DESTDIR PROFILE FLUTTER_MODE ARCH ARCH_DIR BIN ENGINE_LIB APP_LIB SHELL_LIB_DIR DATA_DIR ASSETS_DIR SETTINGS_DIR SERVICE_TEMPLATE SERVICE_OUTPUT INSTALL_ENGINE,$(var)=$(call quote,$($(var))))

# Never erase an arbitrary directory or silently package stale files.
stage:
	@test -n $(call quote,$(STAGING_DIR))
	@for entry in $(call quote,$(STAGING_DIR))/* $(call quote,$(STAGING_DIR))/.[!.]* $(call quote,$(STAGING_DIR))/..?*; do \
		if [ -e "$$entry" ] || [ -L "$$entry" ]; then \
			printf '%s\n' 'STAGING_DIR must be empty; choose a fresh directory.' >&2; exit 1; fi; \
	done
	$(MAKE) install PREFIX=/usr DESTDIR=$(call quote,$(STAGING_DIR))

# The metadata consumes build/package-root, independently of Cargo output paths.
deb: stage
	@test $(call quote,$(STAGING_DIR)) = build/package-root || { printf '%s\n' 'Package metadata requires STAGING_DIR=build/package-root.' >&2; exit 1; }
	cargo deb --no-build $(if $(TARGET),--target=$(call quote,$(TARGET)))

rpm: stage
	@test $(call quote,$(STAGING_DIR)) = build/package-root || { printf '%s\n' 'Package metadata requires STAGING_DIR=build/package-root.' >&2; exit 1; }
	cargo generate-rpm $(if $(TARGET),--target=$(call quote,$(TARGET)))

uninstall:
	rm -f $(call quote,$(DESTDIR)$(BINDIR)/veshell) $(call quote,$(DESTDIR)$(BINDIR)/veshell-session) $(call quote,$(DESTDIR)$(BINDIR)/veshell-session-stop)
	rm -f $(call quote,$(DESTDIR)$(SESSIONDIR)/veshell.desktop) $(call quote,$(DESTDIR)$(PORTALDIR)/veshell-portals.conf) $(call quote,$(DESTDIR)$(PORTALDIR)/portals/veshell.portal)
	rm -f $(call quote,$(DESTDIR)$(SYSTEMD_USER_DIR)/veshell.service) $(call quote,$(DESTDIR)$(SYSTEMD_USER_DIR)/veshell-shutdown.target)
	rm -f $(call quote,$(DESTDIR)$(LIBDIR))/*.so $(call quote,$(DESTDIR)$(LIBDIR))/*.so.*
	rmdir --ignore-fail-on-non-empty $(call quote,$(DESTDIR)$(LIBDIR))
	rm -rf $(call quote,$(DESTDIR)$(SHAREDIR)/data) $(call quote,$(DESTDIR)$(SHAREDIR)/settings)
	rmdir --ignore-fail-on-non-empty $(call quote,$(DESTDIR)$(SHAREDIR))

clean:
	cargo clean
	rm -f $(call quote,$(SERVICE_OUTPUT))
