//
//  SafariExtensionHandler.swift
//  Phage Extension
//
//  Created by cpsdqs on 2019-06-12.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import SafariServices
import PhageCore
import Combine

class SafariExtensionHandler: SFSafariExtensionHandler {

    let data = PhageData()

    override init() {
        super.init()
    }

    /// Runs the action once on every page.
    /// - Parameter action: the action to run on every page
    private func performOnAllPages(action: @escaping (SFSafariPage) -> Void) {
        SFSafariApplication.getAllWindows { windows in
            for window in windows {
                window.getAllTabs { tabs in
                    for tab in tabs {
                        tab.getActivePage { page in
                            if let page = page {
                                action(page)
                            }
                        }
                    }
                }
            }
        }
    }

    private func serializeBundle(name: String, matching url: URL) -> [String: Any]? {
        guard let bundle = data.bundles[name] else { return nil }

        var scripts: [[String: Any]] = []
        var styles: [[String: Any]] = []

        for (name, file) in bundle.files {
            switch file.contents() {
            case .some(.javascript(let section)):
                if section.matches(url: url) {
                    var prelude = ""
                    for dependency in file.dependencies() {
                        let stringEscapedName = dependency
                            .replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "\"", with: "\\\"")
                            .replacingOccurrences(of: "\n", with: "\\\n")
                        if let url = URL(string: dependency) {
                            if let data = data.dependencies.getDependencyContents(of: url) {
                                let commentEscapedName = dependency.replacingOccurrences(of: "*/", with: "* /")
                                prelude.append("\n/* Dependency: \(commentEscapedName) */\n")
                                prelude.append(data)
                            } else {
                                prelude.append(";alert(\"[Phage]\n\nMissing dependency “\(stringEscapedName).” Use the Phage app to download it\");\n")
                            }
                        } else {
                            prelude.append(";console.error(\"[Phage] invalid dependency \(stringEscapedName)\");\n")
                        }
                    }

                    scripts.append([
                        "name": name,
                        "prelude": prelude,
                        "contents": section.contents,
                        "inPageContext": file.inPageContext
                    ])
                }
            case .some(.stylesheets(let sections)):
                for (i, section) in sections.enumerated() {
                    if section.matches(url: url) {
                        styles.append([
                            "id": [name, i],
                            "contents": section.contents,
                        ])
                    }
                }
            case .none:
                break
            }
        }

        if scripts.isEmpty && styles.isEmpty {
            return nil
        }

        scripts.sort { (lhs, rhs) in
            let lhsName = lhs["name"] as! String
            let rhsName = rhs["name"] as! String
            return lhsName.lexicographicallyPrecedes(rhsName)
        }

        return [
            "id": name,
            "scripts": scripts,
            "styles": styles,
        ]
    }

    func serializeBundlesMatching(url: URL) -> [[String: Any]] {
        var bundles: [[String: Any]] = []
        for (name, bundle) in data.bundles {
            if bundle.disabled {
                continue
            }
            if let serialized = serializeBundle(name: name, matching: url) {
                bundles.append(serialized)
            }
        }
        return bundles
    }

    // MARK: Bundle update handling
    var version = 0

    func dispatchUpdateNotification() {
        version = version + 1
        NSLog("dispatching update notification")
        performOnAllPages { page in
            page.dispatchMessageToScript(withName: "updateAvailable", userInfo: [:])
        }
    }

    func sendCompleteUpdate(to page: SFSafariPage, url: URL, session: String) {
        page.dispatchMessageToScript(withName: "updateStyles", userInfo: [
            "sessionID": session,
            "updated": serializeBundlesMatching(url: url),
            "replace": true,
        ])
    }

    // MARK: SFSafariExtensionHandling

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        switch messageName {
        case "initInjector":
            guard let urlString = userInfo?["url"] as? String,
                let sessionID = userInfo?["sessionID"] as? String else { return }

            guard let url = URL(string: urlString) else { return }

            let bundles = serializeBundlesMatching(url: url)
            // NSLog("received init for page at \(url), sending bundles (\(bundles.count))")

            page.dispatchMessageToScript(withName: "initInjector", userInfo: [
                "sessionID": sessionID,
                "bundles": bundles,
                "version": version,
            ])
        case "updateRequest":
            guard let urlString = userInfo?["url"] as? String,
                let sessionID = userInfo?["sessionID"] as? String else { return }

            guard let url  = URL(string: urlString) else { return }

            NSLog("received update request for page at \(url)")

            sendCompleteUpdate(to: page, url: url, session: sessionID)
        default:
            NSLog("Script sent unknown message \(messageName)?")
            break
        }
    }

    override func toolbarItemClicked(in window: SFSafariWindow) {
        // This method will be called when your toolbar item is clicked.
        NSLog("The extension's toolbar item was clicked")
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        // This is called when Safari's state changed in some way that would require the extension's toolbar item to be validated again.
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }

}
