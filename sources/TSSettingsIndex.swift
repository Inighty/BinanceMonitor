import Foundation

enum TSSettingsIndex: Int, CaseIterable {
    case binanceAccount = 0
    case binanceUseTestnet
    case binanceRefreshInterval
    case binanceShowSymbol
    case binanceShowSide
    case binanceShowQuantity
    case binanceShowCurrentPrice
    case binanceShowEntryPrice
    case binanceShowPnL
    case binanceShowROE
    case passthroughMode
    case keepInPlace
    case hideAtSnapshot
    case usesInvertedColor
    case usesRotation
    case usesLargeFont

    var key: String {
        switch self {
        case .binanceAccount:
            return HUDUserDefaultsKeyBinanceAccount
        case .binanceUseTestnet:
            return HUDUserDefaultsKeyBinanceUseTestnet
        case .binanceRefreshInterval:
            return HUDUserDefaultsKeyBinanceRefreshInterval
        case .binanceShowSymbol:
            return HUDUserDefaultsKeyBinanceShowSymbol
        case .binanceShowSide:
            return HUDUserDefaultsKeyBinanceShowSide
        case .binanceShowQuantity:
            return HUDUserDefaultsKeyBinanceShowQuantity
        case .binanceShowCurrentPrice:
            return HUDUserDefaultsKeyBinanceShowCurrentPrice
        case .binanceShowEntryPrice:
            return HUDUserDefaultsKeyBinanceShowEntryPrice
        case .binanceShowPnL:
            return HUDUserDefaultsKeyBinanceShowPnL
        case .binanceShowROE:
            return HUDUserDefaultsKeyBinanceShowROE
        case .passthroughMode:
            return HUDUserDefaultsKeyPassthroughMode
        case .keepInPlace:
            return HUDUserDefaultsKeyKeepInPlace
        case .hideAtSnapshot:
            return HUDUserDefaultsKeyHideAtSnapshot
        case .usesInvertedColor:
            return HUDUserDefaultsKeyUsesInvertedColor
        case .usesRotation:
            return HUDUserDefaultsKeyUsesRotation
        case .usesLargeFont:
            return HUDUserDefaultsKeyUsesLargeFont
        }
    }

    var title: String {
        switch self {
        case .binanceAccount:
            return NSLocalizedString("Binance Account", comment: "TSSettingsIndex")
        case .binanceUseTestnet:
            return NSLocalizedString("Binance Environment", comment: "TSSettingsIndex")
        case .binanceRefreshInterval:
            return NSLocalizedString("Refresh Interval", comment: "TSSettingsIndex")
        case .binanceShowSymbol:
            return NSLocalizedString("Show Symbol", comment: "TSSettingsIndex")
        case .binanceShowSide:
            return NSLocalizedString("Show Side", comment: "TSSettingsIndex")
        case .binanceShowQuantity:
            return NSLocalizedString("Show Quantity", comment: "TSSettingsIndex")
        case .binanceShowCurrentPrice:
            return NSLocalizedString("Show Current Price", comment: "TSSettingsIndex")
        case .binanceShowEntryPrice:
            return NSLocalizedString("Show Entry Price", comment: "TSSettingsIndex")
        case .binanceShowPnL:
            return NSLocalizedString("Show PnL", comment: "TSSettingsIndex")
        case .binanceShowROE:
            return NSLocalizedString("Show ROE", comment: "TSSettingsIndex")
        case .passthroughMode:
            return NSLocalizedString("Pass-through", comment: "TSSettingsIndex")
        case .keepInPlace:
            return NSLocalizedString("Keep In-place", comment: "TSSettingsIndex")
        case .hideAtSnapshot:
            return NSLocalizedString("Hide @snapshot", comment: "TSSettingsIndex")
        case .usesInvertedColor:
            return NSLocalizedString("Appearance", comment: "TSSettingsIndex")
        case .usesRotation:
            return NSLocalizedString("Landscape", comment: "TSSettingsIndex")
        case .usesLargeFont:
            return NSLocalizedString("Size", comment: "TSSettingsIndex")
        }
    }

    func subtitle(highlighted: Bool, restartRequired: Bool) -> String {
        switch self {
        case .binanceAccount:
            return highlighted ? NSLocalizedString("Configured", comment: "TSSettingsIndex") : NSLocalizedString("Not Configured", comment: "TSSettingsIndex")
        case .binanceUseTestnet:
            return highlighted ? NSLocalizedString("Testnet", comment: "TSSettingsIndex") : NSLocalizedString("Mainnet", comment: "TSSettingsIndex")
        case .binanceRefreshInterval:
            return TSSettingsIndex.binanceRefreshIntervalSubtitle()
        case .binanceShowSymbol, .binanceShowSide, .binanceShowQuantity, .binanceShowCurrentPrice, .binanceShowEntryPrice, .binanceShowPnL, .binanceShowROE:
            return highlighted ? NSLocalizedString("ON", comment: "TSSettingsIndex") : NSLocalizedString("OFF", comment: "TSSettingsIndex")
        case .passthroughMode:
            if restartRequired {
                return NSLocalizedString("Re-open to apply", comment: "TSSettingsIndex")
            }
            return highlighted ? NSLocalizedString("ON", comment: "TSSettingsIndex") : NSLocalizedString("OFF", comment: "TSSettingsIndex")
        case .keepInPlace, .hideAtSnapshot:
            return highlighted ? NSLocalizedString("ON", comment: "TSSettingsIndex") : NSLocalizedString("OFF", comment: "TSSettingsIndex")
        case .usesInvertedColor:
            return highlighted ? NSLocalizedString("Inverted", comment: "TSSettingsIndex") : NSLocalizedString("Classic", comment: "TSSettingsIndex")
        case .usesRotation:
            return highlighted ? NSLocalizedString("Follow", comment: "TSSettingsIndex") : NSLocalizedString("Hide", comment: "TSSettingsIndex")
        case .usesLargeFont:
            return highlighted ? NSLocalizedString("Large", comment: "TSSettingsIndex") : NSLocalizedString("Standard", comment: "TSSettingsIndex")
        }
    }

    private static func binanceRefreshIntervalSubtitle() -> String {
        let defaults = GetStandardUserDefaults()
        let interval = defaults.integer(forKey: HUDUserDefaultsKeyBinanceRefreshInterval)
        let resolvedInterval = interval > 0 ? interval : 15
        return String(format: NSLocalizedString("%ds", comment: "TSSettingsIndex"), resolvedInterval)
    }
}
