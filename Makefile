# Restore XDG_CONFIG_HOME to what it was before sourcing setup_env.sh
ifdef SETUP_ENV_SOURCED
XDG_CONFIG_HOME = $(OLD_XDG_CONFIG_HOME)
endif

uname_m = $(shell uname -m)
ifeq ($(uname_m),x86_64)
ARCH += x64
ARCH_DEB += amd64
else
ARCH += arm64
ARCH_DEB += arm64
endif

TARGET_EXEC := veshell
DEPS_DIR := embedder/third_party/flutter_engine

DEBUG_BUNDLE_DIR := build/$(ARCH)/debug
PROFILE_BUNDLE_DIR := build/$(ARCH)/profile
RELEASE_BUNDLE_DIR := build/$(ARCH)/release

cargo_debug:
	cd embedder && FLUTTER_ENGINE_BUILD=debug cargo build

cargo_profile:
	cd embedder && FLUTTER_ENGINE_BUILD=profile cargo build --release

cargo_release:
	cd embedder && FLUTTER_ENGINE_BUILD=release cargo build --release

flutter_debug:
	cd shell && \
	dart run build_runner build --delete-conflicting-outputs && \
	flutter build linux --debug

flutter_profile:
	cd shell && \
	dart run build_runner build --delete-conflicting-outputs && \
	flutter build linux --profile

flutter_release:
	cd shell && \
	dart run build_runner build --delete-conflicting-outputs && \
	flutter build linux --release

debug_bundle: flutter_debug cargo_debug
	mkdir -p $(DEBUG_BUNDLE_DIR)/lib/
	cp embedder/target/debug/$(TARGET_EXEC) $(DEBUG_BUNDLE_DIR)
	cp $(DEPS_DIR)/debug/libflutter_engine.so $(DEBUG_BUNDLE_DIR)/lib
	cp -r shell/build/linux/$(ARCH)/debug/bundle/data $(DEBUG_BUNDLE_DIR)
#	cp lsan_suppressions.txt $(DEBUG_BUNDLE_DIR)

run_debug_bundle: debug_bundle
	./$(DEBUG_BUNDLE_DIR)/$(TARGET_EXEC)

profile_bundle: flutter_profile cargo_profile
	mkdir -p $(PROFILE_BUNDLE_DIR)/lib/
	cp embedder/target/release/$(TARGET_EXEC) $(PROFILE_BUNDLE_DIR)
	cp $(DEPS_DIR)/profile/libflutter_engine.so $(PROFILE_BUNDLE_DIR)/lib
	cp shell/build/linux/$(ARCH)/profile/bundle/lib/libapp.so $(PROFILE_BUNDLE_DIR)/lib
	cp -r shell/build/linux/$(ARCH)/profile/bundle/data $(PROFILE_BUNDLE_DIR)

release_bundle: flutter_release cargo_release
	mkdir -p $(RELEASE_BUNDLE_DIR)/lib/
	cp embedder/target/release/$(TARGET_EXEC) $(RELEASE_BUNDLE_DIR)
	cp $(DEPS_DIR)/release/libflutter_engine.so $(RELEASE_BUNDLE_DIR)/lib
	cp shell/build/linux/$(ARCH)/release/bundle/lib/libapp.so $(RELEASE_BUNDLE_DIR)/lib
	cp -r shell/build/linux/$(ARCH)/release/bundle/data $(RELEASE_BUNDLE_DIR)

# Usage: make deb_package VERSION=0.2
deb_package: release_bundle
	mkdir -p build/veshell/release/deb/debpkg
	cp -r dpkg/* build/veshell/release/deb/debpkg

	sed -i 's/$$VERSION/$(VERSION)/g' build/veshell/release/deb/debpkg/DEBIAN/control
	sed -i 's/$$ARCH/$(ARCH_DEB)/g' build/veshell/release/deb/debpkg/DEBIAN/control
	cp -r build/veshell/release/bundle/* build/veshell/release/deb/debpkg/opt/veshell

	dpkg-deb -Zxz --root-owner-group --build build/veshell/release/deb/debpkg build/veshell/release/deb

attach_debugger:
	cd shell && flutter attach --debug-uri=http://127.0.0.1:12345/

all: debug_bundle profile_bundle release_bundle

clean:
	cd embedder && cargo clean
	cd shell && flutter clean
	rm -r build

.PHONY: clean all \
		flutter_debug flutter_profile flutter_release \
		cargo_debug cargo_profile cargo_release \
 		debug_bundle profile_bundle release_bundle \
 		deb_package attach_debugger

dev_shell:
	export XDG_CONFIG_HOME=$(PWD)/shell/.config && cd shell && flutter run -d veshell
dev_embedder:
	cd embedder && cargo run
