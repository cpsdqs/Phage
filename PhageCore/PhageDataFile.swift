//
//  PhageDataFile.swift
//  PhageCore
//
//  Created by cpsdqs on 2019-06-18.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import Foundation
import SwiftUI

public class PhageDataFile : NSObject, Identifiable {
    public let url: URL
    public let type: FileType

    init?(at url: URL) {
        let pathExtension = url.pathExtension

        let type: PhageDataFile.FileType

        switch pathExtension {
        case "js":
            type = .javascript
        case "css":
            type = .stylesheet
        default:
            // unsupported
            return nil
        }

        self.url = url
        self.type = type
    }

    var cachedContents: Contents?
    var cachedDependencies: [String]?

    public func contents() -> Contents? {
        if let contents = cachedContents {
            return contents
        }

        guard let rawContents = loadRawContents() else { return nil }

        switch type {
        case .javascript:
            if let meta = parseScriptMetadata(for: rawContents) {
                cachedContents = .javascript(Section(rules: meta.matches, contents: rawContents))
                cachedDependencies = meta.requires
            }
        case .stylesheet:
            cachedContents = .stylesheets(parseCSSFileSections(rawContents))
        }

        return cachedContents
    }

    public func dependencies() -> [String] {
        let _ = contents()
        return cachedDependencies ?? []
    }

    func loadRawContents() -> String? {
        if let data = FileManager.default.contents(atPath: url.path) {
            if let string = String(data: data, encoding: .utf8) {
                return string
            }
        }

        return nil
    }

    // MARK: - Identifiable
    public var id: URL {
        get {
            return url
        }
    }

    public enum FileType {
        case javascript
        case stylesheet
    }

    public enum Contents {
        case javascript(Section)
        case stylesheets([Section])
    }
}

/// Various types of URL matching.
public enum MatchRule: Equatable {
    /// Matches a glob, such as `https://example.com/**/test`
    case glob(String)
    /// Matches an exact URL.
    case exact(String)
    /// Matches if the URL starts with the given prefix.
    case prefix(String)
    /// Matches if the URL is on the given domain or subdomain.
    case domain(String)
    /// Matches using the regular expression.
    case regexp(String)

    func match(_ url: URL) -> Bool {
        switch self {
        case .glob(let pattern):
            let regex = globToRegex(pattern)
            return MatchRule.regexp(regex).match(url)
        case .exact(let pattern):
            return url.absoluteString == pattern
        case .prefix(let pattern):
            return url.absoluteString.starts(with: pattern)
        case .domain(let pattern):
            // FIXME: does not match subdomains
            return url.host == pattern
        case .regexp(let pattern):
            if let regexp = try? NSRegularExpression(pattern: pattern, options: .init()) {
                let urlString = url.absoluteString
                return regexp.firstMatch(in: urlString, options: .init(), range: NSMakeRange(0, urlString.count)) != nil
            } else {
                return false
            }
        }
    }
}

func globToRegex(_ glob: String) -> String {
    var regex = ""

    var index = glob.startIndex
    var mayDoDoubleStar = true
    while index < glob.endIndex {
        let c = glob[index]
        switch c {
        case "?":
            regex.append("[^/]")
            mayDoDoubleStar = false
        case "*":
            if mayDoDoubleStar {
                if glob[index...].starts(with: "**/") || glob[index...] == "**" {
                    regex.append("[^/]*(?:/[^/])*")
                    index = glob.index(index, offsetBy: 2)
                    mayDoDoubleStar = false
                    continue
                }
            }
            regex.append("[^/]*")
        case "/":
            regex.append("/")
            mayDoDoubleStar = true
        case "[":
            var i = glob.index(index, offsetBy: 1)
            var chars = ""
            while i < glob.endIndex && (glob[i] != "]" || chars.isEmpty) {
                let c = glob[i]
                if chars.isEmpty && c == "!" {
                    chars.append("^")
                } else {
                    // TODO: ranges
                    switch c {
                    case "\\":
                        chars.append("\\\\")
                    case "^":
                        chars.append("\\^")
                    default:
                        chars.append(c)
                    }
                }
                i = glob.index(i, offsetBy: 1)
            }
            if i < glob.endIndex && glob[i] == "]" {
                regex.append("[\(chars)]")
                index = glob.index(i, offsetBy: 1)
                continue
            }
        default:
            regex.append(c)
        }
        index = glob.index(index, offsetBy: 1)
    }

    return regex
}

public struct Section {
    public let rules: [MatchRule]
    public let contents: String

