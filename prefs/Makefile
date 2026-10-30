ARCHS := arm64 arm64e
TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES := Preferences

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME += BinanceMonitorPrefs

BinanceMonitorPrefs_FILES += TSPrefsRootListController.m

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
BinanceMonitorPrefs_FILES += ../libroot/dyn.c
BinanceMonitorPrefs_LIBRARIES += roothide
endif

BinanceMonitorPrefs_CFLAGS += -fobjc-arc
BinanceMonitorPrefs_CFLAGS += -I../supports/

BinanceMonitorPrefs_FRAMEWORKS += UIKit
BinanceMonitorPrefs_PRIVATE_FRAMEWORKS += Preferences
BinanceMonitorPrefs_INSTALL_PATH += /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
