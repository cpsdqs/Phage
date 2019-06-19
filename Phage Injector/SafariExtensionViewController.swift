//
//  SafariExtensionViewController.swift
//  Phage Injector
//
//  Created by cpsdqs on 2019-06-17.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import SafariServices
import SwiftUI

class SafariExtensionViewController: SFSafariExtensionViewController {
    
    static let shared: SafariExtensionViewController = {
        let shared = SafariExtensionViewController()
        shared.preferredContentSize = NSSize(width:320, height:240)
        return shared
    }()

    override func viewDidLoad() {
        let hostingView = NSHostingView(rootView: PopoutView())
        view.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

}

struct PopoutView : View {
    var body: some View {
        VStack {
            Button(action: {
                SFSafariApplication.getActiveWindow { window in
                    window?.getActiveTab { tab in
                        tab?.getActivePage { page in
                            page?.dispatchMessageToScript(withName: "forceUpdate", userInfo: [
                                "action": "single"
                            ])
                        }
                    }
                }
            }) {
                Text("Update stylesheets")
            }
        }.padding(8)
    }
}
