uname_m = $(shell uname -m)
ifeq ($(uname_m),x86_64)
ARCH += x64
ARCH_DEB += amd64
else
ARCH += arm64
ARCH_DEB += arm64
endif

TARGET_EXEC := veshell
DEPS_DIR := third_party/flutter_engine

DEBUG_BUILD_DIR := target/debug
PROFILE_BUILD_DIR := target/profile
RELEASE_BUILD_DIR := target/release

DEBUG_BUNDLE_DIR := $(DEBUG_BUILD_DIR)/bundle
PROFILE_BUNDLE_DIR := $(PROFILE_BUILD_DIR)/bundle
RELEASE_BUNDLE_DIR := $(RELEASE_BUILD_DIR)/bundle

ENGINE_REVISION := $(shell flutter --version | grep Engine | awk '{print $$NF}')

$(DEPS_DIR)/debug/libflutter_engine.so:
	curl -L https://github.com/sony/flutter-embedded-linux/releases/download/$(ENGINE_REVISION)/elinux-$(ARCH)-debug.zip >/tmp/elinux-$(ARCH)-debug.zip
	unzip -o /tmp/elinux-$(ARCH)-debug.zip -d /tmp || exit
	mkdir -p $(DEPS_DIR)/debug
	mv /tmp/libflutter_engine.so $(DEPS_DIR)/debug

$(DEPS_DIR)/profile/libflutter_engine.so:
	curl -L https://github.com/sony/flutter-embedded-linux/releases/download/$(ENGINE_REVISION)/elinux-$(ARCH)-profile.zip >/tmp/elinux-$(ARCH)-profile.zip
	unzip -o /tmp/elinux-$(ARCH)-profile.zip -d /tmp || exit
	mv /tmp/libflutter_engine.so $(DEPS_DIR)/profile

$(DEPS_DIR)/release/libflutter_engine.so:
	curl -L https://github.com/sony/flutter-embedded-linux/releases/download/$(ENGINE_REVISION)/elinux-$(ARCH)-release.zip >/tmp/elinux-$(ARCH)-release.zip
	unzip -o /tmp/elinux-$(ARCH)-release.zip -d /tmp || exit
	mv /tmp/libflutter_engine.so $(DEPS_DIR)/release

cargo_debug:
	BUNDLE= cargo build

cargo_profile:
	BUNDLE= cargo build --release

cargo_release:
	BUNDLE= cargo build --release

flutter_debug:
	cd veshell_flutter && flutter build linux --debug

flutter_profile:
	cd veshell_flutter && flutter build linux --profile

flutter_release:
	cd veshell_flutter && flutter build linux --release

debug_bundle: $(DEPS_DIR)/debug/libflutter_engine.so flutter_debug cargo_debug
	mkdir -p $(DEBUG_BUNDLE_DIR)/lib/
	cp target/debug/$(TARGET_EXEC) $(DEBUG_BUNDLE_DIR)
	cp $(DEPS_DIR)/debug/libflutter_engine.so $(DEBUG_BUNDLE_DIR)/lib
	cp -r veshell_flutter/build/linux/$(ARCH)/debug/bundle/data $(DEBUG_BUNDLE_DIR)
#	cp lsan_suppressions.txt $(DEBUG_BUNDLE_DIR)

profile_bundle: $(DEPS_DIR)/profile/libflutter_engine.so flutter_profile cargo_profile
	mkdir -p $(PROFILE_BUNDLE_DIR)/lib/
	cp target/release/$(TARGET_EXEC) $(PROFILE_BUNDLE_DIR)
	cp $(DEPS_DIR)/profile/libflutter_engine.so $(PROFILE_BUNDLE_DIR)/lib
	cp veshell_flutter/build/linux/$(ARCH)/profile/bundle/lib/libapp.so $(PROFILE_BUNDLE_DIR)/lib
	cp -r veshell_flutter/build/linux/$(ARCH)/profile/bundle/data $(PROFILE_BUNDLE_DIR)

release_bundle: $(DEPS_DIR)/release/libflutter_engine.so flutter_release cargo_release
	mkdir -p $(RELEASE_BUNDLE_DIR)/lib/
	cp target/release/$(TARGET_EXEC) $(RELEASE_BUNDLE_DIR)
	cp $(DEPS_DIR)/release/libflutter_engine.so $(RELEASE_BUNDLE_DIR)/lib
	cp veshell_flutter/build/linux/$(ARCH)/release/bundle/lib/libapp.so $(RELEASE_BUNDLE_DIR)/lib
	cp -r veshell_flutter/build/linux/$(ARCH)/release/bundle/data $(RELEASE_BUNDLE_DIR)

# Usage: make deb_package VERSION=0.2
deb_package: release_bundle
	mkdir -p build/zenith/release/deb/debpkg
	cp -r dpkg/* build/zenith/release/deb/debpkg

	sed -i 's/$$VERSION/$(VERSION)/g' build/zenith/release/deb/debpkg/DEBIAN/control
	sed -i 's/$$ARCH/$(ARCH_DEB)/g' build/zenith/release/deb/debpkg/DEBIAN/control
	cp -r build/zenith/release/bundle/* build/zenith/release/deb/debpkg/opt/zenith

	dpkg-deb -Zxz --root-owner-group --build build/zenith/release/deb/debpkg build/zenith/release/deb

attach_debugger:
	flutter attach --debug-uri=http://127.0.0.1:12345/

all: debug_bundle profile_bundle release_bundle

clean:
	cargo clean
	cd dart && flutter clean

.PHONY: clean all \
		flutter_debug flutter_profile flutter_release \
		cargo_debug cargo_profile cargo_release \
 		debug_bundle profile_bundle release_bundle \
 		deb_package attach_debugger
