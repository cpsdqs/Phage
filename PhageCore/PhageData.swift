//
//  PhageData.swift
//  PhageCore
//
//  Created by cpsdqs on 2019-06-17.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

public let appGroupID = Bundle.main.infoDictionary!["TeamIdentifierPrefix"] as! String + "net.cloudwithlightning.phage"
public let bundlesURL = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
    .appendingPathComponent("bundles")
public let dependenciesURL = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
    .appendingPathComponent("dependencies")

/// Observes Phage user data, i.e. scripts and stylesheets.
public class PhageData : NSObject, NSFilePresenter, BindableObject {

    public var dependencies: PhageDependencies! = nil

    public override init() {
        super.init()

        dependencies = PhageDependencies(owner: self)
        NSFileCoordinator.addFilePresenter(self)

        reload()
    }

    // MARK: - BindableObject

    public var willChange = PassthroughSubject<Event, Never>()

    // MARK: - Bundle Handling

    public var bundles: [String:PhageDataBundle] = [:]

    /// Reloads all bundles.
    func reload() {
        bundles = [:]

        let directoryContents = try? FileManager.default.contentsOfDirectory(
            at: bundlesURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        if let directoryContents = directoryContents {
            for subitemURL in directoryContents {
                let _ = tryEnsureBundle(enclosing: subitemURL)
            }
        }

        willChange.send(.bundlesReloaded)
    }

    /// Returns the enclosing bundle’s URL and the remaining subpath.
    func bundleURLAndSubpath(enclosing url: URL) -> (URL, [String])? {
        var pathComponents = url.pathComponents
        for component in bundlesURL.pathComponents {
            // check if path matches and pop front
            if pathComponents.first == component {
                pathComponents.removeFirst()
            } else {
                return nil
            }
        }
        if pathComponents.isEmpty {
            return nil
        }
        let bundleURL = bundlesURL.appendingPathComponent(pathComponents.removeFirst())
        return (bundleURL, pathComponents)
    }

    func bundleName(for bundleURL: URL) -> String {
        return bundleURL.lastPathComponent
    }

    func tryEnsureBundle(enclosing url: URL) -> Bool {
        if let (bundleURL, _) = bundleURLAndSubpath(enclosing: url) {
            let name = bundleName(for: bundleURL)
            if bundles[name] == nil {
                if let bundle = PhageDataBundle(at: bundleURL) {
                    bundles[name] = bundle
                    willChange.send(.addedBundle(name))
                    return true
                }
            } else {
                return true
            }
        }
        return false
    }

    func didDeleteBundle(at url: URL) {
        let name = bundleName(for: url)
        if bundles[name] != nil {
            bundles.removeValue(forKey: name)
        }

        willChange.send(.deletedBundle(name))
    }

    func didDeleteBundleFile(at bundleURL: URL, subPath: [String]) {
        let name = bundleName(for: bundleURL)
        if tryEnsureBundle(enclosing: bundleURL) {
            if subPath.count == 1 {
                // TODO: what about deeper items?
                bundles[name]!.deletedFile(at: bundleURL.appendingPathComponent(subPath[0]))
                willChange.send(.changedBundle(name))
            }
        }
    }

    func didChangeBundleFile(at bundleURL: URL, subPath: [String]) {
        let name = bundleName(for: bundleURL)
        if tryEnsureBundle(enclosing: bundleURL) {
            if subPath.count == 1 {
                // TODO: what about deeper items?
                bundles[name]!.updatedFile(at: bundleURL.appendingPathComponent(subPath[0]))
                willChange.send(.changedBundle(name))
            }
        }
    }

    // MARK: - NSFilePresenter

    public var presentedItemURL: URL? {
        get {
            return bundlesURL
        }
    }
    public var presentedItemOperationQueue: OperationQueue = OperationQueue.main

    public func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        reload()
    }
    public func presentedItemDidMove(to newURL: URL) {
        reload()
    }
    public func presentedItemDidChange() {
        reload()
    }

    public func accommodatePresentedSubitemDeletion(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        if let (bundleURL, subPath) = bundleURLAndSubpath(enclosing: url) {
            if subPath.isEmpty {
                // bundle has been deleted
                didDeleteBundle(at: bundleURL)
            } else {
                didDeleteBundleFile(at: bundleURL, subPath: subPath)
            }
        }
    }
    public func presentedSubitemDidAppear(at url: URL) {
        // just forward to didChange because it’s handled the same way
        presentedSubitemDidChange(at: url)
    }
    public func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) {
        accommodatePresentedSubitemDeletion(at: oldURL) { _ in }
        // this is fine because presentedSubitemDidChange(at:) checks if it’s a valid url
        presentedSubitemDidChange(at: newURL)
    }
    public func presentedSubitemDidChange(at url: URL) {
        // may have been deleted instead
        if !FileManager.default.fileExists(atPath: url.path) {
            accommodatePresentedSubitemDeletion(at: url, completionHandler: { _ in })
            return
        }

        if let (bundleURL, subPath) = bundleURLAndSubpath(enclosing: url) {
            if subPath.isEmpty {
                // a bundle was added (or changed, somehow?)
                let _ = tryEnsureBundle(enclosing: bundleURL)
            } else {
                didChangeBundleFile(at: bundleURL, subPath: subPath)
            }
        }
    }

    /// An event that may be emitted over the lifetime of a PhageData object.
    public enum Event {
        case bundlesReloaded
        case deletedBundle(String)
        case changedBundle(String)
        case addedBundle(String)
    }
}
