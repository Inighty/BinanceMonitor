//
//  TSSettingsController.swift
//  TrollSpeed
//
//  Created by Lessica on 2024/1/24.
//

import UIKit

@objc public protocol TSSettingsControllerDelegate {
    func settingHighlighted(key: String) -> Bool
    func settingDidSelect(key: String) -> Void
}

@objc open class TSSettingsController: UITableViewController {

    @objc open weak var delegate: TSSettingsControllerDelegate?
    @objc open var alreadyLaunched: Bool = false
    private var restartRequired = false

    private struct Section {
        let title: String
        let footer: String?
        let items: [TSSettingsIndex]
    }

    private var sections: [Section] = []

    private static let toggleCellIdentifier = "TSSettingsToggleCell"
    private static let valueCellIdentifier = "TSSettingsValueCell"

    @objc public convenience init() {
        self.init(style: .insetGrouped)
    }

    public override init(style: UITableView.Style) {
        super.init(style: style)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Settings", comment: "TSSettingsController")
        view.backgroundColor = .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(closeTapped)
        )

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.valueCellIdentifier)
        tableView.register(TSSwitchCell.self, forCellReuseIdentifier: Self.toggleCellIdentifier)
        tableView.cellLayoutMarginsFollowReadableWidth = true

        rebuildSections()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshAfterExternalChange()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func defaultsChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshAfterExternalChange()
        }
    }

    private func currentDisplayUsesPositions() -> Bool {
        let mode = GetStandardUserDefaults().string(forKey: HUDUserDefaultsKeyBinanceDisplayMode) ?? "positions"
        return mode != "summary"
    }

    private func rebuildSections() {
        var built: [Section] = []

        built.append(Section(
            title: NSLocalizedString("Account", comment: "TSSettingsController"),
            footer: nil,
            items: [.binanceAccount, .binanceUseTestnet]
        ))

        built.append(Section(
            title: NSLocalizedString("Data Source", comment: "TSSettingsController"),
            footer: nil,
            items: [.binanceDisplayMode, .binanceFocusSymbol, .binanceRefreshInterval]
        ))

        if currentDisplayUsesPositions() {
            built.append(Section(
                title: NSLocalizedString("Position Fields", comment: "TSSettingsController"),
                footer: NSLocalizedString("Choose which columns are shown for each open position.", comment: "TSSettingsController"),
                items: [
                    .binanceShowSymbol, .binanceShowSide, .binanceShowQuantity,
                    .binanceShowCurrentPrice, .binanceShowEntryPrice,
                    .binanceShowPnL, .binanceShowROE,
                ]
            ))
        } else {
            built.append(Section(
                title: NSLocalizedString("Summary Fields", comment: "TSSettingsController"),
                footer: NSLocalizedString("Choose which figures are shown in the account summary.", comment: "TSSettingsController"),
                items: [
                    .binanceShowTotalEquity, .binanceShowFloatingPnL,
                    .binanceShowFloatingPnLRate, .binanceShowTotalROI,
                ]
            ))
        }

        built.append(Section(
            title: NSLocalizedString("HUD Behavior", comment: "TSSettingsController"),
            footer: nil,
            items: [
                .passthroughMode, .keepInPlace, .hideAtSnapshot,
                .usesInvertedColor, .usesRotation, .usesLargeFont,
            ]
        ))

        sections = built
        tableView.reloadData()
    }

    private func refreshAfterExternalChange() {
        let usesPositions = currentDisplayUsesPositions()
        let hasPositionsSection = sections.contains { $0.items.contains(.binanceShowSymbol) }
        if usesPositions != hasPositionsSection {
            rebuildSections()
            return
        }

        guard let visible = tableView.indexPathsForVisibleRows else { return }
        for indexPath in visible {
            guard let cell = tableView.cellForRow(at: indexPath) else { continue }
            configure(cell: cell, with: sections[indexPath.section].items[indexPath.row])
        }
    }

    open override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    open override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    open override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footer
    }

    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section].items[indexPath.row]
        let cell: UITableViewCell
        switch item.kind {
        case .toggle:
            let switchCell = tableView.dequeueReusableCell(withIdentifier: Self.toggleCellIdentifier, for: indexPath) as! TSSwitchCell
            switchCell.toggleAction = { [weak self] in
                self?.didTapToggle(for: item, at: indexPath)
            }
            cell = switchCell
        case .value:
            cell = tableView.dequeueReusableCell(withIdentifier: Self.valueCellIdentifier, for: indexPath)
            cell.accessoryType = .disclosureIndicator
        }
        configure(cell: cell, with: item)
        return cell
    }

    private func configure(cell: UITableViewCell, with item: TSSettingsIndex) {
        let highlighted = delegate?.settingHighlighted(key: item.key) ?? false
        var content = cell.defaultContentConfiguration()
        content.text = item.title
        if item.kind == .value {
            content.secondaryText = item.subtitle(highlighted: highlighted, restartRequired: restartRequired)
            content.prefersSideBySideTextAndSecondaryText = true
            content.secondaryTextProperties.color = .secondaryLabel
        } else {
            content.secondaryText = nil
        }
        cell.contentConfiguration = content

        if let switchCell = cell as? TSSwitchCell {
            switchCell.setOn(highlighted, animated: false)
        }
    }

    private func didTapToggle(for item: TSSettingsIndex, at indexPath: IndexPath) {
        if item == .passthroughMode && alreadyLaunched {
            restartRequired = true
        }
        delegate?.settingDidSelect(key: item.key)
        if let cell = tableView.cellForRow(at: indexPath) {
            configure(cell: cell, with: item)
        }
    }

    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section].items[indexPath.row]
        guard item.kind == .value else { return }
        if item == .passthroughMode && alreadyLaunched {
            restartRequired = true
        }
        delegate?.settingDidSelect(key: item.key)
        if let cell = tableView.cellForRow(at: indexPath) {
            configure(cell: cell, with: item)
        }
        if item == .binanceDisplayMode {
            rebuildSections()
        }
    }
}

private final class TSSwitchCell: UITableViewCell {
    private let toggle = UISwitch()
    var toggleAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        accessoryView = toggle
        selectionStyle = .none
        toggle.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func setOn(_ on: Bool, animated: Bool) {
        if toggle.isOn != on {
            toggle.setOn(on, animated: animated)
        }
    }

    @objc private func switchChanged() {
        toggleAction?()
    }
}
