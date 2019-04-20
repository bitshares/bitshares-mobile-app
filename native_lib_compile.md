# How to compile the native library?

[中文](native_lib_compile_zh.md)

## Development Environment

* MacOS 10.14.4+
* XCODE 10.1+

## Clone
```
git clone https://github.com/bitshares/bitshares-mobile-app.git
```

## Compile secp256k1 for iOS.
```
cd shell
chmod a+x build_secp256k1_ios.sh
./build_secp256k1_ios.sh
```

## Compile secp256k1 for Android.

#### step A. Install the Android NDK library (Supported version: 13b)
```
https://developer.android.google.cn/ndk/downloads/older_releases.html#ndk-13b-downloads
```

#### step B. configuring environment variables
```
export ANDROID_NDK_ROOT="Your NDK Install Dir"
export PATH=$PATH:$ANDROID_NDK_ROOT
```

#### step C. Start compiling
```
cd shell
chmod a+x build_secp256k1_android.sh
./build_secp256k1_android.sh
```

## Compile libfowallet.so and xxx.jar for Android. (requirement: secp256k1)
```
cd shell
chmod a+x build_fowallet_so_android.sh
./build_fowallet_so_android.sh
```