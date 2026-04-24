import Foundation

enum TSSettingsIndex: Int, CaseIterable {
    case binanceAccount = 0
    case binanceUseTestnet
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
}
