#	ndk-build NDK_PROJECT_PATH=. NDK_APPLICATION_MK=Application.mk NDK_DEBUG=0 DEBUG=0 APP_ABI=armeabi-v7a
#	ndk-build NDK_PROJECT_PATH=. NDK_APPLICATION_MK=Application.mk NDK_DEBUG=0 DEBUG=0 APP_ABI=x86
TARGET_OUT =./android_native_output/$(TARGET_ARCH_ABI)/lib/$(TARGET_ARCH_ABI)

NDK_APP_OUT := ../../../../../src

# LOCAL_PATH := $(call my-dir)/
LOCAL_PATH := ../ios/oplayer/bitshares

#	REMARK：这个strip的是 install 之前的so。
cmd-strip = $(TOOLCHAIN_PREFIX)strip $1

include $(CLEAR_VARS)

#	生成的模块名字
LOCAL_MODULE := fowallet

#	源文件
ALL_C_FILES 	:= $(wildcard $(LOCAL_PATH)/*.c)
ALL_C_FILES 	+= $(wildcard $(LOCAL_PATH)/android_jni_src/*.c) 	#	REMARK：该目录代码仅 android jni 用，ios不需要。
ALL_C_FILES 	+= $(wildcard $(LOCAL_PATH)/base58/*.c)
ALL_C_FILES 	+= $(wildcard $(LOCAL_PATH)/lzma/*.c)
ALL_C_FILES 	+= $(wildcard $(LOCAL_PATH)/rmd160/*.c)
ALL_C_FILES 	+= $(wildcard $(LOCAL_PATH)/varint/*.c)
ALL_C_FILES 	+= $(wildcard $(LOCAL_PATH)/WjCryptLib/*.c)
LOCAL_SRC_FILES := $(ALL_C_FILES:$(LOCAL_PATH)/%=%)

#	DEBUG调试
# $(error debug-error $(TARGET_ARCH_ABI))

#	添加第三方依赖库
LOCAL_LDFLAGS   += secp256k1_android/btspp_output/$(TARGET_ARCH_ABI)/lib/libsecp256k1.a

#	头文件
LOCAL_C_INCLUDES += secp256k1_android/btspp_output/$(TARGET_ARCH_ABI)/include
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/android_jni_src)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/base58)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/lzma)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/rmd160)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/varint)
LOCAL_C_INCLUDES += $(wildcard $(LOCAL_PATH)/WjCryptLib)

#	-fvisibility=hidden 隐藏编译出来的 so 的符号表（T -> t） T：是导出符号 t：局部符号，t考虑 strip命令去掉。
LOCAL_CFLAGS 	:= -std=c99 -fsigned-char -fvisibility=hidden -DNDK_DEBUG=$(NDK_DEBUG) -DDEBUG=$(DEBUG)

#	编译所依赖的库
LOCAL_LDLIBS    := -landroid -llog -lz

include $(BUILD_SHARED_LIBRARY)
