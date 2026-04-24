import Foundation
import Security

@objcMembers
final class TSBinanceCredentialStore: NSObject {
    private static let service = "ch.xxtou.hudapp.binance"
    private static let apiKeyAccount = "apiKey"
    private static let secretAccount = "secret"

    private static let sharedInstance = TSBinanceCredentialStore()

    @objc(sharedStore)
    class func sharedStore() -> TSBinanceCredentialStore {
        sharedInstance
    }

    func hasCredentials() -> Bool {
        guard
            let apiKey = currentAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines),
            !apiKey.isEmpty,
            let secret = currentSecret()?.trimmingCharacters(in: .whitespacesAndNewlines),
            !secret.isEmpty
        else {
            return false
        }

        return true
    }

    func currentAPIKey() -> String? {
        loadValue(forAccount: Self.apiKeyAccount)
    }

    func currentSecret() -> String? {
        loadValue(forAccount: Self.secretAccount)
    }

    @objc(saveAPIKey:secret:error:)
    func save(apiKey: String, secret: String) throws {
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

        try saveValue(trimmedAPIKey, forAccount: Self.apiKeyAccount)
        try saveValue(trimmedSecret, forAccount: Self.secretAccount)
    }

    @objc(clearCredentials:)
    func clearCredentials(_ error: NSErrorPointer) -> Bool {
        do {
            try deleteValue(forAccount: Self.apiKeyAccount)
            try deleteValue(forAccount: Self.secretAccount)
            return true
        } catch let nsError as NSError {
            error?.pointee = nsError
            return false
        }
    }

    private func loadValue(forAccount account: String) -> String? {
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
            return nil
        }

        guard
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return value
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
}
