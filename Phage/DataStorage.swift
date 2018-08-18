//
//  DataStorage.swift
//  Phage
//
//  Created by cpsd on 2018-07-20.
//  Copyright © 2018 cpsdqs. All rights reserved.
//

import Cocoa

let appGroupID = Bundle.main.infoDictionary!["TeamIdentifierPrefix"] as! String + "net.cloudwithlightning.phage"

let fileManager = FileManager()
let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
let storageURL = containerURL.appendingPathComponent("phage_data.json")
let requiredScriptsURL = containerURL.appendingPathComponent("required_scripts", isDirectory: true)

let scriptTemplate = """
// ==UserScript==
// @name        untitled
// @namespace   http://localhost/
// @version     0.1
// @description does a thing
// @author      \(NSFullUserName())
// @match       */*
// ==/UserScript==


"""

class DataStorage: NSObject, NSOutlineViewDataSource {
    var scriptList: ScriptList

    init(json data: Data) throws {
        scriptList = try JSONDecoder().decode(ScriptList.self, from: data)
        super.init()
    }

    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(scriptList)
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return scriptList.scripts.count
        } else {
            return 0
        }
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return scriptList.orderedKeys[index]
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        if let key = item as? String {
            return scriptList.scripts[key]
        } else {
            return item
        }
    }
}

class ScriptList: Codable {
    var scripts: [String: ScriptData]

    var orderedKeys: [String] {
        get {
            return scripts.keys.sorted()
        }
    }

    private enum CodingKeys: String, CodingKey {
        case scripts
    }
}

class ScriptData: Codable {
    var script: String
    var enabled: Bool
    var injectAsScriptTag: Bool = false

    var cachedMetadata: ScriptMetadata?

    init(script: String, enabled: Bool) {
        self.script = script
        self.enabled = enabled
    }

    var metadata: ScriptMetadata {
        get {
            if cachedMetadata == nil {
                updateMetadata()
            }
            return cachedMetadata!
        }
    }

    private enum CodingKeys: String, CodingKey {
        case script
        case enabled
        case injectAsScriptTag
    }

    func updateMetadata() {
        let startRe: NSRegularExpression!
        let endRe: NSRegularExpression!
        do {
            startRe = try NSRegularExpression(pattern: "^//\\s*==UserScript==$", options: [])
            endRe = try NSRegularExpression(pattern: "^//\\s*==/UserScript==$", options: [])
        } catch _ {
            debugPrint("Failed to compile regex for updateMetadata")
            return
        }
        var inMetaBlock = false
        var metaBlock: [String] = []
        script.enumerateLines() { line, stop in
            let fullRange = NSRange(location: 0, length: line.count)
            if let _ = startRe.firstMatch(in: line, options: [], range: fullRange) {
                inMetaBlock = true
            } else if let _ = endRe.firstMatch(in: line, options: [], range: fullRange) {
                inMetaBlock = false
            } else if inMetaBlock {
                metaBlock.append(line)
            }
        }

        var metadata = ScriptMetadata()

        for line in metaBlock {
            if !line.starts(with: "//") {
                return
            }
            var line = line
            line.removeSubrange(line.startIndex..<line.index(line.startIndex, offsetBy: 2))
            line = line.trimmingCharacters(in: .whitespaces)
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2 {
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                switch parts[0] {
                case "@name":
                    metadata.name = value
                case "@namespace":
                    metadata.namespace = value
                case "@description":
                    metadata.description = value
                case "@version":
                    metadata.version = value
                case "@match":
                    metadata.matches.append(value)
                case "@author":
                    metadata.author = value
                case "@require":
                    metadata.requires.append(value)
                default:
                    debugPrint("Unknown meta tag: ", line)
                }
            }
        }

        cachedMetadata = metadata
    }
}

struct ScriptMetadata {
    var name = "(unnamed)"
    var namespace = "?"
    var description = "?"
    var version = "?"
    var author = "?"
    var matches: [String] = []
    var requires: [String] = []
}

func loadDataStorage() -> DataStorage {
    var jsonData: Data
    var scripts: DataStorage
    do {
        jsonData = try Data(contentsOf: storageURL)
    } catch _ {
        jsonData = "{\"scripts\":{}}".data(using: .utf8)!
    }

    do {
        scripts = try DataStorage(json: jsonData)
    } catch _ {
        fatalError("Failed to decode JSON data")
    }
    return scripts
}

func fileURLForScript(named name: String) -> URL {
    return requiredScriptsURL.appendingPathComponent(name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)
}

func scriptNameForFileName(_ name: String) -> String? {
    return name.removingPercentEncoding
}

func requiredScript(named name: String) -> String? {
    let scriptURL = fileURLForScript(named: name)
    let data: Data
    do {
        data = try Data(contentsOf: scriptURL)
    } catch _ {
        return nil
    }
    return String(data: data, encoding: .utf8)
}

func writeRequiredScript(named name: String, content: String) -> Bool {
    let scriptURL = fileURLForScript(named: name)
    do {
        if !fileManager.fileExists(atPath: requiredScriptsURL.absoluteString) {
            try fileManager.createDirectory(at: requiredScriptsURL, withIntermediateDirectories: true, attributes: [:])
        }
        try content.data(using: .utf8)?.write(to: scriptURL)
        return true
    } catch {
        debugPrint(error)
        return false
    }
}

func deleteRequiredScript(named name: String) {
    let scriptURL = fileURLForScript(named: name)
    do {
        try fileManager.removeItem(at: scriptURL)
    } catch {
        //
    }
}
