import Foundation
import Security

public enum TSBinanceCredentialState {
    case configured(apiKey: String, secret: String)
    case missing
    case temporarilyUnavailable(NSError)
    case failed(NSError)
}

private enum TSBinanceCredentialValueResult {
    case success(String)
    case notFound
    case temporarilyUnavailable(NSError)
    case failure(NSError)
}

@objcMembers
public final class TSBinanceAccount: NSObject, Codable {
    public let id: String
    public var name: String
    public var apiKey: String
    public var secret: String
    public var useTestnet: Bool
    public var createdAt: Date

    public init(id: String = UUID().uuidString, name: String, apiKey: String, secret: String, useTestnet: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.apiKey = apiKey
        self.secret = secret
        self.useTestnet = useTestnet
        self.createdAt = createdAt
    }

    public var maskedAPIKey: String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else {
            return trimmed.isEmpty ? "••••" : trimmed
        }
        let start = trimmed.prefix(4)
        let end = trimmed.suffix(4)
        return "\(start)...\(end)"
    }
}

@objcMembers
public final class TSBinanceCredentialStore: NSObject {
    private static let service = "com.inighty.binancemonitor.binance"
    private static let accountsAccount = "accounts_json"
    private static let legacyApiKeyAccount = "apiKey"
    private static let legacySecretAccount = "secret"
    private static let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    private static let sharedInstance = TSBinanceCredentialStore()

    private var cachedAccounts: [TSBinanceAccount]?

    @objc(sharedStore)
    public class func sharedStore() -> TSBinanceCredentialStore {
        sharedInstance
    }

    public func allAccounts() -> [TSBinanceAccount] {
        if let cached = cachedAccounts {
            return cached
        }

        let loaded = loadAccountsFromKeychain()
        cachedAccounts = loaded
        return loaded
    }

    public func activeAccountId() -> String? {
        let savedId = GetStandardUserDefaults().string(forKey: HUDUserDefaultsKeyBinanceActiveAccountId)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let accounts = allAccounts()
        if let savedId, !savedId.isEmpty, accounts.contains(where: { $0.id == savedId }) {
            return savedId
        }

        return accounts.first?.id
    }

    public func activeAccount() -> TSBinanceAccount? {
        guard let id = activeAccountId() else { return nil }
        return allAccounts().first { $0.id == id }
    }

    @discardableResult
    public func setActiveAccount(id: String) -> Bool {
        let accounts = allAccounts()
        guard accounts.contains(where: { $0.id == id }) else {
            return false
        }

        GetStandardUserDefaults().set(id, forKey: HUDUserDefaultsKeyBinanceActiveAccountId)
        if let account = accounts.first(where: { $0.id == id }) {
            GetStandardUserDefaults().set(account.useTestnet, forKey: HUDUserDefaultsKeyBinanceUseTestnet)
        }
        GetStandardUserDefaults().synchronize()

        notifyChange()
        return true
    }

    public func hasCredentials() -> Bool {
        guard let active = activeAccount() else { return false }
        let trimmedKey = active.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = active.secret.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedKey.isEmpty && !trimmedSecret.isEmpty
    }

    public func currentAccountName() -> String? {
        activeAccount()?.name
    }

    public func currentAPIKey() -> String? {
        activeAccount()?.apiKey
    }

    public func currentSecret() -> String? {
        activeAccount()?.secret
    }

    public func currentUseTestnet() -> Bool {
        activeAccount()?.useTestnet ?? false
    }

    public func credentialState() -> TSBinanceCredentialState {
        guard let active = activeAccount() else {
            return .missing
        }

        let trimmedAPIKey = active.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = active.secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty, !trimmedSecret.isEmpty else {
            return .missing
        }

        return .configured(apiKey: trimmedAPIKey, secret: trimmedSecret)
    }

    @objc(addAccountWithName:apiKey:secret:useTestnet:error:)
    public func addAccount(name: String, apiKey: String, secret: String, useTestnet: Bool) throws -> TSBinanceAccount {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedName = trimmedName.isEmpty ? String(format: NSLocalizedString("Account %d", comment: "TSBinanceCredentialStore"), allAccounts().count + 1) : trimmedName

        guard !trimmedAPIKey.isEmpty else {
            throw NSError(
                domain: "TSBinanceCredentialStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("API Key cannot be empty.", comment: "TSBinanceCredentialStore")]
            )
        }

        guard !trimmedSecret.isEmpty else {
            throw NSError(
                domain: "TSBinanceCredentialStore",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("API Secret cannot be empty.", comment: "TSBinanceCredentialStore")]
            )
        }

        let newAccount = TSBinanceAccount(
            name: resolvedName,
            apiKey: trimmedAPIKey,
            secret: trimmedSecret,
            useTestnet: useTestnet
        )

        var accounts = allAccounts()
        accounts.append(newAccount)
        try saveAccountsToKeychain(accounts)
        cachedAccounts = accounts

        // If this is the only account, activate it
        if accounts.count == 1 || activeAccountId() == nil {
            setActiveAccount(id: newAccount.id)
        } else {
            notifyChange()
        }

