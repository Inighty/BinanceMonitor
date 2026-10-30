# BinanceMonitor

[![Xcode - Build and Analyze](https://github.com/Inighty/BinanceMonitor/actions/workflows/build-analyse.yml/badge.svg)](https://github.com/Inighty/BinanceMonitor/actions/workflows/build-analyse.yml)
[![Analyse Commands](https://github.com/Inighty/BinanceMonitor/actions/workflows/analyse-commands.yml/badge.svg)](https://github.com/Inighty/BinanceMonitor/actions/workflows/analyse-commands.yml)
[![Build Release](https://github.com/Inighty/BinanceMonitor/actions/workflows/build-release.yml/badge.svg)](https://github.com/Inighty/BinanceMonitor/actions/workflows/build-release.yml)
![Latest Release](https://img.shields.io/github/v/release/Inighty/BinanceMonitor)
![MIT License](https://img.shields.io/github/license/Inighty/BinanceMonitor)

BinanceMonitor is a TrollStore app that shows Binance USD-M Futures positions as a persistent floating HUD on iOS.

The original network speed display from TrollSpeed has been replaced with real-time Binance position and account monitoring.

## Features

- **Binance USD-M Futures HUD**: Displays real-time contract position metrics in a persistent floating overlay.
- **Multi-Account Support**: Add and manage multiple Binance accounts (API Key/Secret pairs), with custom account names, individual testnet/mainnet settings, and seamless one-tap switching.
- **Secure Keychain Storage**: Read-only API Key and Secret are safely stored in the iOS Keychain.
- **Mainnet & Testnet Support**: Easily switch between Binance Mainnet (`fapi.binance.com`) and Testnet (`demo-fapi.binance.com`).
- **Flexible Field Customization**: Toggle display of common metrics:
  - `Symbol`
  - `Side` (LONG / SHORT)
  - `Quantity`
  - `Current Price` (Mark Price)
  - `Entry Price`
  - `PnL` (Unrealized Profit & Loss)
  - `ROE` (Return on Equity)
- **Account Summary Mode**: Switch from individual positions to total account metrics:
  - `Total Equity`
  - `Floating PnL`
  - `Floating PnL Rate`
  - `Total ROI`
- **Configurable Refresh Interval**: Adjust REST snapshot polling frequency directly in app settings.
- **Real-Time WebSocket Updates**: Live mark price stream (`!markPrice@arr@1s`) and user data stream for instant updates.
- **Gesture & Position Control**: Support for dragging HUD, touch pass-through, screenshot hiding, landscape orientation following, and custom sizing.

## How It Works

- The app uses elevated TrollStore privileges to launch a background HUD service (`BinanceMonitor -hud`).
- The HUD creates a persistent floating window across the system UI (even above Dynamic Island and Status Bar).
- Position and account data are fetched from Binance Futures REST APIs (`/fapi/v2/positionRisk`, `/fapi/v2/account`) and kept live with WebSockets.

## Build

### Using Theos
```bash
FINALPACKAGE=1 make package
```
The output `.tipa` and `.deb` will be generated in `./packages`.

### Using Xcode
```bash
./build.sh
```

## Security Note

- Please use a **read-only** Binance Futures API key.
- **Do NOT** enable trading, withdrawal, or transfer permissions for the API key.

## Special Thanks

- [TrollSpeed](https://github.com/Lessica/TrollSpeed) by [@Lessica](https://github.com/Lessica)
- [KIF](https://github.com/kif-framework/KIF)
- [SPLarkController](https://github.com/ivanvorobei/SPLarkController) by [@ivanvorobei_](https://twitter.com/ivanvorobei_)
- [TrollStore](https://github.com/opa334/TrollStore) by [@opa334dev](https://twitter.com/opa334dev)
- [UIDaemon](https://github.com/limneos/UIDaemon) by [@limneos](https://twitter.com/limneos)
- [SnapshotSafeView](https://github.com/Stampoo/SnapshotSafeView) by [Ilya knyazkov](https://github.com/Stampoo)

## License

BinanceMonitor is licensed under the [MIT License](LICENSE).
