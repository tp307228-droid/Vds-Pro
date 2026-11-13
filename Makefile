ARCHS = arm64
TARGET = iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = VdsProUnlock

VdsProUnlock_FILES = VdsPro/VdsProUnlock.m
VdsProUnlock_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error
VdsProUnlock_FRAMEWORKS = UIKit Foundation StoreKit

include $(THEOS_MAKE_PATH)/library.mk