    public func matches(url: URL) -> Bool {
        if rules.isEmpty {
            return true
        }
        for rule in rules {
            if rule.match(url) {
                return true
            }
        }
        return false
    }
}

public struct ScriptMeta {
    var name = "(unnamed)"
    var namespace = "?"
    var description = "?"
    var version = "?"
    var author = "?"
    var matches: [MatchRule] = []
    var requires: [String] = []
}

/// A simple CSS parser that extracts @document sections.
func parseCSSFileSections(_ contents: String) -> [Section] {
    var sectionRanges: [Range<String.Index>] = []

    func consumeComment(in string: String, at startIndex: String.Index) -> String.Index? {
        let substr = string[startIndex...]
        if substr.starts(with: "/*") {
            return substr.range(of: "*/")?.upperBound
        }
        return nil
    }

    func consumeString(in string: String, at startIndex: String.Index, escaping delimiter: Character) -> String.Index? {
        var index = startIndex
        while index < string.endIndex {
            let c = string[index]
            switch c {
            case "\\":
                // escape next character
                index = string.index(index, offsetBy: 1)
            case delimiter:
                // end of string
                return index
            default:
                break
            }
            index = string.index(index, offsetBy: 1)
        }
        return nil
    }

    func matchAtDocumentToken(at index: String.Index) -> String.Index? {
        let options = ["@document", "@-moz-document"]
        let substr = contents[index...]
        for option in options {
            if substr.starts(with: option) {
                return contents.index(index, offsetBy: option.count)
            }
        }
        return nil
    }

    func consumeTillMatchingBrace(at startIndex: String.Index) -> String.Index {
        var braceDepth = 0

        var index = startIndex
        while index < contents.endIndex {
            let c = contents[index]
            if let newIndex = consumeComment(in: contents, at: index) {
                index = newIndex
                continue
            }
            switch c {
            case "{":
                braceDepth += 1
            case "}":
                braceDepth -= 1
                if braceDepth <= 0 {
                    return contents.index(index, offsetBy: 1)
                }
            case "'":
                let startIndex = contents.index(index, offsetBy: 1)
                if let newIndex = consumeString(in: contents, at: startIndex, escaping: "'") {
                    index = contents.index(newIndex, offsetBy: 1)
                    continue
                }
            case "\"":
                let startIndex = contents.index(index, offsetBy: 1)
                if let newIndex = consumeString(in: contents, at: startIndex, escaping: "\"") {
                    index = contents.index(newIndex, offsetBy: 1)
                    continue
                }
            default:
                break
            }
            index = contents.index(index, offsetBy: 1)
        }
        return index
    }

    var index = contents.startIndex
    while index < contents.endIndex {
        let c = contents[index]

        if let newIndex = consumeComment(in: contents, at: index) {
            index = newIndex
            continue
        }

        if !c.isWhitespace {
            if let newIndex = matchAtDocumentToken(at: index) {
                let lowerBound = newIndex
                let upperBound = consumeTillMatchingBrace(at: newIndex)
                index = upperBound
                sectionRanges.append(lowerBound..<upperBound)
                continue
            } else {
                // some other CSS rule; skip
                index = consumeTillMatchingBrace(at: index)
                continue
            }
        }

        index = contents.index(index, offsetBy: 1)
    }

    var sections: [Section] = []

    sectionLoop: for sectionRange in sectionRanges {
        let sectionContents = contents[sectionRange]
        guard let matchRulesEnd = sectionContents.firstIndex(of: "{") else { continue }
        let matchRules = String(sectionContents[sectionContents.startIndex..<matchRulesEnd])

        var sectionInnerContents = sectionContents[matchRulesEnd...]
        // drop { and }
        sectionInnerContents.removeFirst()
        sectionInnerContents.removeLast()

        var rules: [MatchRule] = []

        func appendRule(_ name: String, start: String.Index, end: String.Index) {
            let escapedContents = matchRules[start..<end]

            // unescaped contents
            var contents = ""

            var index = escapedContents.startIndex
            while index < escapedContents.endIndex {
                let c = escapedContents[index]
                switch c {
                case "\\":
                    if c.isHexDigit {
                        // 2–6 hex digits plus optional whitespace character, according to spec
                        var digits = ""
                        while index < escapedContents.endIndex && digits.count < 6 {
                            if escapedContents[index].isHexDigit {
                                digits.append(escapedContents[index])
                                index = escapedContents.index(index, offsetBy: 1)
                            } else {
                                break
                            }
                        }
                        if escapedContents[index].isWhitespace {
                            index = escapedContents.index(index, offsetBy: 1)
                        }

                        if let scalar = UnicodeScalar(Int(digits, radix: 16)!) {
                            contents.append(Character(scalar))
                        }
                    } else if c.isNewline {
                        // skip all whitespace that follows
                        while index < escapedContents.endIndex && escapedContents[index].isWhitespace {
                            index = escapedContents.index(index, offsetBy: 1)
                        }
                    } else {
                        index = escapedContents.index(index, offsetBy: 1)
                    }
                default:
                    contents.append(c)
                    index = escapedContents.index(index, offsetBy: 1)
                }
            }

            switch name {
            case "url(":
                rules.append(.exact(contents))
            case "url-prefix(":
                rules.append(.prefix(contents))
            case "domain(":
                rules.append(.domain(contents))
            case "regexp(":
                rules.append(.regexp(contents))
            default:
                break
            }
        }

        var index = matchRules.startIndex
        var didPassComma = true
        outer: while index < matchRules.endIndex {
            if let newIndex = consumeComment(in: matchRules, at: index) {
                index = newIndex
                continue
            }

            let ruleNames = ["url(", "url-prefix(", "domain(", "regexp("]

            for name in ruleNames {
                if matchRules[index...].starts(with: name) {
                    index = matchRules.index(index, offsetBy: name.count)

                    switch matchRules[index] {
                    case "\"":
                        let startIndex = matchRules.index(index, offsetBy: 1)
                        if let endIndex = consumeString(in: matchRules, at: startIndex, escaping: "\"") {
                            appendRule(name, start: startIndex, end: endIndex)
                            index = matchRules.index(endIndex, offsetBy: 2) // ")
                            didPassComma = false
                            continue outer
                        }
                    case "'":
                        let startIndex = matchRules.index(index, offsetBy: 1)
                        if let endIndex = consumeString(in: matchRules, at: startIndex, escaping: "'") {
                            appendRule(name, start: startIndex, end: endIndex)
                            index = matchRules.index(endIndex, offsetBy: 2) // ')
                            didPassComma = false
                            continue outer
                        }
                    default:
                        if name != "regexp(" {
                            // regex must be quoted
                            if let endIndex = consumeString(in: matchRules, at: index, escaping: ")") {
                                appendRule(name, start: index, end: endIndex)
                                index = matchRules.index(endIndex, offsetBy: 1) // )
                                didPassComma = false
                                continue outer
                            }
                        }
                    }
                }
            }

            if !didPassComma && matchRules[index] == "," {
                didPassComma = true
                index = matchRules.index(index, offsetBy: 1)
                continue
            }

            if matchRules[index].isWhitespace {
                index = matchRules.index(index, offsetBy: 1)
            } else {
                // invalid
                continue sectionLoop
            }
        }

        sections.append(Section(rules: rules, contents: String(sectionInnerContents)))
    }

    return sections
}

