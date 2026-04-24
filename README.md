# BinanceHUD

[![Xcode - Build and Analyze](https://github.com/Inighty/trollspeed/actions/workflows/build-analyse.yml/badge.svg)](https://github.com/Inighty/trollspeed/actions/workflows/build-analyse.yml)
[![Analyse Commands](https://github.com/Inighty/trollspeed/actions/workflows/analyse-commands.yml/badge.svg)](https://github.com/Inighty/trollspeed/actions/workflows/analyse-commands.yml)
[![Build Release](https://github.com/Inighty/trollspeed/actions/workflows/build-release.yml/badge.svg)](https://github.com/Inighty/trollspeed/actions/workflows/build-release.yml)
![Latest Release](https://img.shields.io/github/v/release/Inighty/trollspeed)
![MIT License](https://img.shields.io/github/license/Inighty/trollspeed)

BinanceHUD is a TrollStore app that shows Binance USD-M Futures positions as a persistent floating HUD.

The original network speed display has been removed. The HUD now focuses only on Binance position data.

## Features

- Shows Binance USD-M Futures positions in a floating HUD.
- Supports read-only API Key / Secret storage in Keychain.
- Supports Mainnet and Testnet.
- Lets you freely combine common fields in Settings:
  - `Symbol`
  - `Side`
  - `Quantity`
  - `Current Price`
  - `Entry Price`
  - `PnL`
  - `ROE`
- Lets you configure refresh interval from the app settings.
- Keeps the existing HUD placement, appearance, screenshot hiding, and focus interaction behavior.

## How It Works

- A TrollStore app launches a privileged HUD process.
- The HUD process displays a persistent global window.
- Binance position data is loaded from Binance Futures REST + user stream updates.

## Build

- With Theos:
  - `FINALPACKAGE=1 make package`
- The output `.tipa` will be placed in `./packages`.
- With Xcode:
  - `./build.sh`

## Notes

- Spawn with elevated privileges is still required; otherwise SpringBoard may kill the HUD process after unlock.
- The HUD observes app removal and terminates itself if the app is removed.
- Use a read-only Binance Futures API key. Do not grant trading or withdrawal permissions.

## Screenshots

Current screenshots in this repository may not fully match the latest Binance-only HUD layout.

## Special Thanks

- [KIF](https://github.com/kif-framework/KIF)
- [SPLarkController](https://github.com/ivanvorobei/SPLarkController) by [@ivanvorobei_](https://twitter.com/ivanvorobei_)
- [TrollStore](https://github.com/opa334/TrollStore) by [@opa334dev](https://twitter.com/opa334dev)
- [UIDaemon](https://github.com/limneos/UIDaemon) by [@limneos](https://twitter.com/limneos)
- [SnapshotSafeView](https://github.com/Stampoo/SnapshotSafeView) by [Ilya knyazkov](https://github.com/Stampoo)

## License

BinanceHUD is licensed under the [MIT License](LICENSE).

## Localization

To add a language, create a new `.lproj` folder in `Resources`.

- en/zh-Hans [@Lessica](https://github.com/Lessica)
- es [@Deci8BelioS](https://github.com/Deci8BelioS)
