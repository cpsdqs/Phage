//
//  JSSyntaxColoring.swift
//  Phage
//
//  Created by cpsdqs on 2018-08-19.
//  Copyright © 2018 cpsdqs. All rights reserved.
//

import Cocoa
import Fragaria

class JSSyntaxColoring: NSObject, SMLSyntaxColouringProtocol {

    weak var fragaria: MGSFragariaView!
    weak var _layoutManager: NSLayoutManager!
    weak var layoutManager: NSLayoutManager! {
        get {
            return _layoutManager
        }
        set(val) {
            layoutManagerWillChangeTextStorage()
            _layoutManager = val
            layoutManagerDidChangeTextStorage()
        }
    }
    var syntaxDefinitionName: String!
    var syntaxDefinition: MGSSyntaxDefinition!
    var syntaxColouringDelegate: SMLSyntaxColouringDelegate!
    var inspectedCharacterIndexes: NSMutableIndexSet = NSMutableIndexSet()
    var highlighter: Highlighter = Highlighter(folder: Bundle.main.path(forResource: "syntaxes", ofType: "")!)
    var textFont: NSFont = NSFont(name: "Menlo", size: 11.0)!

    // MARK: - Properties - Appearance and Behavior

    var colourForAttributes: NSColor!
    var colourForAutocomplete: NSColor!
    var colourForCommands: NSColor!
    var colourForComments: NSColor!
    var colourForInstructions: NSColor!
    var colourForKeywords: NSColor!
    var colourForNumbers: NSColor!
    var colourForStrings: NSColor!
    var colourForVariables: NSColor!
    var coloursAttributes: Bool = true
    var coloursAutocomplete: Bool = true
    var coloursCommands: Bool = true
    var coloursComments: Bool = true
    var coloursInstructions: Bool = true
    var coloursKeywords: Bool = true
    var coloursNumbers: Bool = true
    var coloursStrings: Bool = true
    var coloursVariables: Bool = true
    var coloursMultiLineStrings: Bool = true
    var coloursOnlyUntilEndOfLine: Bool = true

    // MARK: - Instance Methods

    /// Inform this syntax colourer that its layout manager's text storage
    /// will change.
    ///
    /// In response to this message, the syntax colourer view must remove
    /// itself as observer of any notifications from the old text storage.
    func layoutManagerWillChangeTextStorage() {
        if layoutManager != nil {
            NotificationCenter.default.removeObserver(self, name: NSTextStorage.didProcessEditingNotification, object: layoutManager.textStorage)
        }
    }

