# bitshares-mobile-app

The mobile app for [bitshares](https://how.bitshares.works/en/master/technology/what_bitshares.html) blockchain. 

[中文](README_zh.md)

## About

Bitshares Mobile App is the mobile wallet for the [Bitshares Blockchain](https://github.com/bitshares/bitshares-core). Currently features:

* Support account mode and wallet mode registration
* Support wallet mode, account mode and private key mode login
* Support for all asset views and transactions
* Markets, TimeLine, K-Line Chart, Transaction History
* Collateral
* Account Search, Feed Price Details, Margin Ranking
* Transfer
* Voting
* Balance and Order View
* FAQ
* Support proposal create, approve, revoke actions.
* Wallet Management. Import Common Account and Multi-Money Account, Switch, Delete, etc
* Chinese and English versions are supported

## Development Environment

* Xcode 9.4.1 - 10.1
* Android Stduio 3.1.3 - 3.2

## iOS Compile

Only need to adjust `Bundle Identifier` to your app id. Then you can run it directly in xcode.

## Android Compile

[Click here to view](android_compile.md)

## Native Library Compile

[Click here to view](native_lib_compile.md)

## Other

Configuration Fabric

* Go to the [Fabric](https://fabric.io) to register and apply for `APIKEY`
* For iOS: search for `__YOUR_FABRIC_APIKEY__` and replace it with your apikey.
* For Android: search for the `1111111111111111111111111111111111111111` placeholder in `AndroidManifest.xml` and replace it with your apikey.

## License

BitShares Mobile App is under the MIT license. See [LICENSE](https://github.com/btspp/bitshares-mobile-app/blob/master/LICENSE)
for more information.

## Contact us
If you have any questions, please contact us via the [Telegram](https://t.me/btsplusplus) group.