TARGET = iphone:clang:latest:10.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = QuadHighCurrent
$(BUNDLE_NAME)_FILES = Switch.xm
$(BUNDLE_NAME)_CFLAGS = -fobjc-arc
$(BUNDLE_NAME)_LIBRARIES = flipswitch
$(BUNDLE_NAME)_FRAMEWORKS = UIKit
$(BUNDLE_NAME)_INSTALL_PATH = /Library/Switches

include $(THEOS_MAKE_PATH)/bundle.mk