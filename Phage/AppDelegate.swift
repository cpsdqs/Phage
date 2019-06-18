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

    var data = PhageData()

    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Main Window")

        window.contentView = NSHostingView(rootView: ContentView())

        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

}

