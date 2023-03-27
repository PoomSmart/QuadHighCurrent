TARGET = iphone:clang:latest:10.0
ARCHS = arm64 arm64e
PACKAGE_VERSION = 1.1.1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = QuadHighCurrent
$(TWEAK_NAME)_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk
