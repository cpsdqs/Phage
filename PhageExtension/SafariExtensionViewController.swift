//
//  SafariExtensionViewController.swift
//  PhageExtension
//
//  Created by cpsd on 2018-07-20.
//  Copyright © 2018 cpsdqs. All rights reserved.
//

import SafariServices

class SafariExtensionViewController: SFSafariExtensionViewController {
    
    static let shared: SafariExtensionViewController = {
        let shared = SafariExtensionViewController()
        shared.preferredContentSize = NSSize(width: 200, height: 61)
        return shared
    }()

    @IBAction func manageScriptsPressed(_ sender: Any) {
        // TODO: figure out why this does nothing
        self.extensionContext?.open(URL(string: "phage-injector://manage")!, completionHandler: nil)
    }

}
