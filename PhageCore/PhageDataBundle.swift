//
//  PhageDataBundle.swift
//  PhageCore
//
//  Created by cpsdqs on 2019-06-18.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

public class PhageDataBundle : NSObject, BindableObject {

    public let url: URL
    public var files: [String:PhageDataFile] = [:]

    init?(at url: URL) {
        self.url = url
        didChange = Publisher()

        super.init()

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return nil }

        for subitemURL in contents {
            updatedFile(at: subitemURL)
        }
    }

    /// Handles a new or changed file.
    /// - Parameter url: a top-level subitem of this bundle. Will not be checked for validity
    func updatedFile(at url: URL) {
        let name = url.lastPathComponent

        if let file = PhageDataFile(at: url) {
            files[name] = file
        }

        didChange.emitToAllSubscribers(event: .changedFile(name))
    }

    func deletedFile(at url: URL) {
        let name = url.lastPathComponent
        files.removeValue(forKey: name)

        didChange.emitToAllSubscribers(event: .deletedFile(name))
    }

    // MARK: - BindableObject

    public typealias PublisherType = Publisher

    public var didChange: PhageDataBundle.Publisher

    public class Publisher: Combine.Publisher {

        public typealias Output = Event
        public typealias Failure = Never

        weak var owner: PhageData!

        var subscriptions: [Subscription] = []

        public func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Never, S.Input == Event {
            let subscription = Subscription(owner: self, receiver: subscriber as! AnySubscriber<Event, Never>)
            subscriptions.append(subscription)
            subscriber.receive(subscription: subscription)
        }

        func removeSubscription(_ subscription: Subscription) {
            subscriptions.removeAll(where: { $0.id == subscription.id })
        }

        func emitToAllSubscribers(event: Event) {
            for subscription in subscriptions {
                subscription.send(event)
            }
        }

    }

    public class Subscription : Combine.Subscription {

        let id: UUID = UUID()
        weak var owner: Publisher?
        var receiver: AnySubscriber<Event, Never>

        init(owner: Publisher, receiver: AnySubscriber<Event, Never>) {
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

        func send(_ event: Event) {
            // TODO: figure out what the demand is for
            let _ = receiver.receive(event)
        }

    }

    public enum Event {
        case changedFile(String)
        case deletedFile(String)
    }
}
