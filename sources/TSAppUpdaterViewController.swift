import UIKit

public final class TSAppUpdaterViewController: UIViewController {
    private let updater: TSAppUpdater

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let iconContainer = UIView()
    private let statusImageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let progressRing = TSUpdateProgressRingView()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let notesContainer = UIView()
    private let notesLabel = UILabel()
    private let hintLabel = UILabel()

    private let primaryButton = UIButton(type: .system)
    private let secondaryButton = UIButton(type: .system)
    private let tertiaryButton = UIButton(type: .system)

    private var primaryAction: (() -> Void)?
    private var secondaryAction: (() -> Void)?
    private var tertiaryAction: (() -> Void)?

    public init(updater: TSAppUpdater = .sharedUpdater()) {
        self.updater = updater
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.updater = .sharedUpdater()
        super.init(coder: coder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Software Update", comment: "TSAppUpdaterViewController")
        view.backgroundColor = .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(closeTapped)
        )

        setupLayout()
        renderPhase(updater.phase)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdaterStateChange),
            name: TSAppUpdater.didChangeNotification,
            object: updater
        )
    }

    @objc private func closeTapped() {
        if case .downloading = updater.phase {
            updater.cancelActiveOperations()
        }
        dismiss(animated: true)
    }

    @objc private func handleUpdaterStateChange() {
        renderPhase(updater.phase)
    }

    @objc private func didTapPrimary() {
        primaryAction?()
    }

    @objc private func didTapSecondary() {
        secondaryAction?()
    }

    @objc private func didTapTertiary() {
        tertiaryAction?()
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        view.addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 14
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])

        // Icon / Spinner / Progress Ring slot
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 96),
            iconContainer.heightAnchor.constraint(equalToConstant: 96),
        ])

        statusImageView.translatesAutoresizingMaskIntoConstraints = false
        statusImageView.contentMode = .scaleAspectFit
        iconContainer.addSubview(statusImageView)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        iconContainer.addSubview(activityIndicator)

        progressRing.translatesAutoresizingMaskIntoConstraints = false
        progressRing.isHidden = true
        iconContainer.addSubview(progressRing)

        NSLayoutConstraint.activate([
            statusImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            statusImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            statusImageView.widthAnchor.constraint(equalToConstant: 56),
            statusImageView.heightAnchor.constraint(equalToConstant: 56),

            activityIndicator.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            progressRing.topAnchor.constraint(equalTo: iconContainer.topAnchor),
            progressRing.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor),
            progressRing.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor),
            progressRing.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor),
        ])

        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        subtitleLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        notesContainer.backgroundColor = .secondarySystemGroupedBackground
        notesContainer.layer.cornerRadius = 14
        notesContainer.translatesAutoresizingMaskIntoConstraints = false

        notesLabel.translatesAutoresizingMaskIntoConstraints = false
        notesLabel.font = .systemFont(ofSize: 13, weight: .regular)
        notesLabel.textColor = .secondaryLabel
        notesLabel.numberOfLines = 6
        notesLabel.lineBreakMode = .byTruncatingTail
        notesContainer.addSubview(notesLabel)

        NSLayoutConstraint.activate([
            notesLabel.topAnchor.constraint(equalTo: notesContainer.topAnchor, constant: 12),
            notesLabel.bottomAnchor.constraint(equalTo: notesContainer.bottomAnchor, constant: -12),
            notesLabel.leadingAnchor.constraint(equalTo: notesContainer.leadingAnchor, constant: 14),
            notesLabel.trailingAnchor.constraint(equalTo: notesContainer.trailingAnchor, constant: -14),
        ])

        hintLabel.font = .systemFont(ofSize: 12, weight: .regular)
        hintLabel.textColor = .tertiaryLabel
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0

        stylePrimaryButton(primaryButton)
        primaryButton.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)

        styleSecondaryButton(secondaryButton)
        secondaryButton.addTarget(self, action: #selector(didTapSecondary), for: .touchUpInside)

        tertiaryButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        tertiaryButton.setTitleColor(.secondaryLabel, for: .normal)
        tertiaryButton.addTarget(self, action: #selector(didTapTertiary), for: .touchUpInside)

        stackView.addArrangedSubview(iconContainer)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(notesContainer)
        stackView.addArrangedSubview(hintLabel)
        stackView.addArrangedSubview(primaryButton)
        stackView.addArrangedSubview(secondaryButton)
        stackView.addArrangedSubview(tertiaryButton)

        stackView.setCustomSpacing(6, after: titleLabel)
        stackView.setCustomSpacing(16, after: hintLabel)
        stackView.setCustomSpacing(10, after: primaryButton)

        NSLayoutConstraint.activate([
            notesContainer.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            primaryButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            primaryButton.heightAnchor.constraint(equalToConstant: 48),
            secondaryButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            secondaryButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func stylePrimaryButton(_ button: UIButton) {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.cornerStyle = .large
            config.baseBackgroundColor = .systemTeal
            config.baseForegroundColor = .white
            button.configuration = config
        } else {
            button.backgroundColor = .systemTeal
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            button.layer.cornerRadius = 12
            button.layer.masksToBounds = true
        }
    }

    private func styleSecondaryButton(_ button: UIButton) {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.tinted()
            config.cornerStyle = .large
            config.baseBackgroundColor = .systemTeal
            config.baseForegroundColor = .systemTeal
            button.configuration = config
        } else {
            button.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.14)
            button.setTitleColor(.systemTeal, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            button.layer.cornerRadius = 12
            button.layer.masksToBounds = true
        }
    }

    private func setButtonTitle(_ button: UIButton, title: String) {
        if #available(iOS 15.0, *) {
            var config = button.configuration ?? UIButton.Configuration.plain()
            let fontSize: CGFloat = (button === primaryButton) ? 16 : 15
            config.title = title
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
                return outgoing
            }
            button.configuration = config
        } else {
            button.setTitle(title, for: .normal)
        }
    }

    private func showSymbol(_ systemName: String, tint: UIColor) {
        activityIndicator.stopAnimating()
        progressRing.isHidden = true
        statusImageView.isHidden = false
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 46, weight: .semibold)
        statusImageView.image = UIImage(systemName: systemName, withConfiguration: symbolConfig)
        statusImageView.tintColor = tint
    }

    private func showSpinner() {
        statusImageView.isHidden = true
        progressRing.isHidden = true
        activityIndicator.startAnimating()
    }

    private func showProgress(_ progress: Double) {
        statusImageView.isHidden = true
        activityIndicator.stopAnimating()
        progressRing.isHidden = false
        progressRing.setProgress(progress)
    }

    private func configureButtons(
        primary: (String, () -> Void)? = nil,
        secondary: (String, () -> Void)? = nil,
        tertiary: (String, () -> Void)? = nil
    ) {
        if let primary = primary {
            primaryButton.isHidden = false
            setButtonTitle(primaryButton, title: primary.0)
            primaryAction = primary.1
        } else {
            primaryButton.isHidden = true
            primaryAction = nil
        }

        if let secondary = secondary {
            secondaryButton.isHidden = false
            setButtonTitle(secondaryButton, title: secondary.0)
            secondaryAction = secondary.1
        } else {
            secondaryButton.isHidden = true
            secondaryAction = nil
        }

        if let tertiary = tertiary {
            tertiaryButton.isHidden = false
            tertiaryButton.setTitle(tertiary.0, for: .normal)
            tertiaryAction = tertiary.1
        } else {
            tertiaryButton.isHidden = true
            tertiaryAction = nil
        }
    }

    private func renderPhase(_ phase: TSAppUpdatePhase) {
        notesContainer.isHidden = true
        hintLabel.isHidden = true

        switch phase {
        case .idle, .checking:
            showSpinner()
            titleLabel.text = NSLocalizedString("Checking for Updates...", comment: "TSAppUpdaterViewController")
            subtitleLabel.text = String(
                format: NSLocalizedString("Current version %@", comment: "TSAppUpdaterViewController"),
                updater.currentDisplayVersion
            )
            configureButtons()

        case .upToDate(let release):
            showSymbol("checkmark.circle.fill", tint: .systemGreen)
            titleLabel.text = NSLocalizedString("You're Up to Date", comment: "TSAppUpdaterViewController")
            subtitleLabel.text = String(
                format: NSLocalizedString("Current version %@", comment: "TSAppUpdaterViewController"),
                updater.currentDisplayVersion
            )
            let secondary: (String, () -> Void)? = release.map { rel in
                (NSLocalizedString("View Release on GitHub", comment: "TSAppUpdaterViewController"), { [weak self] in
                    self?.updater.openReleasePage(rel)
                })
            }
            configureButtons(
                primary: (NSLocalizedString("Done", comment: "TSAppUpdaterViewController"), { [weak self] in
                    self?.dismiss(animated: true)
                }),
                secondary: secondary
            )

        case .available(let release):
            showSymbol("arrow.down.circle.fill", tint: .systemTeal)
            titleLabel.text = String(
                format: NSLocalizedString("Update Available (%@)", comment: "TSAppUpdaterViewController"),
                release.displayVersion
            )

            let sizeText = release.assetSize > 0
                ? " • " + ByteCountFormatter.string(fromByteCount: release.assetSize, countStyle: .file)
                : ""
            subtitleLabel.text = String(
                format: NSLocalizedString("Current %@ → %@%@", comment: "TSAppUpdaterViewController"),
                updater.currentDisplayVersion,
                release.displayVersion,
                sizeText
            )

            if !release.notes.isEmpty {
                notesContainer.isHidden = false
                notesLabel.text = release.notes
            }

            hintLabel.isHidden = false
            hintLabel.text = NSLocalizedString(
                "Installs directly via TrollStore (including private repositories). Use Download Package for manual sideloading.",
                comment: "TSAppUpdaterViewController"
            )

            configureButtons(
                primary: (NSLocalizedString("Install via TrollStore", comment: "TSAppUpdaterViewController"), { [weak self] in
                    self?.updater.installViaTrollStore(release)
                }),
                secondary: (NSLocalizedString("Download Package (.tipa)", comment: "TSAppUpdaterViewController"), { [weak self] in
                    guard let self = self else { return }
                    self.updater.downloadPackage(release, from: self)
                }),
                tertiary: (NSLocalizedString("Later", comment: "TSAppUpdaterViewController"), { [weak self] in
                    self?.dismiss(animated: true)
                })
            )

        case .resolvingLink(let release):
            showSpinner()
            titleLabel.text = NSLocalizedString("Preparing Download Link...", comment: "TSAppUpdaterViewController")
            subtitleLabel.text = release.assetName
            configureButtons()

        case .downloading(let progress, let release):
            showProgress(progress)
            titleLabel.text = String(
                format: NSLocalizedString("Downloading %d%%", comment: "TSAppUpdaterViewController"),
                Int((progress * 100).rounded())
            )
            subtitleLabel.text = release.assetName
            configureButtons(
                tertiary: (NSLocalizedString("Cancel Download", comment: "TSAppUpdaterViewController"), { [weak self] in
                    self?.updater.cancelActiveOperations()
                })
            )

        case .readyToInstall(let fileURL, let release):
            showSymbol("square.and.arrow.down.fill", tint: .systemTeal)
            titleLabel.text = NSLocalizedString("Download Complete", comment: "TSAppUpdaterViewController")
            subtitleLabel.text = release.assetName
            hintLabel.isHidden = false
            hintLabel.text = NSLocalizedString(
                "Use the share sheet to import the package into TrollStore, Files, or a signing app.",
                comment: "TSAppUpdaterViewController"
            )
            configureButtons(
                primary: (NSLocalizedString("Import / Share Package", comment: "TSAppUpdaterViewController"), { [weak self] in
                    guard let self = self else { return }
                    self.updater.sharePackage(at: fileURL, from: self)
                }),
                tertiary: (NSLocalizedString("Done", comment: "TSAppUpdaterViewController"), { [weak self] in
                    self?.dismiss(animated: true)
                })
            )

        case .handedOff(let release):
            showSymbol("checkmark.circle.fill", tint: .systemGreen)
            titleLabel.text = NSLocalizedString("Handed Off to TrollStore", comment: "TSAppUpdaterViewController")
            subtitleLabel.text = release.displayVersion
            hintLabel.isHidden = false
            hintLabel.text = NSLocalizedString(
                "Please confirm the installation inside TrollStore.",
                comment: "TSAppUpdaterViewController"
            )
            configureButtons(
                primary: (NSLocalizedString("Done", comment: "TSAppUpdaterViewController"), { [weak self] in
                    self?.dismiss(animated: true)
                })
            )

        case .failed(let message, let release, let needsToken):
            showSymbol("exclamationmark.triangle.fill", tint: .systemOrange)
            titleLabel.text = NSLocalizedString("Update Failed", comment: "TSAppUpdaterViewController")
            subtitleLabel.text = message

            if needsToken {
                configureButtons(
                    primary: (NSLocalizedString("Configure GitHub Token", comment: "TSAppUpdaterViewController"), { [weak self] in
                        guard let self = self else { return }
                        self.updater.presentTokenEditor(from: self) { [weak self] in
                            guard let self = self else { return }
                            self.updater.checkForUpdates(interactive: true, presenter: self)
                        }
                    }),
                    secondary: (NSLocalizedString("Try Again", comment: "TSAppUpdaterViewController"), { [weak self] in
                        guard let self = self else { return }
                        self.updater.checkForUpdates(interactive: true, presenter: self)
                    })
                )
            } else if let release = release {
                configureButtons(
                    primary: (NSLocalizedString("Download Package (.tipa)", comment: "TSAppUpdaterViewController"), { [weak self] in
                        guard let self = self else { return }
                        self.updater.downloadPackage(release, from: self)
                    }),
                    secondary: (NSLocalizedString("View Release on GitHub", comment: "TSAppUpdaterViewController"), { [weak self] in
                        self?.updater.openReleasePage(release)
                    })
                )
            } else {
                configureButtons(
                    primary: (NSLocalizedString("Try Again", comment: "TSAppUpdaterViewController"), { [weak self] in
                        guard let self = self else { return }
                        self.updater.checkForUpdates(interactive: true, presenter: self)
                    })
                )
            }
        }
    }
}

private final class TSUpdateProgressRingView: UIView {
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let percentLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.tertiarySystemFill.cgColor
        trackLayer.lineWidth = 8
        layer.addSublayer(trackLayer)

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.systemTeal.cgColor
        progressLayer.lineWidth = 8
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)

        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        percentLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        percentLabel.textColor = .label
        percentLabel.textAlignment = .center
        percentLabel.text = "0%"
        addSubview(percentLabel)

        NSLayoutConstraint.activate([
            percentLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            percentLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = max(min(bounds.width, bounds.height) / 2 - 6, 1)
        let path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 1.5 * .pi,
            clockwise: true
        )
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
        trackLayer.strokeColor = UIColor.tertiarySystemFill.cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        trackLayer.strokeColor = UIColor.tertiarySystemFill.cgColor
        progressLayer.strokeColor = UIColor.systemTeal.cgColor
    }

    func setProgress(_ progress: Double) {
        let clamped = min(max(progress, 0), 1)
        progressLayer.strokeEnd = CGFloat(clamped)
        percentLabel.text = "\(Int((clamped * 100).rounded()))%"
    }
}
