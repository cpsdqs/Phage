//
//  PhageDataBundle.swift
//  PhageCore
//
//  Created by cpsdqs on 2019-06-18.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import Foundation
import Combine

public class PhageDataBundle : NSObject, ObservableObject, Identifiable {

    public let url: URL
    public var files: [String:PhageDataFile] = [:]
    public var disabled: Bool {
        get {
            // check if the disabled xattr exists
            return url.withUnsafeFileSystemRepresentation { path in
                let code = getxattr(path, "disabled", nil, 0, 0, 0)
                // if getxattr fails that probably means the attribute doesn't exist
                return code != -1
            }
        }
        set(disabled) {
            url.withUnsafeFileSystemRepresentation { path in
                self.willChange.send(.changedEnabled(disabled))
                if disabled {
                    let value = "yes".data(using: .utf8)!
                    let result = value.withUnsafeBytes { data in
                        setxattr(path, "disabled", data.baseAddress, data.count, 0, 0)
                    }
                    if result < 0 {
                        NSLog("Failed to set disabled state on bundle at \(url)")
                    }
                } else {
                    removexattr(path, "disabled", 0)
                }
            }
        }
    }

    init?(at url: URL) {
        self.url = url

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

    public func dependencies() -> [URL] {
        var dependencies: [URL] = []
        for (_, file) in files {
            dependencies.append(contentsOf: file.dependencies()
                .map { URL(string: $0) }
                .filter { $0 != nil }
                .map { $0! })
        }
        return dependencies
    }

    /// Handles a new or changed file.
    /// - Parameter url: a top-level subitem of this bundle. Will not be checked for validity
    func updatedFile(at url: URL) {
        let name = url.lastPathComponent

        if let file = PhageDataFile(at: url) {
            files[name] = file
        }

        willChange.send(.changedFile(name))
    }

    func deletedFile(at url: URL) {
        let name = url.lastPathComponent
        files.removeValue(forKey: name)

        willChange.send(.deletedFile(name))
    }

    // MARK: - Identifiable
    public var id: URL {
        get {
            return url
        }
    }

    // MARK: - ObservableObject

    public var willChange = PassthroughSubject<Event, Never>()

    public enum Event {
        case changedEnabled(Bool)
        case changedFile(String)
        case deletedFile(String)
    }
}
