import UIKit

@objc protocol TSBinanceAccountViewControllerDelegate: AnyObject {
    func binanceAccountViewControllerDidUpdateCredentials(_ controller: TSBinanceAccountViewController)
}

@objcMembers
final class TSBinanceAccountViewController: UIViewController, UIGestureRecognizerDelegate {
    weak var delegate: TSBinanceAccountViewControllerDelegate?

    private let store = TSBinanceCredentialStore.sharedStore()
    private var editingAccount: TSBinanceAccount?

    convenience init(account: TSBinanceAccount?) {
        self.init(nibName: nil, bundle: nil)
        self.editingAccount = account
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.keyboardDismissMode = .interactive
        return view
    }()

    private lazy var contentStack: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 18
        return stackView
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .secondaryLabel
        label.text = NSLocalizedString("Enter a read-only USD-M Futures API Key and Secret. Use the buttons below to paste directly from the clipboard.", comment: "TSBinanceAccountViewController")
        return label
    }()

    private lazy var accountNameField: UITextField = makeTextField(
        placeholder: NSLocalizedString("Account Name (e.g. Main)", comment: "TSBinanceAccountViewController"),
        secure: false
    )

    private lazy var apiKeyField: UITextField = makeTextField(
        placeholder: NSLocalizedString("API Key", comment: "TSBinanceAccountViewController"),
        secure: false
    )

    private lazy var secretField: UITextField = makeTextField(
        placeholder: NSLocalizedString("API Secret", comment: "TSBinanceAccountViewController"),
        secure: false
    )

    private lazy var testnetSwitch: UISwitch = {
        let toggle = UISwitch()
        return toggle
    }()

    private lazy var apiKeyPasteReceiver = TextFieldPasteReceiver(textField: apiKeyField) { [weak self] error in
        self?.presentError(error)
    }

    private lazy var secretPasteReceiver = TextFieldPasteReceiver(textField: secretField) { [weak self] error in
        self?.presentError(error)
    }

    private lazy var apiKeyPasteControl: UIView = makePasteControl(
        for: apiKeyField,
        pasteReceiver: apiKeyPasteReceiver,
        title: NSLocalizedString("Paste API Key", comment: "TSBinanceAccountViewController"),
        action: #selector(pasteAPIKey)
    )

    private lazy var secretPasteControl: UIView = makePasteControl(
        for: secretField,
        pasteReceiver: secretPasteReceiver,
        title: NSLocalizedString("Paste API Secret", comment: "TSBinanceAccountViewController"),
        action: #selector(pasteSecret)
    )

    private lazy var secretVisibilityButton: UIButton = makeActionButton(
        title: NSLocalizedString("Hide Secret", comment: "TSBinanceAccountViewController"),
        tintColor: view.tintColor,
        action: #selector(toggleSecretVisibility)
    )

    private lazy var clearCredentialsButton: UIButton = makeActionButton(
        title: editingAccount != nil
            ? NSLocalizedString("Delete Account", comment: "TSBinanceAccountViewController")
            : NSLocalizedString("Clear Saved Credentials", comment: "TSBinanceAccountViewController"),
        tintColor: .systemRed,
        action: #selector(clearSavedCredentials)
    )

    private lazy var positionDiagnosticsButton: UIButton = makeActionButton(
        title: NSLocalizedString("Show Position Diagnostics", comment: "TSBinanceAccountViewController"),
        tintColor: view.tintColor,
        action: #selector(showPositionDiagnostics)
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        title = editingAccount != nil
            ? NSLocalizedString("Edit Account", comment: "TSBinanceAccountViewController")
            : NSLocalizedString("Add Account", comment: "TSBinanceAccountViewController")
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(closeEditor)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Save", comment: "TSBinanceAccountViewController"),
            style: .done,
            target: self,
            action: #selector(saveCredentials)
        )

        apiKeyField.pasteConfiguration = UIPasteConfiguration(forAccepting: NSString.self)
        secretField.pasteConfiguration = UIPasteConfiguration(forAccepting: NSString.self)

        if let account = editingAccount {
            accountNameField.text = account.name
            apiKeyField.text = account.apiKey
            secretField.text = account.secret
            testnetSwitch.isOn = account.useTestnet
        } else {
            testnetSwitch.isOn = GetStandardUserDefaults().bool(forKey: HUDUserDefaultsKeyBinanceUseTestnet)
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)

        view.addSubview(scrollView)
        view.addSubview(apiKeyPasteReceiver)
        view.addSubview(secretPasteReceiver)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            apiKeyPasteReceiver.widthAnchor.constraint(equalToConstant: 1),
            apiKeyPasteReceiver.heightAnchor.constraint(equalToConstant: 1),
            apiKeyPasteReceiver.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            apiKeyPasteReceiver.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            secretPasteReceiver.widthAnchor.constraint(equalToConstant: 1),
            secretPasteReceiver.heightAnchor.constraint(equalToConstant: 1),
            secretPasteReceiver.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            secretPasteReceiver.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])

        contentStack.addArrangedSubview(descriptionLabel)

        contentStack.addArrangedSubview(makeFieldSection(
            title: NSLocalizedString("Account Name", comment: "TSBinanceAccountViewController"),
            textField: accountNameField,
            buttons: []
        ))

        contentStack.addArrangedSubview(makeFieldSection(
            title: NSLocalizedString("API Key", comment: "TSBinanceAccountViewController"),
            textField: apiKeyField,
            buttons: [apiKeyPasteControl]
        ))

        contentStack.addArrangedSubview(makeFieldSection(
            title: NSLocalizedString("API Secret", comment: "TSBinanceAccountViewController"),
            textField: secretField,
            buttons: [secretPasteControl, secretVisibilityButton]
        ))

        contentStack.addArrangedSubview(makeSwitchSection(
            title: NSLocalizedString("Use Testnet", comment: "TSBinanceAccountViewController"),
            switchControl: testnetSwitch
        ))

        if editingAccount != nil {
            contentStack.addArrangedSubview(positionDiagnosticsButton)
            contentStack.addArrangedSubview(clearCredentialsButton)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if accountNameField.text?.isEmpty ?? true {
            accountNameField.becomeFirstResponder()
        } else if apiKeyField.text?.isEmpty ?? true {
            apiKeyField.becomeFirstResponder()
        } else {
            secretField.becomeFirstResponder()
        }
    }

    private func makeSwitchSection(title: String, switchControl: UISwitch) -> UIView {
        let container = UIView()
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .equalSpacing

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .label

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(switchControl)

        container.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])
        return container
    }

    private func makeFieldSection(title: String, textField: UITextField, buttons: [UIView]) -> UIView {
        let sectionView = UIView()
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 10

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(textField)

        if !buttons.isEmpty {
            let buttonRow = UIStackView(arrangedSubviews: buttons)
            buttonRow.axis = .horizontal
            buttonRow.spacing = 10
            buttonRow.distribution = .fillEqually
            stackView.addArrangedSubview(buttonRow)
        }

        sectionView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: sectionView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: sectionView.bottomAnchor),
        ])
        return sectionView
    }

    private func makeTextField(placeholder: String, secure: Bool) -> UITextField {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.keyboardType = .asciiCapable
        textField.textContentType = .oneTimeCode
        textField.isSecureTextEntry = secure
        textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        textField.backgroundColor = .secondarySystemBackground
        return textField
    }

    private func makePasteControl(
        for targetField: UITextField,
        pasteReceiver: TextFieldPasteReceiver,
        title: String,
        action: Selector
    ) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let fallbackButton = makeActionButton(title: title, tintColor: view.tintColor, action: action)
        fallbackButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(fallbackButton)
        NSLayoutConstraint.activate([
            fallbackButton.topAnchor.constraint(equalTo: container.topAnchor),
            fallbackButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            fallbackButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            fallbackButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        if #available(iOS 16.0, *) {
            let config = UIPasteControl.Configuration()
            config.displayMode = .labelOnly
            config.cornerStyle = .capsule
            config.baseForegroundColor = view.tintColor
            config.baseBackgroundColor = .secondarySystemBackground

            let control = UIPasteControl(configuration: config)
            control.target = pasteReceiver
            control.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(control)

            NSLayoutConstraint.activate([
                control.topAnchor.constraint(equalTo: container.topAnchor),
                control.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                control.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }

        return container
    }

    private func makeActionButton(title: String, tintColor: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.setTitleColor(tintColor, for: .normal)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func closeEditor() {
        dismiss(animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var currentView: UIView? = touch.view
        while let view = currentView {
            if view is UIControl {
                return false
            }
            if NSStringFromClass(type(of: view)).contains("PasteControl") {
                return false
            }
            currentView = view.superview
        }
        return true
    }

    @objc private func toggleSecretVisibility() {
        secretField.isSecureTextEntry.toggle()
        let title = secretField.isSecureTextEntry
            ? NSLocalizedString("Show Secret", comment: "TSBinanceAccountViewController")
            : NSLocalizedString("Hide Secret", comment: "TSBinanceAccountViewController")
        secretVisibilityButton.setTitle(title, for: .normal)
    }

    @objc private func pasteAPIKey() {
        pasteFromClipboard(into: apiKeyField)
    }

    @objc private func pasteSecret() {
        pasteFromClipboard(into: secretField)
    }

    private func pasteFromClipboard(into textField: UITextField) {
        if let string = directPasteboardString(), !string.isEmpty {
            textField.text = string
            return
        }

        if #available(iOS 14.0, *) {
            UIPasteboard.general.detectPatterns(for: [.probableWebURL, .number]) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.readPasteboardStrings(into: textField)
                    case .failure(let error):
                        self?.presentError(error)
                    }
                }
            }
            return
        }

        readPasteboardStrings(into: textField)
    }

    private func readPasteboardStrings(into textField: UITextField) {
        if let string = directPasteboardString(), !string.isEmpty {
            textField.text = string
            return
        }

        let pasteboard = UIPasteboard.general
        if let itemStrings = pasteboard.itemProviders.first {
            _ = itemStrings.loadObject(ofClass: NSString.self) { [weak self] item, error in
                DispatchQueue.main.async {
                    if let string = item as? String {
                        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            textField.text = trimmed
                            return
                        }
                    }
                    if let error {
                        self?.presentError(error)
                    } else {
                        self?.presentClipboardFailureAlert()
                    }
                }
            }
            return
        }

        presentClipboardFailureAlert()
    }

    private func directPasteboardString() -> String? {
        let pasteboard = UIPasteboard.general
        if pasteboard.hasStrings,
           let value = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }

        if let stringItems = pasteboard.strings {
            for item in stringItems {
                let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }

        return nil
    }

    private func presentClipboardFailureAlert() {
        let alert = UIAlertController(
            title: NSLocalizedString("Paste Failed", comment: "TSBinanceAccountViewController"),
            message: NSLocalizedString("Unable to paste. In iOS Settings, open BinanceMonitor and set Paste from Other Apps to Ask or Allow.", comment: "TSBinanceAccountViewController"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "TSBinanceAccountViewController"), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Open Settings", comment: "TSBinanceAccountViewController"), style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        })
        present(alert, animated: true)
    }

    private func presentError(_ error: Error) {
        let alert = UIAlertController(
            title: NSLocalizedString("Paste Error", comment: "TSBinanceAccountViewController"),
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Dismiss", comment: "TSBinanceAccountViewController"), style: .default))
        present(alert, animated: true)
    }

    @objc private func showPositionDiagnostics() {
        let text = TSBinancePositionService.sharedService().diagnosticsText()
        let alert = UIAlertController(
            title: NSLocalizedString("Position Diagnostics", comment: "TSBinanceAccountViewController"),
            message: text,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Copy Diagnostics", comment: "TSBinanceAccountViewController"), style: .default) { _ in
            UIPasteboard.general.string = text
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Dismiss", comment: "TSBinanceAccountViewController"), style: .cancel))
        present(alert, animated: true)
    }

    @objc private func clearSavedCredentials() {
        if let account = editingAccount {
            let alert = UIAlertController(
                title: NSLocalizedString("Delete Account", comment: "TSBinanceAccountViewController"),
                message: String(format: NSLocalizedString("Are you sure you want to delete '%@'?", comment: "TSBinanceAccountViewController"), account.name),
                preferredStyle: .actionSheet
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("Delete Account", comment: "TSBinanceAccountViewController"), style: .destructive) { [weak self] _ in
                guard let self else { return }
                do {
                    try self.store.deleteAccount(id: account.id)
                    self.delegate?.binanceAccountViewControllerDidUpdateCredentials(self)
                    self.dismiss(animated: true)
                } catch {
                    self.presentError(error)
                }
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "TSBinanceAccountViewController"), style: .cancel))
            present(alert, animated: true)
            return
        }

        let alert = UIAlertController(
            title: NSLocalizedString("Clear Saved Credentials", comment: "TSBinanceAccountViewController"),
            message: NSLocalizedString("This will remove all saved Binance credentials from the Keychain.", comment: "TSBinanceAccountViewController"),
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Clear", comment: "TSBinanceAccountViewController"), style: .destructive) { [weak self] _ in
            guard let self else { return }
            var error: NSError?
            if self.store.clearCredentials(&error) {
                self.apiKeyField.text = nil
                self.secretField.text = nil
                self.delegate?.binanceAccountViewControllerDidUpdateCredentials(self)
                self.dismiss(animated: true)
            } else if let error {
                self.presentError(error)
            }
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "TSBinanceAccountViewController"), style: .cancel))
        present(alert, animated: true)
    }

    @objc private func saveCredentials() {
        let name = accountNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let apiKey = apiKeyField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let secret = secretField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let useTestnet = testnetSwitch.isOn

        do {
            if let account = editingAccount {
                try store.updateAccount(
                    id: account.id,
                    name: name,
                    apiKey: apiKey,
                    secret: secret,
                    useTestnet: useTestnet
                )
            } else {
                _ = try store.addAccount(
                    name: name,
                    apiKey: apiKey,
                    secret: secret,
                    useTestnet: useTestnet
                )
            }
            delegate?.binanceAccountViewControllerDidUpdateCredentials(self)
            dismiss(animated: true)
        } catch {
            presentError(error)
        }
    }
}

private final class TextFieldPasteReceiver: UIView {
    private weak var targetTextField: UITextField?
    private let onError: (Error) -> Void

    init(textField: UITextField, onError: @escaping (Error) -> Void) {
        self.targetTextField = textField
        self.onError = onError
        super.init(frame: .zero)
        pasteConfiguration = UIPasteConfiguration(forAccepting: NSString.self)
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
        itemProviders.contains { $0.canLoadObject(ofClass: NSString.self) }
    }

    override func paste(itemProviders: [NSItemProvider]) {
        for provider in itemProviders {
            if provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { [weak self] item, error in
                    DispatchQueue.main.async {
                        if let string = item as? String {
                            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                self?.targetTextField?.text = trimmed
                                return
                            }
                        }
                        if let error = error {
                            self?.onError(error)
                        }
                    }
                }
                return
            }
        }
    }
}
