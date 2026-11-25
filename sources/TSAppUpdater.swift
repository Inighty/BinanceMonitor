import Foundation
import Security
import UIKit

public struct TSAppReleaseInfo: Equatable {
    public let tagName: String
    public let version: String
    public let title: String
    public let notes: String
    public let htmlURL: URL
    public let assetAPIURL: URL
    public let browserDownloadURL: URL?
    public let assetName: String
    public let assetSize: Int64
    public let isPrerelease: Bool

    public var displayVersion: String {
        version.hasPrefix("v") || version.hasPrefix("V") ? version : "v\(version)"
    }
}

public enum TSUpdateTokenSource: Equatable {
    case keychain
    case bundled
    case none
}

public enum TSAppUpdatePhase: Equatable {
    case idle
    case checking
    case upToDate(TSAppReleaseInfo?)
    case available(TSAppReleaseInfo)
    case resolvingLink(TSAppReleaseInfo)
    case downloading(Double, TSAppReleaseInfo)
    case readyToInstall(URL, TSAppReleaseInfo)
    case handedOff(TSAppReleaseInfo)
    case failed(message: String, release: TSAppReleaseInfo?, needsToken: Bool)
}

public enum TSAppUpdateError: LocalizedError {
    case invalidRepository
    case unauthorized
    case forbidden
    case notFound(hasToken: Bool)
    case httpError(Int)
    case invalidResponse
    case noAvailableRelease
    case missingInstallableAsset
    case missingRedirectLocation

    public var needsTokenConfiguration: Bool {
        switch self {
        case .unauthorized, .forbidden, .notFound:
            return true
        default:
            return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidRepository:
            return NSLocalizedString("Invalid GitHub repository configuration.", comment: "TSAppUpdater")
        case .unauthorized:
            return NSLocalizedString("GitHub token is invalid or expired. Please update your token in Settings.", comment: "TSAppUpdater")
        case .forbidden:
            return NSLocalizedString("GitHub API access denied. Check token permissions (Contents: Read-only) or try again later.", comment: "TSAppUpdater")
        case .notFound(let hasToken):
            if hasToken {
                return NSLocalizedString("Repository not found or token lacks read access to Releases.", comment: "TSAppUpdater")
            }
            return NSLocalizedString("Repository is not publicly accessible. Configure a read-only GitHub token in Settings for private repositories.", comment: "TSAppUpdater")
        case .httpError(let code):
            return String(format: NSLocalizedString("GitHub request failed (HTTP %d).", comment: "TSAppUpdater"), code)
        case .invalidResponse:
            return NSLocalizedString("Unable to parse GitHub release metadata.", comment: "TSAppUpdater")
        case .noAvailableRelease:
            return NSLocalizedString("No installable iOS release was found.", comment: "TSAppUpdater")
        case .missingInstallableAsset:
            return NSLocalizedString("This release does not contain a .tipa or .ipa package.", comment: "TSAppUpdater")
        case .missingRedirectLocation:
            return NSLocalizedString("Unable to obtain a direct download link for the private release asset.", comment: "TSAppUpdater")
        }
    }
}

public enum TSAppVersionComparator {
    /// Compares release/bundle versions including Debian-style revisions (e.g. "2.0-16" vs "2.0-15")
    /// as well as dotted semantic versions (e.g. "2.1.0" vs "2.0-15").
    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = parse(lhs)
        let right = parse(rhs)

        let coreCompare = compareNumericArrays(left.core, right.core)
        if coreCompare != .orderedSame {
            return coreCompare
        }

        return compareNumericArrays(left.revision, right.revision)
    }

    public static func isNewer(_ remote: String, than local: String) -> Bool {
        compare(remote, local) == .orderedDescending
    }

    private struct ParsedVersion {
        let core: [Int]
        let revision: [Int]
    }

    private static func parse(_ raw: String) -> ParsedVersion {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed = String(trimmed.dropFirst())
        }

        let parts = trimmed.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let coreString = parts.first.map(String.init) ?? ""
        let revisionString = parts.count > 1 ? String(parts[1]) : ""

        let coreNumbers = extractNumbers(from: coreString)
        let revisionNumbers = extractNumbers(from: revisionString)
        return ParsedVersion(core: coreNumbers, revision: revisionNumbers)
    }

    private static func extractNumbers(from text: String) -> [Int] {
        guard !text.isEmpty else { return [] }
        var numbers: [Int] = []
        var current = ""
        for ch in text {
            if ch.isNumber {
                current.append(ch)
            } else if !current.isEmpty {
                if let val = Int(current) {
                    numbers.append(val)
                }
                current = ""
            }
        }
        if !current.isEmpty, let val = Int(current) {
            numbers.append(val)
        }
        return numbers
    }

    private static func compareNumericArrays(_ lhs: [Int], _ rhs: [Int]) -> ComparisonResult {
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b {
                return a < b ? .orderedAscending : .orderedDescending
            }
        }
        return .orderedSame
    }
}

public final class TSUpdateTokenStore {
    public static let shared = TSUpdateTokenStore()

    private static let service = "com.inighty.binancemonitor.updater"
    private static let tokenAccount = "github_pat"
    private static let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    private static let infoPlistBase64Key = "TSUpdateGitHubTokenBase64"
    private static let infoPlistRawKey = "TSUpdateGitHubToken"

    private init() {}

    public func resolvedToken() -> (token: String?, source: TSUpdateTokenSource) {
        if let custom = loadKeychainToken(), !custom.isEmpty {
            return (custom, .keychain)
        }
        if let bundled = loadBundledToken(), !bundled.isEmpty {
            return (bundled, .bundled)
        }
        return (nil, .none)
    }

    public func keychainToken() -> String? {
        loadKeychainToken()
    }

    public func hasBundledToken() -> Bool {
        loadBundledToken() != nil
    }

    public func maskedToken(_ token: String?) -> String {
        guard let raw = token?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return ""
        }
        guard raw.count > 10 else {
            return "••••"
        }
        return "\(raw.prefix(6))...\(raw.suffix(4))"
    }

    public func saveKeychainToken(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try clearKeychainToken()
            return
        }

        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.tokenAccount,
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

    public func clearKeychainToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.tokenAccount,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError(status: status)
        }
    }

    private func loadKeychainToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func loadBundledToken() -> String? {
        let info = Bundle.main.infoDictionary
        if let encoded = info?[Self.infoPlistBase64Key] as? String {
            let clean = encoded.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty,
               let data = Data(base64Encoded: clean),
               let decoded = String(data: data, encoding: .utf8) {
                let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        if let raw = info?[Self.infoPlistRawKey] as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
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

@objc
public final class TSAppUpdater: NSObject {
    public static let didChangeNotification = Notification.Name("TSAppUpdaterDidChangeNotification")

    private static let sharedInstance = TSAppUpdater()
    private static let defaultRepository = "Inighty/BinanceMonitor"
    private static let infoPlistRepoKey = "TSUpdateGitHubRepo"

    @objc(sharedUpdater)
    public class func sharedUpdater() -> TSAppUpdater {
        sharedInstance
    }

    public private(set) var phase: TSAppUpdatePhase = .idle {
        didSet {
            notifyStateChanged()
        }
    }

    public private(set) var availableRelease: TSAppReleaseInfo?

    @objc public var hasAvailableUpdate: Bool {
        availableRelease != nil
    }

    @objc public var currentVersionString: String {
        let raw = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "0" : raw
    }

    @objc public var currentDisplayVersion: String {
        let ver = currentVersionString
        return ver.hasPrefix("v") || ver.hasPrefix("V") ? ver : "v\(ver)"
    }

    public var repositorySlug: String {
        if let configured = Bundle.main.infoDictionary?[Self.infoPlistRepoKey] as? String {
            let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.contains("/") {
                return trimmed
            }
        }
        return Self.defaultRepository
    }

    public var isBusy: Bool {
        switch phase {
        case .checking, .resolvingLink, .downloading:
            return true
        default:
            return false
        }
    }

    private var didCheckOnLaunch = false
    private var activeDataTask: URLSessionDataTask?
    private var activeDownloadTask: URLSessionDownloadTask?
    private var activeDownloadSession: URLSession?
    private var activeDownloadDelegate: TSUpdateDownloadDelegate?
    private weak var presentedUpdaterNav: UINavigationController?

    private override init() {
        super.init()
    }

    // MARK: - Token Status (ObjC-friendly)

    @objc public func hasAnyToken() -> Bool {
        TSUpdateTokenStore.shared.resolvedToken().source != .none
    }

    @objc public func tokenStatusSummary() -> String {
        switch TSUpdateTokenStore.shared.resolvedToken().source {
        case .keychain:
            return NSLocalizedString("Custom", comment: "TSAppUpdater")
        case .bundled:
            return NSLocalizedString("Built-in", comment: "TSAppUpdater")
        case .none:
            return NSLocalizedString("Not Set", comment: "TSAppUpdater")
        }
    }

    @objc public func updateRowSubtitle() -> String {
        if let release = availableRelease {
            return String(format: NSLocalizedString("New: %@", comment: "TSAppUpdater"), release.displayVersion)
        }
        return currentDisplayVersion
    }

    // MARK: - Entry Points

    @objc(checkOnLaunchIfEnabledFrom:)
    public func checkOnLaunchIfEnabled(from presenter: UIViewController) {
        DispatchQueue.main.async {
            guard !self.didCheckOnLaunch else { return }
            self.didCheckOnLaunch = true

            let defaults = GetStandardUserDefaults()
            let autoEnabled: Bool
            if defaults.object(forKey: HUDUserDefaultsKeyAutoCheckUpdates) != nil {
                autoEnabled = defaults.bool(forKey: HUDUserDefaultsKeyAutoCheckUpdates)
            } else {
                autoEnabled = true
            }
            guard autoEnabled else { return }

            self.checkForUpdates(interactive: false, presenter: presenter)
        }
    }

    @objc(presentUpdaterFrom:startCheck:)
    public func presentUpdater(from presenter: UIViewController, startCheck: Bool) {
        DispatchQueue.main.async {
            self.presentSheetIfNeeded(from: presenter)
            if startCheck {
                if case .available = self.phase {
                    return
                }
                if !self.isBusy {
                    self.checkForUpdates(interactive: true, presenter: presenter)
                }
            }
        }
    }

    @objc(presentTokenEditorFrom:)
    public func presentTokenEditor(from presenter: UIViewController) {
        presentTokenEditor(from: presenter, completion: nil)
    }

    public func presentTokenEditor(from presenter: UIViewController, completion: (() -> Void)?) {
        DispatchQueue.main.async {
            let store = TSUpdateTokenStore.shared
            let resolved = store.resolvedToken()
            let statusLine: String
            switch resolved.source {
            case .keychain:
                statusLine = String(
                    format: NSLocalizedString("Current: Custom token (%@)", comment: "TSAppUpdater"),
                    store.maskedToken(resolved.token)
                )
            case .bundled:
                statusLine = String(
                    format: NSLocalizedString("Current: CI built-in token (%@)", comment: "TSAppUpdater"),
                    store.maskedToken(resolved.token)
                )
            case .none:
                statusLine = NSLocalizedString("Current: Not configured (public repositories only)", comment: "TSAppUpdater")
            }

            let message = statusLine + "\n\n" + NSLocalizedString(
                "Enter a fine-grained GitHub Personal Access Token with Contents: Read-only permission for private repository updates.",
                comment: "TSAppUpdater"
            )

            let alert = UIAlertController(
                title: NSLocalizedString("GitHub Update Token", comment: "TSAppUpdater"),
                message: message,
                preferredStyle: .alert
            )

            alert.addTextField { textField in
                textField.placeholder = "github_pat_... / ghp_..."
                textField.isSecureTextEntry = true
                textField.autocorrectionType = .no
                textField.autocapitalizationType = .none
                textField.spellCheckingType = .no
                textField.clearButtonMode = .whileEditing
            }

            alert.addAction(UIAlertAction(title: NSLocalizedString("Save", comment: "TSAppUpdater"), style: .default) { _ in
                let raw = alert.textFields?.first?.text ?? ""
                self.saveTokenAndNotify(raw, presenter: presenter, completion: completion)
            })

            alert.addAction(UIAlertAction(title: NSLocalizedString("Paste & Save", comment: "TSAppUpdater"), style: .default) { _ in
                let pasted = UIPasteboard.general.string ?? ""
                if pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.presentSimpleAlert(
                        from: presenter,
                        title: NSLocalizedString("Clipboard Empty", comment: "TSAppUpdater"),
                        message: NSLocalizedString("Copy a GitHub token to your clipboard first, then try again.", comment: "TSAppUpdater")
                    )
                    return
                }
                self.saveTokenAndNotify(pasted, presenter: presenter, completion: completion)
            })

            if store.keychainToken() != nil {
                alert.addAction(UIAlertAction(title: NSLocalizedString("Clear Custom Token", comment: "TSAppUpdater"), style: .destructive) { _ in
                    do {
                        try store.clearKeychainToken()
                        self.availableRelease = nil
                        if !self.isBusy {
                            self.phase = .idle
                        } else {
                            self.notifyStateChanged()
                        }
                        completion?()
                    } catch {
                        self.presentSimpleAlert(
                            from: presenter,
                            title: NSLocalizedString("Error", comment: "TSAppUpdater"),
                            message: error.localizedDescription
                        )
                    }
                })
            }

            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "TSAppUpdater"), style: .cancel))

            let top = self.topmostViewController(from: presenter)
            top.present(alert, animated: true)
        }
    }

    // MARK: - Core Update Flow

    public func checkForUpdates(interactive: Bool, presenter: UIViewController? = nil) {
        DispatchQueue.main.async {
            if interactive, let presenter = presenter {
                self.presentSheetIfNeeded(from: presenter)
            }
            if case .available = self.phase, interactive {
                return
            }
            guard !self.isBusy else { return }

            self.phase = .checking
            self.fetchLatestRelease { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let release):
                        if TSAppVersionComparator.isNewer(release.version, than: self.currentVersionString) {
                            self.availableRelease = release
                            self.phase = .available(release)
                            if let presenter = presenter {
                                self.presentSheetIfNeeded(from: presenter)
                            }
                        } else {
                            self.availableRelease = nil
                            self.phase = interactive ? .upToDate(release) : .idle
                        }
                    case .failure(let error):
                        if interactive {
                            let needsToken = (error as? TSAppUpdateError)?.needsTokenConfiguration ?? false
                            self.phase = .failed(
                                message: error.localizedDescription,
                                release: nil,
                                needsToken: needsToken
                            )
                        } else {
                            self.phase = .idle
                        }
                    }
                }
            }
        }
    }

    /// Resolves a direct (pre-signed if private) package URL and hands it to TrollStore
    /// via `apple-magnifier://install?url=...`.
    public func installViaTrollStore(_ release: TSAppReleaseInfo) {
        DispatchQueue.main.async {
            guard !self.isBusy else { return }
            self.phase = .resolvingLink(release)

            self.resolveDirectDownloadURL(for: release) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let directURL):
                        // Strictly percent-encode every non-alphanumeric character so embedded
                        // `?`, `&`, `=`, `%` in GitHub's pre-signed Azure SAS / JWT query parameters
                        // survive URLQueryItem decoding inside TrollStore byte-for-byte intact.
                        let encoded = directURL.absoluteString
                            .addingPercentEncoding(withAllowedCharacters: .alphanumerics)
                            ?? directURL.absoluteString

                        guard let trollURL = URL(string: "apple-magnifier://install?url=\(encoded)") else {
                            self.phase = .failed(
                                message: NSLocalizedString("Unable to construct TrollStore install link.", comment: "TSAppUpdater"),
                                release: release,
                                needsToken: false
                            )
                            return
                        }

                        UIApplication.shared.open(trollURL, options: [:]) { success in
                            DispatchQueue.main.async {
                                if success {
                                    self.phase = .handedOff(release)
                                } else {
                                    self.phase = .failed(
                                        message: NSLocalizedString("Unable to open TrollStore. You can download the package and import it manually.", comment: "TSAppUpdater"),
                                        release: release,
                                        needsToken: false
                                    )
                                }
                            }
                        }

                    case .failure(let error):
                        let needsToken = (error as? TSAppUpdateError)?.needsTokenConfiguration ?? false
                        self.phase = .failed(
                            message: error.localizedDescription,
                            release: release,
                            needsToken: needsToken
                        )
                    }
                }
            }
        }
    }

    /// Fallback for non-TrollStore environments: resolves the direct (pre-signed) URL,
    /// downloads the package with progress, and opens the iOS share sheet.
    public func downloadPackage(_ release: TSAppReleaseInfo, from presenter: UIViewController?) {
        DispatchQueue.main.async {
            self.cancelActiveOperations()
            self.phase = .resolvingLink(release)

            self.resolveDirectDownloadURL(for: release) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let directURL):
                        self.startPackageDownload(from: directURL, release: release, presenter: presenter)
                    case .failure(let error):
                        let needsToken = (error as? TSAppUpdateError)?.needsTokenConfiguration ?? false
                        self.phase = .failed(
                            message: error.localizedDescription,
                            release: release,
                            needsToken: needsToken
                        )
                    }
                }
            }
        }
    }

    public func cancelActiveOperations() {
        activeDataTask?.cancel()
        activeDataTask = nil
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        activeDownloadSession?.invalidateAndCancel()
        activeDownloadSession = nil
        activeDownloadDelegate = nil
    }

    public func openReleasePage(_ release: TSAppReleaseInfo) {
        UIApplication.shared.open(release.htmlURL, options: [:], completionHandler: nil)
    }

    public func sharePackage(at fileURL: URL, from presenter: UIViewController) {
        DispatchQueue.main.async {
            let target = self.topmostViewController(from: presenter)
            let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let popover = activity.popoverPresentationController {
                popover.sourceView = target.view
                popover.sourceRect = CGRect(
                    x: target.view.bounds.midX,
                    y: target.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            target.present(activity, animated: true)
        }
    }

    // MARK: - GitHub API Requests

    private func fetchLatestRelease(completion: @escaping (Result<TSAppReleaseInfo, Error>) -> Void) {
        let slug = repositorySlug
        guard let url = URL(string: "https://api.github.com/repos/\(slug)/releases?per_page=10") else {
            completion(.failure(TSAppUpdateError.invalidRepository))
            return
        }

        let resolvedToken = TSUpdateTokenStore.shared.resolvedToken()
        let hasToken = resolvedToken.token != nil

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("BinanceMonitor-iOS", forHTTPHeaderField: "User-Agent")
        if let token = resolvedToken.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        activeDataTask?.cancel()
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            self?.activeDataTask = nil

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let http = response as? HTTPURLResponse else {
                completion(.failure(TSAppUpdateError.invalidResponse))
                return
            }

            switch http.statusCode {
            case 200..<300:
                break
            case 401:
                completion(.failure(TSAppUpdateError.unauthorized))
                return
            case 403:
                completion(.failure(TSAppUpdateError.forbidden))
                return
            case 404:
                completion(.failure(TSAppUpdateError.notFound(hasToken: hasToken)))
                return
            default:
                completion(.failure(TSAppUpdateError.httpError(http.statusCode)))
                return
            }

            guard let data = data,
                  let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                completion(.failure(TSAppUpdateError.invalidResponse))
                return
            }

            let parsed = items.compactMap { self?.parseRelease($0) }
            let stable = parsed.filter { !$0.isPrerelease }
            let pool = stable.isEmpty ? parsed : stable

            guard let best = pool.max(by: { TSAppVersionComparator.compare($0.version, $1.version) == .orderedAscending }) else {
                completion(.failure(TSAppUpdateError.noAvailableRelease))
                return
            }

            completion(.success(best))
        }

        activeDataTask = task
        task.resume()
    }

    private func parseRelease(_ obj: [String: Any]) -> TSAppReleaseInfo? {
        if let isDraft = obj["draft"] as? Bool, isDraft {
            return nil
        }

        guard let tag = obj["tag_name"] as? String,
              let htmlString = obj["html_url"] as? String,
              let htmlURL = URL(string: htmlString) else {
            return nil
        }

        let assets = obj["assets"] as? [[String: Any]] ?? []
        guard let selectedAsset = selectBestAsset(from: assets),
              let assetAPIString = selectedAsset["url"] as? String,
              let assetAPIURL = URL(string: assetAPIString),
              let assetName = selectedAsset["name"] as? String else {
            return nil
        }

        let browserDownloadURL = (selectedAsset["browser_download_url"] as? String).flatMap(URL.init)
        let assetSize = (selectedAsset["size"] as? NSNumber)?.int64Value ?? 0
        let rawTitle = (obj["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawNotes = (obj["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isPrerelease = (obj["prerelease"] as? Bool) ?? false

        let normalizedVersion: String
        if tag.hasPrefix("v") || tag.hasPrefix("V") {
            normalizedVersion = String(tag.dropFirst())
        } else {
            normalizedVersion = tag
        }

        return TSAppReleaseInfo(
            tagName: tag,
            version: normalizedVersion,
            title: rawTitle.isEmpty ? tag : rawTitle,
            notes: rawNotes,
            htmlURL: htmlURL,
            assetAPIURL: assetAPIURL,
            browserDownloadURL: browserDownloadURL,
            assetName: assetName,
            assetSize: assetSize,
            isPrerelease: isPrerelease
        )
    }

    private func selectBestAsset(from assets: [[String: Any]]) -> [String: Any]? {
        let installables = assets.filter { asset in
            guard let name = (asset["name"] as? String)?.lowercased() else { return false }
            return name.hasSuffix(".tipa") || name.hasSuffix(".ipa")
        }
        guard !installables.isEmpty else { return nil }

        let tipas = installables.filter {
            (($0["name"] as? String)?.lowercased().hasSuffix(".tipa")) == true
        }
        let candidates = tipas.isEmpty ? installables : tipas

        if #available(iOS 16.0, *) {
            if let appIntents = candidates.first(where: {
                (($0["name"] as? String)?.lowercased().contains("appintents16")) == true
            }) {
                return appIntents
            }
        } else {
            if let standard = candidates.first(where: {
                (($0["name"] as? String)?.lowercased().contains("appintents16")) == false
            }) {
                return standard
            }
        }

        return candidates.first
    }

    /// For authenticated / private repositories, requests the GitHub Release Asset API
    /// with `Accept: application/octet-stream` and intercepts the `302` redirect to extract
    /// the unauthenticated, short-lived pre-signed `release-assets.githubusercontent.com` URL.
    private func resolveDirectDownloadURL(
        for release: TSAppReleaseInfo,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let resolvedToken = TSUpdateTokenStore.shared.resolvedToken()
        guard let token = resolvedToken.token, !token.isEmpty else {
            if let browserURL = release.browserDownloadURL {
                completion(.success(browserURL))
            } else {
                completion(.failure(TSAppUpdateError.missingInstallableAsset))
            }
            return
        }

        var request = URLRequest(url: release.assetAPIURL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("BinanceMonitor-iOS", forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let redirectDelegate = TSRedirectCaptureDelegate()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config, delegate: redirectDelegate, delegateQueue: nil)

        let task = session.dataTask(with: request) { _, response, error in
            defer { session.finishTasksAndInvalidate() }

            if let captured = redirectDelegate.capturedURL {
                completion(.success(captured))
                return
            }

            if let http = response as? HTTPURLResponse {
                if (300..<400).contains(http.statusCode),
                   let location = http.value(forHTTPHeaderField: "Location"),
                   let locationURL = URL(string: location) {
                    completion(.success(locationURL))
                    return
                }
                switch http.statusCode {
                case 401:
                    completion(.failure(TSAppUpdateError.unauthorized))
                    return
                case 403:
                    completion(.failure(TSAppUpdateError.forbidden))
                    return
                case 404:
                    completion(.failure(TSAppUpdateError.notFound(hasToken: true)))
                    return
                default:
                    if !(200..<300).contains(http.statusCode) {
                        completion(.failure(TSAppUpdateError.httpError(http.statusCode)))
                        return
                    }
                }
            }

            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.failure(TSAppUpdateError.missingRedirectLocation))
        }
        task.resume()
    }

    private func startPackageDownload(
        from directURL: URL,
        release: TSAppReleaseInfo,
        presenter: UIViewController?
    ) {
        phase = .downloading(0, release)

        let delegate = TSUpdateDownloadDelegate(
            filename: release.assetName,
            onProgress: { [weak self] progress in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if case .downloading = self.phase {
                        self.phase = .downloading(progress, release)
                    }
                }
            },
            onFinish: { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.activeDownloadTask = nil
                    self.activeDownloadDelegate = nil
                    self.activeDownloadSession?.finishTasksAndInvalidate()
                    self.activeDownloadSession = nil

                    switch result {
                    case .success(let localURL):
                        self.phase = .readyToInstall(localURL, release)
                        if let presenter = presenter ?? self.presentedUpdaterNav {
                            self.sharePackage(at: localURL, from: presenter)
                        }
                    case .failure(let error):
                        let nsError = error as NSError
                        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                            self.phase = .available(release)
                        } else {
                            self.phase = .failed(
                                message: error.localizedDescription,
                                release: release,
                                needsToken: false
                            )
                        }
                    }
                }
            }
        )

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.downloadTask(with: directURL)
        activeDownloadDelegate = delegate
        activeDownloadSession = session
        activeDownloadTask = task
        task.resume()
    }

    // MARK: - Helpers

    private func saveTokenAndNotify(_ raw: String, presenter: UIViewController, completion: (() -> Void)?) {
        do {
            try TSUpdateTokenStore.shared.saveKeychainToken(raw)
            availableRelease = nil
            if !isBusy {
                phase = .idle
            } else {
                notifyStateChanged()
            }
            completion?()
        } catch {
            presentSimpleAlert(
                from: presenter,
                title: NSLocalizedString("Error", comment: "TSAppUpdater"),
                message: error.localizedDescription
            )
        }
    }

    private func presentSheetIfNeeded(from presenter: UIViewController) {
        if let existing = presentedUpdaterNav, existing.presentingViewController != nil {
            return
        }

        let sheetVC = TSAppUpdaterViewController(updater: self)
        let nav = UINavigationController(rootViewController: sheetVC)
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 24.0
            }
        }
        nav.modalPresentationStyle = .pageSheet
        presentedUpdaterNav = nav

        let target = topmostViewController(from: presenter)
        target.present(nav, animated: true)
    }

    private func presentSimpleAlert(from presenter: UIViewController, title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "TSAppUpdater"), style: .default))
        topmostViewController(from: presenter).present(alert, animated: true)
    }

    private func topmostViewController(from root: UIViewController) -> UIViewController {
        var current = root
        while let presented = current.presentedViewController, !presented.isBeingDismissed {
            current = presented
        }
        return current
    }

    private func notifyStateChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
        }
    }
}

