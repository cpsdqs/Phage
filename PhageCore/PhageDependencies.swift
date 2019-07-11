//
//  PhageDependencies.swift
//  PhageCore
//
//  Created by cpsdqs on 2019-06-25.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import Foundation

public class PhageDependencies {
    weak var owner: PhageData?

    init(owner: PhageData) {
        self.owner = owner

        try? FileManager.default.createDirectory(at: dependenciesURL, withIntermediateDirectories: true, attributes: nil)
    }

    func urlToFile(url: URL) -> String {
        return url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    }

    func fileToURL(name: String) -> URL? {
        if let name = name.removingPercentEncoding {
            return URL(string: name)
        }
        return nil
    }

    public func getDependencyContents(of url: URL) -> String? {
        if let data = FileManager.default.contents(
            atPath: dependenciesURL.appendingPathComponent(urlToFile(url: url)).path) {
            if let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        return nil
    }

    var urlSession: URLSession?

    public func loadDependency(at url: URL, completion: @escaping (String?) -> Void) {
        if urlSession == nil {
            urlSession = URLSession(configuration: .ephemeral)
        }

        let task = urlSession!.dataTask(with: url) { (data, response, error) in
            if let data = data {
                FileManager.default.createFile(atPath: dependenciesURL.appendingPathComponent(self.urlToFile(url: url)).path, contents: data, attributes: nil)
                completion(String(data: data, encoding: .utf8))
            } else {
                completion(nil)
            }
        }
        task.resume()
    }
}
