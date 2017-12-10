##TARGET := iphone:clang:latest:5.0
THEOS_DEVICE_IP=iphone150	#5C9
TARGET = iphone:latest:8.0
ARCHS := armv7 armv7s arm64

THEOS=/opt/theos
THEOS_MAKE_PATH=$(THEOS)/makefiles
include $(THEOS)/makefiles/common.mk
TOOL_NAME = toggle-pie
toggle-pie_FILES = toggle-pie.mm

include $(THEOS_MAKE_PATH)/tool.mk
