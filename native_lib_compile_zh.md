# 如何编译本地库？

[English Version](native_lib_compile.md)

## 编译环境

* MacOS 10.14.4+
* XCODE 10.1+

## 克隆代码
```
git clone https://github.com/bitshares/bitshares-mobile-app.git
```

## 编译 iOS 的 secp256k1 库。
```
cd shell
chmod a+x build_secp256k1_ios.sh
./build_secp256k1_ios.sh
```

## 编译 Android 的 secp256k1 库。

#### 第一步 安装安卓 NDK 库（仅支持 13b 版）
```
https://developer.android.google.cn/ndk/downloads/older_releases.html#ndk-13b-downloads
```

#### 第二步 配置环境变量
```
export ANDROID_NDK_ROOT="Your NDK Install Dir"
export PATH=$PATH:$ANDROID_NDK_ROOT
```

#### 第三步 开始编译
```
cd shell
chmod a+x build_secp256k1_android.sh
./build_secp256k1_android.sh
```

## 编译 libfowallet.so 和 安卓的 jar 包。（需先编译 secp256k1 库）
```
cd shell
chmod a+x build_fowallet_so_android.sh
./build_fowallet_so_android.sh
```