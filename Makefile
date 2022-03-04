PACKAGE_VERSION = 1.1.0
TARGET = iphone:clang:14.5:10.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = QuadHighCurrent
$(TWEAK_NAME)_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk
