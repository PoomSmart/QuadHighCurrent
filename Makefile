ROOTLESS ?= 0

ifeq ($(ROOTLESS),1)
	TARGET = iphone:clang:latest:14.0
	THEOS_LAYOUT_DIR_NAME = layout-rootless
	THEOS_PACKAGE_SCHEME = rootless
else
	TARGET = iphone:clang:latest:10.0
endif
ARCHS = arm64 arm64e
PACKAGE_VERSION = 1.1.1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = QuadHighCurrent
$(TWEAK_NAME)_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk
