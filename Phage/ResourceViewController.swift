//
//  ResourceViewController.swift
//  Phage
//
//  Created by cat on 2018-08-18.
//  Copyright © 2018 cpsdqs. All rights reserved.
//

import Cocoa

class ResourceViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var statusTextField: NSTextField!
    let fileManager = FileManager()
    @IBOutlet weak var updateListButton: NSButton!
    
    var allScripts: [String: RequiredScriptData] = [:]
    var scriptOrder: [String] = []
    var scriptState: [String: String] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.

        statusTextField.stringValue = ""
        tableView.delegate = self
        tableView.dataSource = self

        updateAllScripts()
        tableView.reloadData()
    }

    @IBAction func openResourcesInFinder(_ sender: Any) {
        NSWorkspace.shared.openFile(requiredScriptsURL.path)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return allScripts.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let textContent: String
        switch (tableColumn?.identifier.rawValue) {
        case "url":
            textContent = scriptOrder[row]
        case "requiredBy":
            textContent = allScripts[scriptOrder[row]]!.requiredBy.joined()
        case "state":
            if let state = scriptState[scriptOrder[row]] {
                textContent = state
            } else {
                textContent = allScripts[scriptOrder[row]]!.loaded ? "Loaded" : "Not loaded"
            }
        default:
            textContent = "(error)"
        }

        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(tableColumn!.identifier.rawValue + "Label"),
                                      owner: self) as! NSTableCellView
        view.textField!.stringValue = textContent

        return view
    }

    func listSavedScripts() -> [String] {
        do {
            var savedScripts: [String] = []
            let items = try fileManager.contentsOfDirectory(atPath: requiredScriptsURL.path)
            for item in items {
                if item == ".DS_Store" {
                    continue
                }
                if let script = scriptNameForFileName(item) {
                    savedScripts.append(script)
                }
            }
            return savedScripts
        } catch {
            return []
        }
    }

    func getRequiredScripts() -> [String: [String]] {
        var requiredScripts: [String: [String]] = [:]
        let dataStorage = loadDataStorage()
        for script in dataStorage.scriptList.scripts.values {
            for requiredURL in script.metadata.requires {
                if requiredScripts[requiredURL] == nil {
                    requiredScripts[requiredURL] = []
                }
                requiredScripts[requiredURL]!.append(script.metadata.name)
            }
        }
        return requiredScripts
    }

    func updateAllScripts() {
        let savedScripts = listSavedScripts()
        let requiredScripts = getRequiredScripts()
        var scripts: [String: RequiredScriptData] = [:]
        for script in savedScripts {
            scripts[script] = RequiredScriptData(requiredBy: [], loaded: true)
        }
        for (script, requiredBy) in requiredScripts {
            scripts[script] = RequiredScriptData(requiredBy: requiredBy, loaded: savedScripts.contains(script))
        }
        allScripts = scripts
        scriptOrder = allScripts.keys.sorted()
    }

    func deleteUnusedScripts() {
        for (script, data) in allScripts {
            if data.loaded && data.requiredBy.count == 0 {
                deleteRequiredScript(named: script)
                scriptState.removeValue(forKey: script)
            }
        }
    }

    func loadMissingScripts() {
        updateListButton.isEnabled = false

        let remainingScripts = allScripts.keys.filter({ key in !allScripts[key]!.loaded })
        recursivelyLoadMissingScripts(remaining: remainingScripts) {
            DispatchQueue.main.async {
                self.updateListButton.isEnabled = true
                self.tableView.reloadData()
            }
        }
    }

    func setStatusTextAsync(_ text: String) {
        DispatchQueue.main.async {
            self.statusTextField.stringValue = text
        }
    }

    func recursivelyLoadMissingScripts(remaining: [String], completionHandler: @escaping () -> Void) {
        if remaining.isEmpty {
            setStatusTextAsync("")
            completionHandler()
            return
        }
        let script = remaining[0]
        let url = URL(string: script)!
        setStatusTextAsync("Downloading (\(remaining.count - 1) remaining)")
        scriptState[script] = "Downloading…"
        URLSession.shared.dataTask(with: url) { data, response, error in
            // load next script
            var remaining = remaining
            remaining.remove(at: 0)
            self.recursivelyLoadMissingScripts(remaining: remaining, completionHandler: completionHandler)

            if let error = error {
                self.scriptState[script] = "Failed: \(error)"
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                self.scriptState[script] = "Response is not a HTTPURLResponse"
                return
            }
            if !(200...299).contains(httpResponse.statusCode) {
                self.scriptState[script] = "Failed with code \(httpResponse.statusCode)"
                return
            }
            guard let data = data else {
                self.scriptState[script] = "No response data"
                return
            }

            guard let content = String(data: data, encoding: .utf8) else {
                self.scriptState[script] = "Could not decode UTF-8"
                return
            }

            if !writeRequiredScript(named: script, content: content) {
                self.scriptState[script] = "Failed to write"
            } else {
                self.scriptState.removeValue(forKey: script)
                self.allScripts[script]!.loaded = true

                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }.resume()

        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    @IBAction func updateResourceList(_ sender: Any) {
        updateAllScripts()
        deleteUnusedScripts()
        loadMissingScripts()
    }
}

struct RequiredScriptData {
    var requiredBy: [String]
    var loaded: Bool
}
