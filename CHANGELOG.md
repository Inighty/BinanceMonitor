# BinanceMonitor 2.0-13

## Features

- **Binance USD-M Futures Monitor**: Replace TrollSpeed network speed HUD with Binance contract position monitoring.
- **Multi-Account Support & Switching**: Add, edit, delete, and switch between multiple Binance accounts/keys seamlessly.
- **Real-Time Data Streaming**: Support both REST snapshot API (`/fapi/v2/positionRisk`, `/fapi/v2/account`) and WebSocket streams (`!markPrice@arr@1s` mark price stream and user data stream).
- **Secure Keychain Storage**: Store read-only API Key and Secret securely in iOS Keychain.
- **Configurable Display Options**: Toggle display for Symbol, Side, Quantity, Mark Price, Entry Price, PnL, ROE, or Account Summary (Total Equity, Floating PnL, PnL Rate, Total ROI).
- **Position & Appearance Customization**: Custom font size, HUD position offset, touch pass-through, landscape following, and screenshot hiding.
