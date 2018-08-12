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

var scriptRequests: [String:([String]) -> Void] = [:]

class SafariExtensionHandler: SFSafariExtensionHandler {

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        if messageName == "scriptsForURL" {
            if let urlString = userInfo?["url"] as? String {
                let scripts = loadDataStorage()

                var matchingScripts: [[String: Any]] = []
                let urlFullRange = NSRange(location: 0, length: urlString.count)

                for (uuid, script) in scripts.scriptList.scripts {
                    var doesMatch = false;
                    for glob in script.metadata.matches {
                        do {
                            guard let pattern = globToRegex(glob) else {
                                NSLog("Failed to convert \(glob) to regex")
                                continue
                            }
                            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                            if let _ = regex.firstMatch(in: urlString, options: [], range: urlFullRange) {
                                doesMatch = true;
                                break;
                            }
                        } catch _ {
                            NSLog("Failed to compile the regex for \(glob)")
                        }
                    }

                    if (doesMatch) {
                        matchingScripts.append([
                            "uuid": uuid,
                            "name": script.metadata.name,
                            "enabled": script.enabled,
                            "injectAsScriptTag": script.injectAsScriptTag,
                            "script": script.enabled ? script.script : ""
                        ])
                    }
                }

                page.dispatchMessageToScript(withName: "scriptsForURL", userInfo: [
                    "scripts": matchingScripts,
                    "id": userInfo?["id"] as Any
                ])

                if (userInfo?["topLevel"] as? Bool) ?? false {
                    SFSafariApplication.setToolbarItemsNeedUpdate()
                }
            } else {
                page.dispatchMessageToScript(withName: "scriptsForURL", userInfo: [
                    "error": "Page has no URL",
                    "id": userInfo?["id"] as Any
                ])
            }
        } else if messageName == "runningScripts" {
            if let requestID = userInfo?["request"] as? String {
                if let request = scriptRequests[requestID] {
                    if let scripts = userInfo?["scripts"] as? [String] {
                        request(scripts)
                    }
                    scriptRequests.removeValue(forKey: requestID)
                }
            }
        }
    }

    static func getRunningScripts(from page: SFSafariPage, callback: @escaping ([String]) -> Void) {
        let requestID = UUID().uuidString
        scriptRequests[requestID] = callback
        page.dispatchMessageToScript(withName: "runningScripts", userInfo: [
            "request": requestID
        ])
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        window.getActiveTab { tab in
            guard let tab = tab else {
                validationHandler(false, "")
                return
            }
            tab.getActivePage { page in
                guard let page = page else {
                    validationHandler(false, "")
                    return
                }
                page.getPropertiesWithCompletionHandler { properties in
                    if properties?.url != nil {
                        /*
                         badges are annoying

                         SafariExtensionHandler.getRunningScripts(from: page) { scripts in
                         validationHandler(true, scripts.count > 0 ? "\(scripts.count)" : "")
                         }
                         */
                        validationHandler(true, "")
                    } else {
                        // probably empty new-tab page or something
                        validationHandler(false, "")
                    }
                }
            }
        }
    }

    // TODO: look into additionalRequestHeaders and CSP

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }

}
