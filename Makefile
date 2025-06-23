# Installation paths
PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin
LIBDIR := $(PREFIX)/lib/veshell
SHAREDIR := $(PREFIX)/share/veshell
SESSIONDIR := $(PREFIX)/share/wayland-sessions
PORTALDIR := $(PREFIX)/share/xdg-desktop-portal
SYSTEMD_USER_DIR := /usr/lib/systemd/user

# Build configuration
PROFILE ?= release
ARCH ?= $(shell uname -m)
ifeq ($(ARCH),x86_64)
	ARCH_DIR := x64
else
	ARCH_DIR := arm64
endif

# Paths to build outputs and assets
BIN := build/target/$(PROFILE)/veshell
ENGINE_LIB := extra/third_party/flutter_engine/$(PROFILE)/libflutter_engine.so
APP_LIB := src/shell/build/linux/$(ARCH_DIR)/$(PROFILE)/bundle/lib/libapp.so
ASSETS_DIR := extra/assets
DATA_DIR := src/shell/build/linux/$(ARCH_DIR)/$(PROFILE)/bundle/data
SETTINGS_DIR := extra/settings

# Service file handling
SERVICE_TEMPLATE := $(ASSETS_DIR)/veshell.service.in
SERVICE_OUTPUT := build/veshell.service

.PHONY: all build package install uninstall clean

all: build

build:
	cargo build --profile=$(PROFILE)

$(SERVICE_OUTPUT): $(SERVICE_TEMPLATE)
	@mkdir -p $(@D)
	sed "s|@bindir@|$(BINDIR)|" $< > $@

package: $(SERVICE_OUTPUT)
	@echo "Installing veshell system components..."

	# Install binaries
	install -Dm755 $(BIN) $(DESTDIR)$(BINDIR)/veshell
	install -Dm755 $(ASSETS_DIR)/veshell-session $(DESTDIR)$(BINDIR)/veshell-session

	# Install desktop/session files
	install -Dm644 $(ASSETS_DIR)/veshell.desktop $(DESTDIR)$(SESSIONDIR)/veshell.desktop
	install -Dm644 $(ASSETS_DIR)/veshell-portals.conf $(DESTDIR)$(PORTALDIR)/veshell-portals.conf

	# Install systemd user unit (processed)
	install -Dm644 $(SERVICE_OUTPUT) $(DESTDIR)$(SYSTEMD_USER_DIR)/veshell.service
	install -Dm644 $(ASSETS_DIR)/veshell-shutdown.target $(DESTDIR)$(SYSTEMD_USER_DIR)/veshell-shutdown.target

	# Install shared libraries
	install -Dm644 $(ENGINE_LIB) $(DESTDIR)$(LIBDIR)/libflutter_engine.so
	install -Dm644 $(APP_LIB) $(DESTDIR)$(LIBDIR)/libapp.so

	# Install data directory
	install -d -m755 $(DESTDIR)$(SHAREDIR)/data
	cp -r $(DATA_DIR)/* $(DESTDIR)$(SHAREDIR)/data/

	# Install settings directory
	install -d -m755 $(DESTDIR)$(SHAREDIR)/settings
	cp -r $(SETTINGS_DIR)/* $(DESTDIR)$(SHAREDIR)/settings/

install:
	$(MAKE) build PROFILE=$(PROFILE)
	sudo $(MAKE) package PROFILE=$(PROFILE)

uninstall:
	@echo "Uninstalling veshell..."

	# Remove binaries
	rm -f $(DESTDIR)$(BINDIR)/veshell
	rm -f $(DESTDIR)$(BINDIR)/veshell-session

	# Remove desktop/session files
	rm -f $(DESTDIR)$(SESSIONDIR)/veshell.desktop
	rm -f $(DESTDIR)$(PORTALDIR)/veshell-portals.conf

	# Remove systemd user units
	rm -f $(DESTDIR)$(SYSTEMD_USER_DIR)/veshell.service
	rm -f $(DESTDIR)$(SYSTEMD_USER_DIR)/veshell-shutdown.target

	# Remove shared libraries
	rm -f $(DESTDIR)$(LIBDIR)/libflutter_engine.so
	rm -f $(DESTDIR)$(LIBDIR)/libapp.so
	rmdir --ignore-fail-on-non-empty $(DESTDIR)$(LIBDIR)

	# Remove data and settings
	rm -rf $(DESTDIR)$(SHAREDIR)/data
	rm -rf $(DESTDIR)$(SHAREDIR)/settings
	rmdir --ignore-fail-on-non-empty $(DESTDIR)$(SHAREDIR)

clean:
	cargo clean
	rm -f $(SERVICE_OUTPUT)
