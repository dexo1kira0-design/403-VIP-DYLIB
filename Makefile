ARCHS = arm64
TARGET = iphone:clang:latest:14.0
DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = metalbiew

metalbiew_FILES = metalbiew.mm ESP/FCUUID.m ESP/FTToastIndicator.m ESP/ErrorVipPanel.mm ESP/fishhook.c ESP/FarsiType.cpp
metalbiew_FRAMEWORKS = UIKit Foundation Metal MetalKit AVFoundation
metalbiew_CFLAGS = -fobjc-arc -I.

include $(THEOS_MAKE_PATH)/library.mk
