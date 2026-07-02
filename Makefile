ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = WhatsApp

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TranslatePlugin
TranslatePlugin_FILES = Sources/TPPlugin.m Sources/TPSettings.m Sources/TPTranslationService.m Sources/TPUIInjector.m
TranslatePlugin_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
TranslatePlugin_FRAMEWORKS = UIKit Foundation Security

include $(THEOS_MAKE_PATH)/tweak.mk
