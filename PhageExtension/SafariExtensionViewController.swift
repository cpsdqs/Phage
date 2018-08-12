//
//  SafariExtensionViewController.swift
//  PhageExtension
//
//  Created by cpsd on 2018-07-20.
//  Copyright © 2018 cpsdqs. All rights reserved.
//

import SafariServices

class SafariExtensionViewController: SFSafariExtensionViewController, NSTableViewDataSource, NSTableViewDelegate {
    var runningScripts: [String]?
    @IBOutlet weak var scriptTableView: NSTableView!
    
    static var shared: SafariExtensionViewController {
        let shared = SafariExtensionViewController()
        shared.preferredContentSize = NSSize(width: 200, height: 200)
        return shared
    }

    override func viewDidLoad() {
        runningScripts = ["Loading…"]
        scriptTableView.dataSource = self
        scriptTableView.delegate = self
        loadScripts()
    }

    func setTableStatus(_ status: String) {
        runningScripts = [status]
        scriptTableView.reloadData()
    }

    func loadScripts() {
        setTableStatus("Getting active window…")
        SFSafariApplication.getActiveWindow { window in
            guard let window = window else {
                self.setTableStatus("No active window")
                return
            }
            self.setTableStatus("Getting active tab…")
            window.getActiveTab { tab in
                guard let tab = tab else {
                    self.setTableStatus("No active tab")
                    return
                }
                self.setTableStatus("Getting active page…")
                tab.getActivePage { page in
                    guard let page = page else {
                        self.setTableStatus("No active page")
                        return
                    }
                    self.setTableStatus("Getting running scripts…")
                    SafariExtensionHandler.getRunningScripts(from: page) { scripts in
                        self.runningScripts = scripts
                        self.scriptTableView.reloadData()
                    }
                }
            }
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return runningScripts?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ScriptNameCell"), owner: self) as! NSTableCellView
        let textField = cell.subviews[0] as! NSTextField
        textField.stringValue = runningScripts?[row] ?? "???"
        return cell
    }

}
