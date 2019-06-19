//
//  AppDelegate.swift
//  Phage
//
//  Created by cpsdqs on 2019-06-17.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import Cocoa
import SwiftUI
import PhageCore

@NSApplicationMain
class AppDelegate : NSObject, NSApplicationDelegate {

    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.title = "Phage"

        window.contentView = NSHostingView(rootView: ContentView())

        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

}

