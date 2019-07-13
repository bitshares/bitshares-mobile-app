#!/bin/sh

# 编译android的native的库。[arm64-v8a.jar / armeabi-v7a.jar / x86.jar] / Compile android native library.
#
# ※ 注意：执行该脚本之前得先执行 ./build_secp256k1_android.sh 编译 secp256k1 依赖库。
# ※ Tips: Before executing this script, you must first execute ./build_secp256k1_android.sh to compile the secp256k1 dependency library.
#
# by syalon

# 1、配置所有参数 / configure all parameters
NATIVE_DIR="android_native_output"

JNI_ABI="arm64-v8a armeabi-v7a x86"

# 2、清理 / Clean
rm -rf $NATIVE_DIR
ndk-build clean NDK_PROJECT_PATH=. NDK_APPLICATION_MK=Application.mk

# 3、循环编译所有本地库。 / Loop compile all native libraries.
CWD=`pwd`
for CURR_ABI in $JNI_ABI
do 
  ndk-build NDK_PROJECT_PATH=. NDK_APPLICATION_MK=Application.mk NDK_DEBUG=0 DEBUG=0 APP_ABI=$CURR_ABI
  cd "$CWD/$NATIVE_DIR/$CURR_ABI"
  zip -q -r -o ../$CURR_ABI.jar lib
  cp -r -f $CWD/$NATIVE_DIR/$CURR_ABI.jar $CWD/../android/app/libs

  cd $CWD
done

echo "done. target dir: $NATIVE_DIR"
