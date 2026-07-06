ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = WhatsApp

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TranslatePlugin
TranslatePlugin_FILES = Sources/TPPlugin.m Sources/TPPluginBootstrap.m Sources/TPRuntimeGuard.m Sources/TPDebugLogger.m Sources/TPSettings.m Sources/TPPluginSettingsStore.m Sources/TPCacheStore.m Sources/TPTermbaseManager.m Sources/TPLanguageDetector.m Sources/TPTranslationPromptBuilder.m Sources/TPTranslationService.m Sources/TPMessageTextExtractor.m Sources/TPRetryController.m Sources/TPTranslationRenderer.m Sources/TPMessageScanner.m Sources/TPChatPageObserver.m Sources/TPThemeAdapter.m Sources/TPSettingsPageDetector.m Sources/TPSettingsEntryView.m Sources/TPSettingsEntryInjector.m Sources/TPSettingsTabObserver.m Sources/TPSettingsNavigator.m Sources/TPPluginSettingsPage.m
TranslatePlugin_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
TranslatePlugin_FRAMEWORKS = UIKit Foundation Security

include $(THEOS_MAKE_PATH)/tweak.mk
