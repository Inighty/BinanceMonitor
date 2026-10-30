# BinanceMonitor 2.0-15

## Improvements & Bug Fixes

- **Live Cross-Process Account Switching**: Switching active Binance accounts in the app now immediately refreshes the floating HUD window without needing to restart the HUD.
- **Cross-Process State Synchronization**: Synced active account ID across `securityd` Keychain, shared preferences plist (`/var/mobile/Library/Preferences/com.inighty.binancemonitor.plist`), and `NSUserDefaults`.
- **Dual Notification Delivery**: Integrated both Darwin notification broadcast (`notify_post`) and Darwin notification center (`CFNotificationCenterPostNotification`) to ensure the background HUD process receives reload events instantly.
- **HUD Instant State Transition**: HUD resets position and entry cache upon reload and seamlessly fetches and displays data for the newly selected account.

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