        return newAccount
    }

    @objc(updateAccountWithId:name:apiKey:secret:useTestnet:error:)
    public func updateAccount(id: String, name: String, apiKey: String, secret: String, useTestnet: Bool) throws {
        let accounts = allAccounts()
        guard let index = accounts.firstIndex(where: { $0.id == id }) else {
            throw NSError(
                domain: "TSBinanceCredentialStore",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Account not found.", comment: "TSBinanceCredentialStore")]
            )
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedName.isEmpty {
            accounts[index].name = trimmedName
        }
        if !trimmedAPIKey.isEmpty {
            accounts[index].apiKey = trimmedAPIKey
        }
        if !trimmedSecret.isEmpty {
            accounts[index].secret = trimmedSecret
        }
        accounts[index].useTestnet = useTestnet

        try saveAccountsToKeychain(accounts)
        cachedAccounts = accounts

        if activeAccountId() == id {
            GetStandardUserDefaults().set(useTestnet, forKey: HUDUserDefaultsKeyBinanceUseTestnet)
            GetStandardUserDefaults().synchronize()
        }

        notifyChange()
    }

    @objc(deleteAccountWithId:error:)
    public func deleteAccount(id: String) throws {
        var accounts = allAccounts()
        guard let index = accounts.firstIndex(where: { $0.id == id }) else {
            return
        }

        let wasActive = (activeAccountId() == id)
        accounts.remove(at: index)
        try saveAccountsToKeychain(accounts)
        cachedAccounts = accounts

        if wasActive {
            if let first = accounts.first {
                setActiveAccount(id: first.id)
            } else {
                GetStandardUserDefaults().removeObject(forKey: HUDUserDefaultsKeyBinanceActiveAccountId)
                GetStandardUserDefaults().synchronize()
                notifyChange()
            }
        } else {
            notifyChange()
        }
    }

    // Backward-compatible single-account save API
    @objc(saveAPIKey:secret:error:)
    public func save(apiKey: String, secret: String) throws {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAPIKey.isEmpty else {
            throw NSError(
                domain: "TSBinanceCredentialStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("API Key cannot be empty.", comment: "TSBinanceCredentialStore")]
            )
        }

        guard !trimmedSecret.isEmpty else {
            throw NSError(
                domain: "TSBinanceCredentialStore",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("API Secret cannot be empty.", comment: "TSBinanceCredentialStore")]
            )
        }

        let useTestnet = GetStandardUserDefaults().bool(forKey: HUDUserDefaultsKeyBinanceUseTestnet)

        if let active = activeAccount() {
            try updateAccount(
                id: active.id,
                name: active.name,
                apiKey: trimmedAPIKey,
                secret: trimmedSecret,
                useTestnet: useTestnet
            )
        } else {
            _ = try addAccount(
                name: NSLocalizedString("Main Account", comment: "TSBinanceCredentialStore"),
                apiKey: trimmedAPIKey,
                secret: trimmedSecret,
                useTestnet: useTestnet
            )
        }
    }

    @objc(clearCredentials:)
    public func clearCredentials(_ error: NSErrorPointer) -> Bool {
        do {
            try deleteValue(forAccount: Self.accountsAccount)
            try deleteValue(forAccount: Self.legacyApiKeyAccount)
            try deleteValue(forAccount: Self.legacySecretAccount)
            cachedAccounts = []
            GetStandardUserDefaults().removeObject(forKey: HUDUserDefaultsKeyBinanceActiveAccountId)
            GetStandardUserDefaults().synchronize()
            notifyChange()
            return true
        } catch let nsError as NSError {
            error?.pointee = nsError
            return false
        }
    }

    private func notifyChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("TSBinancePositionServiceDidUpdateNotification"),
                object: nil
            )
            NotificationCenter.default.post(
                name: UserDefaults.didChangeNotification,
                object: nil
            )
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName("com.inighty.binancemonitor.notification.hud.reload" as CFString),
                nil,
                nil,
                true
            )
        }
    }

    private func loadAccountsFromKeychain() -> [TSBinanceAccount] {
        if let jsonString = loadValue(forAccount: Self.accountsAccount),
           let data = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([TSBinanceAccount].self, from: data) {
            return decoded
        }

        // Migrate from legacy single-account storage if present
        let legacyKey = loadValue(forAccount: Self.legacyApiKeyAccount)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let legacySecret = loadValue(forAccount: Self.legacySecretAccount)?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let legacyKey, !legacyKey.isEmpty, let legacySecret, !legacySecret.isEmpty {
            let useTestnet = GetStandardUserDefaults().bool(forKey: HUDUserDefaultsKeyBinanceUseTestnet)
            let defaultAccount = TSBinanceAccount(
                name: NSLocalizedString("Default Account", comment: "TSBinanceCredentialStore"),
                apiKey: legacyKey,
                secret: legacySecret,
                useTestnet: useTestnet
            )
            let accounts = [defaultAccount]
            try? saveAccountsToKeychain(accounts)
            return accounts
        }

        return []
    }

    private func saveAccountsToKeychain(_ accounts: [TSBinanceAccount]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(accounts)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "TSBinanceCredentialStore", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to encode accounts."])
        }

        try saveValue(jsonString, forAccount: Self.accountsAccount)
    }

    private func loadValue(forAccount account: String) -> String? {
        guard case .success(let value) = loadValueResult(forAccount: account) else {
            return nil
        }

        return value
    }

    private func loadValueResult(forAccount account: String) -> TSBinanceCredentialValueResult {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return .notFound
            }
            let error = keychainError(status: status)
            if Self.isTemporarilyUnavailable(status) {
                return .temporarilyUnavailable(error)
            }
            return .failure(error)
        }

        guard
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            return .failure(NSError(
                domain: "TSBinanceCredentialStore",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to decode saved Binance credential."]
            ))
        }

        return .success(value)
    }

    private func saveValue(_ value: String, forAccount account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: Self.accessibility,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw keychainError(status: updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = Self.accessibility
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw keychainError(status: addStatus)
        }
    }

    private func deleteValue(forAccount account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError(status: status)
        }
    }

    private func keychainError(status: OSStatus) -> NSError {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)"
        return NSError(
            domain: NSOSStatusErrorDomain,
            code: Int(status),
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private static func isTemporarilyUnavailable(_ status: OSStatus) -> Bool {
        status == errSecInteractionNotAllowed || status == errSecNotAvailable
    }
}
