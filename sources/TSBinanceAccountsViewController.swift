import UIKit

@objc protocol TSBinanceAccountsViewControllerDelegate: AnyObject {
    func binanceAccountsViewControllerDidUpdate(_ controller: TSBinanceAccountsViewController)
}

@objcMembers
public final class TSBinanceAccountsViewController: UITableViewController {
    weak var delegate: TSBinanceAccountsViewControllerDelegate?

    private let store = TSBinanceCredentialStore.sharedStore()
    private static let cellIdentifier = "TSBinanceAccountCell"
    private static let actionCellIdentifier = "TSBinanceActionCell"

    private enum Section: Int, CaseIterable {
        case accounts
        case actions
    }

    private var accounts: [TSBinanceAccount] = []

    public convenience init() {
        self.init(style: .insetGrouped)
    }

    public override init(style: UITableView.Style) {
        super.init(style: style)
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Binance Accounts", comment: "TSBinanceAccountsViewController")
        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addAccountTapped)
        )

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellIdentifier)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.actionCellIdentifier)
        tableView.cellLayoutMarginsFollowReadableWidth = true

        reloadAccountsData()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: NSNotification.Name("TSBinancePositionServiceDidUpdateNotification"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func storeChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadAccountsData()
        }
    }

    private func reloadAccountsData() {
        accounts = store.allAccounts()
        tableView.reloadData()
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func addAccountTapped() {
        let editor = TSBinanceAccountViewController(account: nil)
        editor.delegate = self
        let nav = UINavigationController(rootViewController: editor)
        present(nav, animated: true)
    }

    // MARK: - Table View Data Source

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        switch sectionType {
        case .accounts:
            return max(accounts.count, 1) // 1 row for empty state
        case .actions:
            return 2 // "Add Account", "Position Diagnostics"
        }
    }

    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        switch sectionType {
        case .accounts:
            return NSLocalizedString("Configured Accounts", comment: "TSBinanceAccountsViewController")
        case .actions:
            return nil
        }
    }

    public override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        switch sectionType {
        case .accounts:
            return NSLocalizedString("Tap an account to switch. Swipe to edit or delete.", comment: "TSBinanceAccountsViewController")
        case .actions:
            return nil
        }
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch sectionType {
        case .accounts:
            if accounts.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
                var content = cell.defaultContentConfiguration()
                content.text = NSLocalizedString("No accounts added yet", comment: "TSBinanceAccountsViewController")
                content.textProperties.color = .secondaryLabel
                content.secondaryText = NSLocalizedString("Tap '+' or Add Account below", comment: "TSBinanceAccountsViewController")
                cell.contentConfiguration = content
                cell.accessoryType = .none
                cell.selectionStyle = .none
                return cell
            }

            let account = accounts[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.text = account.name
            content.textProperties.font = .systemFont(ofSize: 16, weight: .semibold)

            let envString = account.useTestnet
                ? NSLocalizedString("Testnet", comment: "TSBinanceAccountsViewController")
                : NSLocalizedString("Mainnet", comment: "TSBinanceAccountsViewController")
            content.secondaryText = "\(account.maskedAPIKey) • \(envString)"
            content.secondaryTextProperties.color = .secondaryLabel
            cell.contentConfiguration = content

            let isActive = (account.id == store.activeAccountId())
            cell.accessoryType = isActive ? .checkmark : .detailButton
            cell.selectionStyle = .default
            return cell

        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: Self.actionCellIdentifier, for: indexPath)
            var content = cell.defaultContentConfiguration()
            if indexPath.row == 0 {
                content.text = NSLocalizedString("Add Account...", comment: "TSBinanceAccountsViewController")
                content.textProperties.color = view.tintColor
                content.image = UIImage(systemName: "plus.circle.fill")
            } else {
                content.text = NSLocalizedString("Show Position Diagnostics", comment: "TSBinanceAccountsViewController")
                content.textProperties.color = .secondaryLabel
                content.image = UIImage(systemName: "stethoscope")
            }
            cell.contentConfiguration = content
            cell.accessoryType = .none
            cell.selectionStyle = .default
            return cell
        }
    }

    // MARK: - Table View Delegate

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let sectionType = Section(rawValue: indexPath.section) else { return }

        switch sectionType {
        case .accounts:
            guard !accounts.isEmpty else { return }
            let account = accounts[indexPath.row]
            store.setActiveAccount(id: account.id)

            UISelectionFeedbackGenerator().selectionChanged()
            tableView.reloadData()
            delegate?.binanceAccountsViewControllerDidUpdate(self)

        case .actions:
            if indexPath.row == 0 {
                addAccountTapped()
            } else {
                showPositionDiagnostics()
            }
        }
    }

    public override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard indexPath.section == Section.accounts.rawValue, indexPath.row < accounts.count else { return }
        let account = accounts[indexPath.row]
        let editor = TSBinanceAccountViewController(account: account)
        editor.delegate = self
        let nav = UINavigationController(rootViewController: editor)
        present(nav, animated: true)
    }

    public override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == Section.accounts.rawValue, indexPath.row < accounts.count else { return nil }
        let account = accounts[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: NSLocalizedString("Delete", comment: "TSBinanceAccountsViewController")) { [weak self] _, _, completion in
            guard let self else { completion(false); return }
            do {
                try self.store.deleteAccount(id: account.id)
                self.reloadAccountsData()
                self.delegate?.binanceAccountsViewControllerDidUpdate(self)
                completion(true)
            } catch {
                completion(false)
            }
        }

        let editAction = UIContextualAction(style: .normal, title: NSLocalizedString("Edit", comment: "TSBinanceAccountsViewController")) { [weak self] _, _, completion in
            guard let self else { completion(false); return }
            let editor = TSBinanceAccountViewController(account: account)
            editor.delegate = self
            let nav = UINavigationController(rootViewController: editor)
            self.present(nav, animated: true)
            completion(true)
        }
        editAction.backgroundColor = .systemOrange

        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }

    private func showPositionDiagnostics() {
        let text = TSBinancePositionService.sharedService().diagnosticsText()
        let alert = UIAlertController(
            title: NSLocalizedString("Position Diagnostics", comment: "TSBinanceAccountsViewController"),
            message: text,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Copy Diagnostics", comment: "TSBinanceAccountsViewController"), style: .default) { _ in
            UIPasteboard.general.string = text
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Dismiss", comment: "TSBinanceAccountsViewController"), style: .cancel))
        present(alert, animated: true)
    }

}

// MARK: - TSBinanceAccountViewControllerDelegate

extension TSBinanceAccountsViewController: TSBinanceAccountViewControllerDelegate {
    func binanceAccountViewControllerDidUpdateCredentials(_ controller: TSBinanceAccountViewController) {
        reloadAccountsData()
        delegate?.binanceAccountsViewControllerDidUpdate(self)
    }
}
