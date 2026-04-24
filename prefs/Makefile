ARCHS := arm64 arm64e
TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES := Preferences

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME += BinanceHUDPrefs

BinanceHUDPrefs_FILES += TSPrefsRootListController.m

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
BinanceHUDPrefs_FILES += ../libroot/dyn.c
BinanceHUDPrefs_LIBRARIES += roothide
endif

BinanceHUDPrefs_CFLAGS += -fobjc-arc
BinanceHUDPrefs_CFLAGS += -I../supports/

BinanceHUDPrefs_FRAMEWORKS += UIKit
BinanceHUDPrefs_PRIVATE_FRAMEWORKS += Preferences
BinanceHUDPrefs_INSTALL_PATH += /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