private final class TSRedirectCaptureDelegate: NSObject, URLSessionTaskDelegate {
    private let lock = NSLock()
    private var _capturedURL: URL?

    var capturedURL: URL? {
        lock.lock()
        defer { lock.unlock() }
        return _capturedURL
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        lock.lock()
        _capturedURL = request.url
        lock.unlock()
        completionHandler(nil)
    }
}

private final class TSUpdateDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let filename: String
    private let onProgress: (Double) -> Void
    private let onFinish: (Result<URL, Error>) -> Void
    private let lock = NSLock()
    private var completed = false

    init(
        filename: String,
        onProgress: @escaping (Double) -> Void,
        onFinish: @escaping (Result<URL, Error>) -> Void
    ) {
        self.filename = filename
        self.onProgress = onProgress
        self.onFinish = onFinish
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = min(max(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0), 1)
        onProgress(fraction)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let baseDir = FileManager.default.temporaryDirectory.appendingPathComponent("BinanceMonitorUpdates", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        let destination = baseDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            finish(with: .success(destination))
        } catch {
            finish(with: .failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        finish(with: .failure(error))
    }

    private func finish(with result: Result<URL, Error>) {
        lock.lock()
        let shouldSend = !completed
        completed = true
        lock.unlock()
        guard shouldSend else { return }
        onFinish(result)
    }
}
