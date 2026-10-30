ARCHS := arm64  # arm64e
TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES := BinanceMonitor
ENT_PLIST := $(PWD)/supports/entitlements.plist
LAUNCHD_PLIST := $(PWD)/layout/Library/LaunchDaemons/com.inighty.binancemonitor.hudservices.plist

include $(THEOS)/makefiles/common.mk

TIPA_VERSION := $(shell ./get-version.sh)
APPLICATION_NAME := BinanceMonitor

BinanceMonitor_USE_MODULES := 0

BinanceMonitor_FILES += $(wildcard sources/*.mm sources/*.m)
BinanceMonitor_FILES += $(wildcard sources/KIF/*.mm sources/KIF/*.m)
BinanceMonitor_FILES += $(wildcard sources/*.swift)
BinanceMonitor_FILES += $(wildcard sources/SPLarkController/*.swift)
BinanceMonitor_FILES += $(wildcard sources/SnapshotSafeView/*.swift)

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
BinanceMonitor_FILES += libroot/dyn.c
BinanceMonitor_LIBRARIES += roothide
endif

# App Intents will be built from Xcode.
# BinanceMonitor_FILES += $(wildcard sources/Intents/*.swift)

BinanceMonitor_CFLAGS += -fobjc-arc
BinanceMonitor_CFLAGS += -Iheaders
BinanceMonitor_CFLAGS += -Isources
BinanceMonitor_CFLAGS += -Isources/KIF
BinanceMonitor_CFLAGS += -include supports/hudapp-prefix.pch
MainApplication.mm_CCFLAGS += -std=c++14

BinanceMonitor_SWIFT_BRIDGING_HEADER += supports/hudapp-bridging-header.h

BinanceMonitor_LDFLAGS += -Flibraries

BinanceMonitor_FRAMEWORKS += CoreGraphics CoreServices QuartzCore IOKit Security CryptoKit UIKit
BinanceMonitor_PRIVATE_FRAMEWORKS += BackBoardServices GraphicsServices SpringBoardServices
BinanceMonitor_CODESIGN_FLAGS += -Ssupports/entitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

SUBPROJECTS += prefs
ifneq ($(FINALPACKAGE),1)
SUBPROJECTS += memory_pressure
endif

include $(THEOS_MAKE_PATH)/aggregate.mk

before-all::
	$(ECHO_NOTHING)defaults write $(LAUNCHD_PLIST) ProgramArguments -array "$(THEOS_PACKAGE_INSTALL_PREFIX)/Applications/BinanceMonitor.app/BinanceMonitor" "-hud" || true$(ECHO_END)
	$(ECHO_NOTHING)plutil -convert xml1 $(LAUNCHD_PLIST)$(ECHO_END)
	$(ECHO_NOTHING)chmod 0644 $(LAUNCHD_PLIST)$(ECHO_END)

before-package::
	$(ECHO_NOTHING)mv -f $(THEOS_STAGING_DIR)/usr/local/bin/memory_pressure $(THEOS_STAGING_DIR)/Applications/BinanceMonitor.app || true$(ECHO_END)
	$(ECHO_NOTHING)rmdir $(THEOS_STAGING_DIR)/usr/local/bin $(THEOS_STAGING_DIR)/usr/local $(THEOS_STAGING_DIR)/usr || true$(ECHO_END)

after-package::
	$(ECHO_NOTHING)mkdir -p packages $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)cp -rp $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Applications/BinanceMonitor.app $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)defaults delete $(THEOS_STAGING_DIR)/Payload/BinanceMonitor.app/Info.plist CFBundleIconName || true$(ECHO_END)
	$(ECHO_NOTHING)defaults write $(THEOS_STAGING_DIR)/Payload/BinanceMonitor.app/Info.plist CFBundleVersion -string $(shell openssl rand -hex 4)$(ECHO_END)
	$(ECHO_NOTHING)plutil -convert xml1 $(THEOS_STAGING_DIR)/Payload/BinanceMonitor.app/Info.plist$(ECHO_END)
	$(ECHO_NOTHING)chmod 0644 $(THEOS_STAGING_DIR)/Payload/BinanceMonitor.app/Info.plist$(ECHO_END)
	$(ECHO_NOTHING)cd $(THEOS_STAGING_DIR); zip -qr BinanceMonitor_${TIPA_VERSION}.tipa Payload; cd -;$(ECHO_END)
	$(ECHO_NOTHING)mv $(THEOS_STAGING_DIR)/BinanceMonitor_${TIPA_VERSION}.tipa packages/BinanceMonitor_${TIPA_VERSION}.tipa$(ECHO_END)
