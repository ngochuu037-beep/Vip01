TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LicenseGate
LicenseGate_FILES = Tweak.x
LicenseGate_CFLAGS = -fobjc-arc
LicenseGate_FRAMEWORKS = UIKit Security

include $(THEOS_MAKE_PATH)/tweak.mk
