INSTALL_TARGET_PROCESSES = VideoStar
ARCHS = arm64
TARGET = iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VdsProUnlock

VdsProUnlock_FILES  = VdsPro/VdsProUnlock.x
VdsProUnlock_CFLAGS = -fobjc-arc
VdsProUnlock_FRAMEWORKS = UIKit Foundation StoreKit

include $(THEOS_MAKE_PATH)/tweak.mk
