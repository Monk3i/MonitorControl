import Cocoa
import DDC
import os.log
import Preferences

class DisplayPrefsViewController: NSViewController, PreferencePane, NSTableViewDataSource, NSTableViewDelegate {
  var preferencePaneIdentifier = Preferences.PaneIdentifier.display
  var preferencePaneTitle: String = NSLocalizedString("Display", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "display", accessibilityDescription: "Display")!
    } else {
      // Fallback on earlier versions
      return NSImage(named: NSImage.computerName)!
    }
  }

  let prefs = UserDefaults.standard

  var displays: [Display] = []

  enum DisplayColumn: Int {
    case checkbox
    case ddc
    case name
    case friendlyName
    case identifier
    case vendor
    case model
  }

  @IBOutlet var displayList: NSTableView!

  override func viewDidLoad() {
    super.viewDidLoad()
    NotificationCenter.default.addObserver(self, selector: #selector(self.loadDisplayList), name: .displayListUpdate, object: nil)
    self.loadDisplayList()
  }

  override func viewWillAppear() {
    super.viewWillAppear()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Table datasource

  @objc func loadDisplayList() {
    os_log("Reloading display preferences display list", type: .info)
    self.displays = DisplayManager.shared.getAllDisplays()
    self.displayList.reloadData()
  }

  func numberOfRows(in _: NSTableView) -> Int {
    return self.displays.count
  }

  // MARK: - Table delegate

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let tableColumn = tableColumn,
          let columnIndex = tableView.tableColumns.firstIndex(of: tableColumn),
          let column = DisplayColumn(rawValue: columnIndex)
    else {
      return nil
    }
    let display = self.displays[row]

    switch column {
    case .checkbox:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? ButtonCellView {
        cell.display = display
        cell.button.state = display.isEnabled && !display.isVirtual ? .on : .off
        cell.button.isEnabled = !display.isVirtual
        return cell
      }
    case .ddc:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? ForceSwCellView {
        cell.display = display
        cell.button.state = ((display as? ExternalDisplay)?.isSw() ?? true) || ((display as? ExternalDisplay)?.isVirtual ?? true) ? .off : .on
        if ((display as? ExternalDisplay)?.isSwOnly() ?? true) || ((display as? ExternalDisplay)?.isVirtual ?? true) {
          cell.button.isEnabled = false
        } else {
          cell.button.isEnabled = true
        }
        return cell
      }
    case .friendlyName:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? FriendlyNameCellView {
        cell.display = display
        cell.textField?.stringValue = display.getFriendlyName()
        cell.textField?.isEditable = true
        return cell
      }
    default:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? NSTableCellView {
        cell.textField?.stringValue = self.getText(for: column, with: display)
        return cell
      }
    }

    return nil
  }

  private func getText(for column: DisplayColumn, with display: Display) -> String {
    switch column {
    case .name:
      return display.name
    case .identifier:
      return "\(display.identifier)"
    case .vendor:
      return display.identifier.vendorNumber.map { String(format: "0x%02X", $0) } ?? NSLocalizedString("Unknown", comment: "Unknown vendor")
    case .model:
      return display.identifier.modelNumber.map { String(format: "0x%02X", $0) } ?? NSLocalizedString("Unknown", comment: "Unknown model")
    default:
      return ""
    }
  }
}
