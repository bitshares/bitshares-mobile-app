#!/bin/sh

# 为android编译secp256k1库。 / Compile the secp256k1 library for android.
#   源码 / source：https://github.com/bitcoin-core/secp256k1
#
# 附加模块编译说明 / Additional module compilation instructions.
#
#ifdef ENABLE_MODULE_ECDH
#ifdef ENABLE_MODULE_RECOVERY
# --enable-module-ecdh    enable ECDH shared secret computation (experimental)
# --enable-module-recovery enable ECDSA pubkey recovery module (default is no)
#
# by syalon

# 1、克隆源代码 / clone source code
SOURCE_DIR_ANDROID="secp256k1_android"

rm -rf $SOURCE_DIR_ANDROID
git clone https://github.com/bitcoin-core/secp256k1.git $SOURCE_DIR_ANDROID && cd $SOURCE_DIR_ANDROID

# 2、配置所有参数 / configure all parameters

# 2.1、编译输出目录 / final output dir
OUTPUT_DIR="btspp_output"

#   2.2、配置：需要编译的架构。 / configuration: The archs that needs to be compiled.
ARCHS="arm64 armv7 x86"

# 2.3、配置：NDK所在路径 / configuration: NDK path
NDKROOT=$ANDROID_NDK_ROOT

# 3、自动生成配置编译配置文件。 / auto generate configure scripts.
make distclean
./autogen.sh

# 4、循环编译所有的架构的静态库。 / Loop compile all arch static libraries.
echo "building all arch libraries..."

CWD=`pwd`
for CURR_ARCH in $ARCHS
do
  echo "[$CURR_ARCH] building..."
  BUILD_TMPDIR="./$OUTPUT_DIR/intermediate.$CURR_ARCH"
  mkdir -p $BUILD_TMPDIR
  cd $BUILD_TMPDIR

  if test "$CURR_ARCH" = "armv7"
  then
    # 可用值：/ Available options:
    # arm
    # arm64
    # mips64
    # mips
    # x86
    # x86_64
    MYARCH=arm
    MYHOST=arm-linux-androideabi #  fetch value: gcc -v 2>&1 | grep ^Targ
    # 可选值：/ Available options:
    # arm-linux-androideabi
    # aarch64-linux-android
    # mips64el-linux-android
    # mipsel-linux-android
    # x86
    # x86_64
    PREBUILD_PREFIX=arm-linux-androideabi
    # 可选值：/ Available options:
    # arm-linux-androideabi
    # aarch64-linux-android
    # mips64el-linux-android
    # mipsel-linux-android
    # i686-linux-android
    # x86_64-linux-android
    BIN_PREFIX=arm-linux-androideabi
    # 可选值：/ Available options:
    # -marm
    # -m32
    # -m64
    # -mx32
    GCC_MARGS="-marm"
    # 可选值：/ Available options:
    # arm64-v8a
    # armeabi-v7a
    # x86
    INSTALL_ARCH_DIR="armeabi-v7a"
  else
    if test "$CURR_ARCH" = "arm64"
    then
      MYARCH=arm64
      MYHOST=aarch64-linux-android
      PREBUILD_PREFIX=aarch64-linux-android
      BIN_PREFIX=aarch64-linux-android
      GCC_MARGS="" # -m64 error??
      INSTALL_ARCH_DIR="arm64-v8a"
    else
      MYARCH=x86
      MYHOST=i686-linux-android
      PREBUILD_PREFIX=x86
      BIN_PREFIX=i686-linux-android
      GCC_MARGS="-m32"
      INSTALL_ARCH_DIR="x86"
    fi
  fi

  SYSROOT=$NDKROOT/platforms/android-21/arch-$MYARCH/usr/
  PREBUILT=$NDKROOT/toolchains/$PREBUILD_PREFIX-4.9/prebuilt/darwin-x86_64
  CC="$PREBUILT/bin/$BIN_PREFIX-gcc --sysroot=$SYSROOT -B $SYSROOT"
  CPP="$PREBUILT/bin/$BIN_PREFIX-cpp --sysroot=$SYSROOT -B $SYSROOT"
  export CXX="$PREBUILT/bin/$BIN_PREFIX-g++ --sysroot=$SYSROOT -B $SYSROOT" 
  export AR="$PREBUILT/bin/$BIN_PREFIX-ar"
  export RANLIB=$PREBUILT/bin/$BIN_PREFIX-ranlib
  export STRIP=$PREBUILT/bin/$BIN_PREFIX-strip

  PREFIX="$CWD/$OUTPUT_DIR/$INSTALL_ARCH_DIR"
  CFLAGS="-Os -fpic $GCC_MARGS -DENABLE_MODULE_RECOVERY"
  LDFLAGS="$CFLAGS"

  CONFIGURE_FLAGS="--disable-shared --enable-module-recovery"

  $CWD/configure $CONFIGURE_FLAGS --prefix=$PREFIX --host="$MYHOST" CFLAGS="$CFLAGS" CC="$CC" LDFLAGS="$LDFLAGS" CPP="$CPP"

  make -j3 install

  cd $CWD
done

echo "done. target dir: $SOURCE_DIR_ANDROID/$OUTPUT_DIR"
