//
//  SafariExtensionHandler.swift
//  PhageExtension
//
//  Created by cpsd on 2018-07-20.
//  Copyright © 2018 cpsdqs. All rights reserved.
//

import SafariServices

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

class SafariExtensionHandler: SFSafariExtensionHandler {

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        if messageName == "scriptsForURL" {
            page.getPropertiesWithCompletionHandler { properties in
                if let url = properties?.url {
                    let scripts = loadDataStorage()

                    var matchingScripts: [[String: Any]] = []
                    let urlString = url.absoluteString
                    let urlFullRange = NSRange(location: 0, length: urlString.count)

                    for (uuid, script) in scripts.scriptList.scripts {
                        for glob in script.metadata.matches {
                            do {
                                guard let pattern = globToRegex(glob) else {
                                    NSLog("Failed to convert \(glob) to regex")
                                    continue
                                }
                                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                                if let _ = regex.firstMatch(in: urlString, options: [], range: urlFullRange) {
                                    matchingScripts.append([
                                        "uuid": uuid,
                                        "name": script.metadata.name,
                                        "enabled": script.enabled,
                                        "injectAsScriptTag": script.injectAsScriptTag,
                                        "script": script.enabled ? script.script : ""
                                    ])
                                }
                            } catch _ {
                                NSLog("Failed to compile the regex for \(glob)")
                            }
                        }
                    }

                    page.dispatchMessageToScript(withName: "scriptsForURL", userInfo: [
                        "scripts": matchingScripts
                    ])
                } else {
                    page.dispatchMessageToScript(withName: "scriptsForURL", userInfo: [
                        "error": "Page has no URL"
                    ])
                }
            }
        }
    }
    
    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        // This is called when Safari's state changed in some way that would require the extension's toolbar item to be validated again.
        validationHandler(true, "")
    }
    
    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }

}