    /// Inform this syntax colourer that its layout manager's text storage
    /// has changed.
    ///
    /// In this method the syntax colourer can register as of any of the new
    /// text storage's notifications.
    func layoutManagerDidChangeTextStorage() {
        NotificationCenter.default.addObserver(self, selector: #selector(textStorageProcessedEditing(_:)), name: NSTextStorage.didProcessEditingNotification, object: layoutManager.textStorage)
    }

    @objc func textStorageProcessedEditing(_ notification: Notification) {
        let textStorage = notification.object as! NSTextStorage
        var newRange = textStorage.editedRange
        var oldRange = newRange
        let changeInLength = textStorage.changeInLength

        oldRange.length -= changeInLength
        inspectedCharacterIndexes.shiftIndexesStarting(at: oldRange.upperBound, by: changeInLength)
        newRange = (textStorage.string as NSString).lineRange(for: newRange)
        inspectedCharacterIndexes.remove(in: newRange)
    }

    /// Recolors the invalid characters in the specified range.
    ///
    /// - Parameter range: A character range where, when this method returns
    ///                    all syntax colouring will be guaranteed to be
    ///                    up-to-date.
    func recolour(_ range: NSRange) {
        let invalidRanges = NSMutableIndexSet(indexesIn: range)
        invalidRanges.remove(inspectedCharacterIndexes as IndexSet)
        invalidRanges.enumerateRanges { (range, stop) in
            if !inspectedCharacterIndexes.contains(in: range) {
                let nowValid = recolourChangedRange(range)
                inspectedCharacterIndexes.add(in: nowValid)
            }
        }
    }

    /// Marks as invalid the colouring in the range currently visible (not
    /// clipped) in the specified text view.
    ///
    /// - Parameter textView: The text view from which to get a character range.
    func invalidateVisibleRange(of textView: SMLTextView!) {
        let visibleRect = textView.enclosingScrollView!.contentView.documentVisibleRect
        let visibleRange = textView.layoutManager!.glyphRange(forBoundingRect: visibleRect, in: textView.textContainer!)
        inspectedCharacterIndexes.remove(in: visibleRange)
    }

    func clearAttributes(in range: NSRange) {
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: range)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
        layoutManager.removeTemporaryAttribute(.font, forCharacterRange: range)
        layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: range)
    }

    /// Marks the entire text's colouring as invalid and removes all coloring
    /// attributes applied.
    func invalidateAllColouring() {
        highlighter.invalidateCache()

        let docString = layoutManager.textStorage!.string
        clearAttributes(in: NSMakeRange(0, docString.count))
        inspectedCharacterIndexes.removeAllIndexes()
    }

    /// Forces a recolouring of the character range specified. The recolouring
    /// will be done anew even if the specified range is already valid (wholly
    /// or in part).
    ///
    /// - Parameter rangeToRecolour: Indicates the range to be recoloured.
    /// - Returns: The range that was effectively coloured. The returned range
    ///            always contains entirely the initial range.
    func recolourChangedRange(_ rangeToRecolour: NSRange) -> NSRange {
        let docString = layoutManager.textStorage!.string
        var startLine = -1
        var endLine = -1
        // var lines = [String]()
        var lineIndices = [String.Index]()

        var accumIndex = docString.startIndex
        while let range = docString[accumIndex...].rangeOfCharacter(from: .newlines) {
            // if accumIndex != range.lowerBound {
                if accumIndex.encodedOffset <= rangeToRecolour.lowerBound && rangeToRecolour.lowerBound < range.upperBound.encodedOffset {
                    startLine = lineIndices.count
                }
                if accumIndex.encodedOffset <= rangeToRecolour.upperBound && rangeToRecolour.upperBound < range.upperBound.encodedOffset {
                    endLine = lineIndices.count + 1
                }

                // lines.append(String(docString[accumIndex..<range.lowerBound]))
                lineIndices.append(accumIndex)
            // }
            accumIndex = range.upperBound
        }
        if accumIndex != docString.endIndex {
            // lines.append(String(docString[accumIndex...]))
            if accumIndex.encodedOffset <= rangeToRecolour.lowerBound {
                startLine = lineIndices.count
            }
            if accumIndex.encodedOffset <= rangeToRecolour.upperBound {
                endLine = lineIndices.count + 1
            }

            lineIndices.append(accumIndex)
        }

        if startLine == -1 {
            startLine = lineIndices.count - 1
        }
        if endLine == -1 {
            endLine = lineIndices.count + 1
        }

        let styleItems = highlighter.highlight(docString,
                                          atLine: UInt(startLine),
                                          lineCount: UInt(endLine - startLine),
                                          totalLines: UInt(lineIndices.count))

        if styleItems.isEmpty {
            return rangeToRecolour
        }

        let effectiveRange = lineIndices[Int(styleItems.first!.line)]..<lineIndices[Int(styleItems.last!.line)]
        let effectiveNSRange = NSRange(effectiveRange, in: docString)

        clearAttributes(in: effectiveNSRange)

        for item in styleItems {
            let offset = lineIndices[Int(item.line)].encodedOffset
            let range = NSMakeRange(offset + item.range.location, offset + item.range.length)

            let font = NSFont(descriptor: textFont.fontDescriptor.addingAttributes([
                .traits: [
                    NSFontDescriptor.TraitKey.weight: item.bold ? 0.5 : 0.0,
                    NSFontDescriptor.TraitKey.slant: item.italic ? 0.5 : 0.0
                ]
            ]), size: textFont.pointSize)!

            layoutManager.addTemporaryAttributes([
                .foregroundColor: item.foreground,
                // .backgroundColor: item.background,
                .font: font,
                // .underlineStyle: item.underline ? NSUnderlineStyle.single : NSUnderlineStyle.init(rawValue: 0)
            ], forCharacterRange: range)
        }

        return effectiveNSRange
    }

}
