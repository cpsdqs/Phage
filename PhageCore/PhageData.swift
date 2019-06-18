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

/// Observes Phage user data, i.e. scripts and stylesheets.
public class PhageData : NSObject, NSFilePresenter, BindableObject {

    public override init() {
        didChange = PhageDataPublisher()
        containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)!
            .appendingPathComponent("bundles")

        super.init()
        didChange.owner = self

        fileCoordinator = NSFileCoordinator(filePresenter: self)

        reload()
    }

    // MARK: - BindableObject

    public typealias PublisherType = PhageDataPublisher

    public var didChange: PhageDataPublisher

    // MARK: - Bundle Handling

    public var bundles: [String:PhageDataBundle] = [:]

    /// Reloads all bundles.
    func reload() {
        bundles = [:]

        let directoryContents = try? FileManager.default.contentsOfDirectory(
            at: containerURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        if let directoryContents = directoryContents {
            for subitemURL in directoryContents {
                let _ = tryEnsureBundle(enclosing: subitemURL)
            }
        }

        didChange.emitToAllSubscribers(event: .bundlesReloaded)
    }

    /// Returns the enclosing bundle’s URL and the remaining subpath.
    func bundleURLAndSubpath(enclosing url: URL) -> (URL, [String])? {
        var pathComponents = url.pathComponents
        for component in containerURL.pathComponents {
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
        let bundleURL = containerURL.appendingPathComponent(pathComponents.removeFirst())
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
                    didChange.emitToAllSubscribers(event: .addedBundle(name))
                    return true
                }
            }
        }
        return false
    }

    func didDeleteBundle(at url: URL) {
        let name = bundleName(for: url)
        if bundles[name] != nil {
            bundles.removeValue(forKey: name)
        }

        didChange.emitToAllSubscribers(event: .deletedBundle(name))
    }

    func didDeleteBundleFile(at bundleURL: URL, subPath: [String]) {
        let name = bundleName(for: bundleURL)
        if tryEnsureBundle(enclosing: bundleURL) {
            if subPath.count == 1 {
                // TODO: what about deeper items?
                bundles[name]!.deletedFile(at: bundleURL.appendingPathComponent(subPath[0]))
                didChange.emitToAllSubscribers(event: .changedBundle(name))
            }
        }
    }

    func didChangeBundleFile(at bundleURL: URL, subPath: [String]) {
        let name = bundleName(for: bundleURL)
        if tryEnsureBundle(enclosing: bundleURL) {
            if subPath.count == 1 {
                // TODO: what about deeper items?
                bundles[name]!.updatedFile(at: bundleURL.appendingPathComponent(subPath[0]))
                didChange.emitToAllSubscribers(event: .changedBundle(name))
            }
        }
    }

    // MARK: - NSFilePresenter

    public var fileCoordinator: NSFileCoordinator!

    public static let appGroupID = Bundle.main.infoDictionary!["TeamIdentifierPrefix"] as! String + "net.cloudwithlightning.phage"
    public let containerURL: URL

    public var presentedItemURL: URL? {
        get {
            return containerURL
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
        if let (bundleURL, subPath) = bundleURLAndSubpath(enclosing: url) {
            if subPath.isEmpty {
                // a bundle was added (or changed, somehow?)
                let _ = tryEnsureBundle(enclosing: bundleURL)
            } else {
                didChangeBundleFile(at: bundleURL, subPath: subPath)
            }
        }
    }
}

/// A publisher associated with a PhageData object.
public class PhageDataPublisher : Publisher {

    public typealias Output = PhageDataEvent

    public typealias Failure = Never

    weak var owner: PhageData!

    var subscriptions: [PhageDataSubscription] = []

    public func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Never, S.Input == PhageDataEvent {
        let subscription = PhageDataSubscription(owner: self, receiver: subscriber as! AnySubscriber<PhageDataEvent, Never>)
        subscriptions.append(subscription)
        subscriber.receive(subscription: subscription)
    }

    func removeSubscription(_ subscription: PhageDataSubscription) {
        subscriptions.removeAll(where: { $0.id == subscription.id })
    }

    func emitToAllSubscribers(event: PhageDataEvent) {
        for subscription in subscriptions {
            subscription.send(event)
        }
    }

}

public class PhageDataSubscription : Subscription {

    let id: UUID = UUID()
    weak var owner: PhageDataPublisher?
    var receiver: AnySubscriber<PhageDataEvent, Never>

    init(owner: PhageDataPublisher, receiver: AnySubscriber<PhageDataEvent, Never>) {
        self.owner = owner
        self.receiver = receiver
    }

    public func request(_ demand: Subscribers.Demand) {
        // TODO: figure out what these are for
    }

    public func cancel() {
        if let owner = owner {
            owner.removeSubscription(self)
        }
    }

    func send(_ event: PhageDataEvent) {
        // TODO: figure out what the demand is for
        let _ = receiver.receive(event)
    }

}

/// An event that may be emitted over the lifetime of a PhageData object.
public enum PhageDataEvent {
    case bundlesReloaded
    case deletedBundle(String)
    case changedBundle(String)
    case addedBundle(String)
    case addedBundleFile(String, String)
}
