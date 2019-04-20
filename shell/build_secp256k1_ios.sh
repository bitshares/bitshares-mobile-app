#!/bin/sh

#	为ios编译secp256k1库。 / Compile the secp256k1 library for ios.
# 	源码 / source：https://github.com/bitcoin-core/secp256k1
#
#	附加模块编译说明 / Additional module compilation instructions.
#
#ifdef ENABLE_MODULE_ECDH
#ifdef ENABLE_MODULE_RECOVERY
# --enable-module-ecdh    enable ECDH shared secret computation (experimental)
# --enable-module-recovery enable ECDSA pubkey recovery module (default is no)
#
#	by syalon

#	1、克隆源代码 / clone source code
SOURCE_DIR_IOS="secp256k1_ios"
rm -rf $SOURCE_DIR_IOS
git clone https://github.com/bitcoin-core/secp256k1.git $SOURCE_DIR_IOS && cd $SOURCE_DIR_IOS

#	2、配置所有参数 / configure all parameters

#	2.1、编译输出目录 / final output dir
OUTPUT_DIR="btspp_output"

# 	2.2、最终fat静态库目录 / fat lib output dir
FAT="$OUTPUT_DIR/fat-libs"

#	2.3、每个arch独立静态库编译目录 / thin lib output dir, each arch stores a different directory.
THIN=`pwd`/"$OUTPUT_DIR/thin-libs"

#	2.4、配置：secp256k1编译附加参数，启用'recovery'模块。 / configuration: secp256k1 compiles additional parameters. enable 'recovery' modules.
CONFIGURE_FLAGS="--disable-shared --disable-frontend --enable-module-recovery"

# 	2.5、配置：需要编译的架构。 / configuration: The archs that needs to be compiled.
ARCHS="arm64 armv7s x86_64 i386 armv7"

#	3、自动生成配置编译配置文件。 / auto generate configure scripts.
make distclean
./autogen.sh

#	4、循环编译所有的 thin 静态库。 / Loop compile all thin static libraries.
echo "building thin libraries..."
mkdir -p $THIN

CWD=`pwd`
for CURR_ARCH in $ARCHS
do
	echo "[$CURR_ARCH] building..."
	mkdir -p "./$OUTPUT_DIR/$CURR_ARCH"
	cd "./$OUTPUT_DIR/$CURR_ARCH"

	if test "$CURR_ARCH" = "i386" -o "$CURR_ARCH" = "x86_64" 
	then
		PLATFORM="iPhoneSimulator"
		if test "$CURR_ARCH" = "x86_64" 
		then
			SIMULATOR="-mios-simulator-version-min=7.0"
			HOST=x86_64-apple-darwin
		else
			SIMULATOR="-mios-simulator-version-min=5.0"
			HOST=i386-apple-darwin
		fi
	else
		PLATFORM="iPhoneOS"
		SIMULATOR=
		HOST=arm-apple-darwin
	fi

	XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
	CC="xcrun -sdk $XCRUN_SDK clang -arch $CURR_ARCH"

	CFLAGS="-arch $CURR_ARCH $SIMULATOR -DENABLE_MODULE_RECOVERY"
	CXXFLAGS="$CFLAGS"
	LDFLAGS="$CFLAGS"

	CC=$CC $CWD/configure $CONFIGURE_FLAGS --host=$HOST --prefix="$THIN/$CURR_ARCH" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
	make -j3 install
	cd $CWD
done

#	5、合并为 fat 静态库。 / merged into a fat static library.
echo "building fat binaries..."
mkdir -p $FAT/lib
set - $ARCHS
CWD=`pwd`
cd $THIN/$1/lib
for LIB in *.a
do
	cd $CWD
	lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
done

#	6、拷贝所需的头文件。 / copy the required header files.
cd $CWD
cp -rf $THIN/$1/include $FAT

echo "done. target dir: $SOURCE_DIR_IOS/$FAT"
