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

    private func serializeBundle(name: String) -> [String: Any] {
        let bundle = data.bundles[name]
        return [
            "id": name,
            "scripts": bundle?.files.filter({ (k, v) in v.type == .javascript }).map({ (k, v) in
                [
                    "id": k,
                    // TODO: required scripts
                    "prelude": "",
                    "contents": v.loadContents()
                        ?? "throw new Error('phage load error')"
                ]
            }) ?? [],
            "styles": bundle?.files.filter({ (k, v) in v.type == .stylesheet }).map({ (k, v) in
                [
                    "id": k,
                    "contents": v.loadContents()
                        ?? "/* failed to load */"
                ]
            }) ?? []
        ]
    }

    // TODO: fix this
    // MARK: PhageDataStoreListener

    func phageDataStoreDidChangeBundles() {
        performOnAllPages { page in
            // TODO: diffing
            page.dispatchMessageToScript(withName: "updateStyles", userInfo: [
                "updated": [],
                "removed": []
            ])
        }
    }

    func phageDataStoreDidChangeBundle(withName name: String) {
        performOnAllPages { page in
            page.dispatchMessageToScript(withName: "updateStyles", userInfo: [
                "updated": [self.serializeBundle(name: name)],
                "removed": []
            ])
        }
    }

    // MARK: SFSafariExtensionHandling

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        // This method will be called when a content script provided by your extension calls safari.extension.dispatchMessage("message").
        page.getPropertiesWithCompletionHandler { properties in
            NSLog("The extension received a message (\(messageName)) from a script injected into (\(String(describing: properties?.url))) with userInfo (\(userInfo ?? [:]))")
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