func parseScriptMetadata(for script: String) -> ScriptMeta? {
    let startRe = try! NSRegularExpression(pattern: "^//\\s*==UserScript==$", options: [])
    let endRe = try! NSRegularExpression(pattern: "^//\\s*==/UserScript==$", options: [])
    var inMetaBlock = false
    var metaBlock: [String] = []
    script.enumerateLines() { line, stop in
        let fullRange = NSRange(location: 0, length: line.count)
        if let _ = startRe.firstMatch(in: line, options: [], range: fullRange) {
            inMetaBlock = true
        } else if let _ = endRe.firstMatch(in: line, options: [], range: fullRange) {
            inMetaBlock = false
        } else if inMetaBlock {
            metaBlock.append(line)
        }
    }

    var metadata = ScriptMeta()

    for line in metaBlock {
        if !line.starts(with: "//") {
            return nil
        }
        var line = line
        line.removeSubrange(line.startIndex..<line.index(line.startIndex, offsetBy: 2))
        line = line.trimmingCharacters(in: .whitespaces)
        let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count == 2 {
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            switch parts[0] {
            case "@name":
                metadata.name = value
            case "@namespace":
                metadata.namespace = value
            case "@description":
                metadata.description = value
            case "@version":
                metadata.version = value
            case "@match":
                metadata.matches.append(.glob(value))
            case "@author":
                metadata.author = value
            case "@require":
                metadata.requires.append(value)
            default:
                debugPrint("Unknown meta tag: ", line)
            }
        }
    }

    return metadata
}
