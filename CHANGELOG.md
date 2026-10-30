# BinanceMonitor 2.0-14

## Bug Fixes & Stability Improvements

- **Fix Floating Window Display**: Resolved an issue where the HUD container could fail to add to the view hierarchy on certain iOS versions due to snapshot container initialization.
- **Asynchronous Context Registration**: Added runloop retry for `SBSAccessibilityWindowHostingController` context ID registration to ensure the floating overlay always attaches to SpringBoard properly.
- **Robust Application Lifecycle**: Prevented accidental HUD termination from LaunchServices notifications when the application bundle is still present on disk.
- **Explicit Text Coloring**: Ensured all attributed text states have explicit foreground colors for maximum visibility against dark backdrop blur.
- **Diagnostic Launch Feedback**: Added prompt if HUD daemon fails to launch within 5 seconds, reminding users that TrollStore is required for root and overlay privileges.

# BinanceMonitor 2.0-13

## Features

- **Binance USD-M Futures Monitor**: Replace TrollSpeed network speed HUD with Binance contract position monitoring.
- **Multi-Account Support & Switching**: Add, edit, delete, and switch between multiple Binance accounts/keys seamlessly.
- **Real-Time Data Streaming**: Support both REST snapshot API (`/fapi/v2/positionRisk`, `/fapi/v2/account`) and WebSocket streams (`!markPrice@arr@1s` mark price stream and user data stream).
- **Secure Keychain Storage**: Store read-only API Key and Secret securely in iOS Keychain.
- **Configurable Display Options**: Toggle display for Symbol, Side, Quantity, Mark Price, Entry Price, PnL, ROE, or Account Summary (Total Equity, Floating PnL, PnL Rate, Total ROI).
- **Position & Appearance Customization**: Custom font size, HUD position offset, touch pass-through, landscape following, and screenshot hiding.
