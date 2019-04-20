# Bitshares - 移动端应用

该源代码是 [Bitshares](https://how.bitshares.works/en/master/technology/what_bitshares.html) 区块链的移动端应用程序。

## 关于
Bitshares Mobile App 是 [Bitshares区块链](https://github.com/bitshares/bitshares-core) 的移动端钱包。

包含特性

* 支持帐号模式和钱包模式的注册
* 支持私钥模式、账号模式、钱包模式的登录
* 支持所有资产查看和交易
* 市场，时间线，K线图表，交易历史
* 抵押借贷
* 账号搜索，喂价详细，抵押排行
* 转账功能
* 投票功能
* 资产和订单管理
* 常见问题
* 提案发起、查看、批准、撤销操作
* 钱包管理支持导入普通账号及多签账号、切换、删除等操作
* 支持中英文版本

## 开发环境
* Xcode 9.4.1 - 10.1
* Android Stduio 3.1.3 - 3.2

## iOS编译
只需要调整 `Bundle Identifier` 为您的应用ID。然后直接在xcode中运行即可。

## Android编译
[点击这里查看](android_compile.md)

## 本地库编译
[点击这里查看](native_lib_compile_zh.md)

## 其他
配置Fabric

* 前往 [Fabric](https://get.fabric.io) 官网注册并申请 `APIKEY`
* 对于iOS：搜索 `__YOUR_FABRIC_APIKEY__` ，并使用您的apikey替换即可。
* 对于Android：在 AndroidManifest.xml 中搜索 `1111111111111111111111111111111111111111 ` 占位符并使用您的apikey替换即可。

## 开源协议
BitShares Mobile App 遵循MIT许可协议。有关更多信息，请参阅[LICENSE](https://github.com/btspp/bitshares-mobile-app/blob/master/LICENSE)。

## 联系我们
有关此项目开发和使用的任何问题可在[电报/Telegram](https://t.me/btsplusplus)群组中与我们联系。
