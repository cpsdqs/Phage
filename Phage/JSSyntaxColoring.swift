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
    var textFont: NSFont
    var boldFont: NSFont
    var italicFont: NSFont
    var boldItalicFont: NSFont

    init(fragaria: MGSFragariaView) {
        self.fragaria = fragaria

        textFont = NSFont(name: "Inconsolata LGC", size: 12.0)
            ?? NSFont(name: "Menlo", size: 12.0)!
        self.fragaria.textFont = textFont

        let family = textFont.familyName!
        let size = textFont.pointSize
        boldFont = NSFontManager.shared.font(withFamily: family, traits: .boldFontMask, weight: 700, size: size)!
        italicFont = NSFontManager.shared.font(withFamily: family, traits: .italicFontMask, weight: 400, size: size)!
        boldItalicFont = NSFontManager.shared.font(withFamily: family, traits: [.boldFontMask, .italicFontMask], weight: 700, size: size)!
    }

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

    var lazyHighlightingQueue: [HLStyleItem] = []
    var lazyHighlighter: Timer?
    var wasDarkMode = false
    var setBackgroundColor = false

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

        lazyHighlightingQueue = lazyHighlightingQueue.filter { (item) -> Bool in
            return newRange.intersection(item.charRange) == nil
        }

        oldRange.length -= changeInLength
        inspectedCharacterIndexes.shiftIndexesStarting(at: oldRange.upperBound, by: changeInLength)
        newRange = (textStorage.string as NSString).lineRange(for: newRange)
        inspectedCharacterIndexes.remove(in: newRange)
    }

    func visibleRange() -> NSRange {
        let textView = fragaria.textView
        let visibleRect = textView.enclosingScrollView!.contentView.documentVisibleRect
        return textView.layoutManager!.glyphRange(forBoundingRect: visibleRect, in: textView.textContainer!)
    }

    func startLazyHighlightingIfNeeded() {
        if lazyHighlighter?.isValid ?? false {
            return
        }

        lazyHighlighter = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true, block: { (timer) in
            if self.lazyHighlightingQueue.isEmpty {
                timer.invalidate()
            }

            for _ in 0..<100 {
                if let item = self.lazyHighlightingQueue.first {
                    self.lazyHighlightingQueue.remove(at: 0)
                    self.applyStyleItem(item)
                } else {
                    break
                }
            }
        })
    }

    func applyStyleItem(_ item: HLStyleItem) {
        let range = item.charRange
        switch ((item.bold, item.italic)) {
        case (true, true):
            layoutManager.addTemporaryAttribute(.font, value: boldItalicFont, forCharacterRange: range)
        case (true, false):
            layoutManager.addTemporaryAttribute(.font, value: boldFont, forCharacterRange: range)
        case (false, true):
            layoutManager.addTemporaryAttribute(.font, value: italicFont, forCharacterRange: range)
        case (false, false):
            break
        }

        layoutManager.addTemporaryAttribute(.foregroundColor, value: item.foreground, forCharacterRange: range)

        if item.underline {
            layoutManager.addTemporaryAttribute(.underlineStyle, value: NSUnderlineStyle.single, forCharacterRange: range)
        }
    }

    func appearanceSeemsDark() -> Bool {
        let bgColor = NSColor.textBackgroundColor.usingColorSpace(NSColorSpace.deviceRGB)!
        let luminance = bgColor.redComponent * 0.21 + bgColor.greenComponent * 0.72 + bgColor.blueComponent * 0.07
        return luminance < 0.5
    }

    /// Recolors the invalid characters in the specified range.
    ///
    /// - Parameter range: A character range where, when this method returns
    ///                    all syntax colouring will be guaranteed to be
    ///                    up-to-date.
    func recolour(_ range: NSRange) {
        let seemsDark = appearanceSeemsDark()
        var darkModeChanged = false
        if seemsDark != wasDarkMode {
            highlighter.setDarkMode(seemsDark)
            wasDarkMode = seemsDark
            invalidateAllColouring()
            darkModeChanged = true
        }

        if !setBackgroundColor || darkModeChanged {
            fragaria.backgroundColor = highlighter.backgroundColor()
            fragaria.gutterBackgroundColour = fragaria.backgroundColor
            setBackgroundColor = true
        }

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
        inspectedCharacterIndexes.remove(in: visibleRange())
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
        lazyHighlightingQueue = []
        lazyHighlighter?.invalidate()

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

        let requiredRange = visibleRange()

        for item in styleItems {
            let offset = lineIndices[Int(item.line)].encodedOffset
            item.charRange = NSMakeRange(offset + item.range.location, offset + item.range.length)

            if requiredRange.intersection(item.charRange) == nil {
                lazyHighlightingQueue.append(item)
                continue
            }

            applyStyleItem(item)
        }

        startLazyHighlightingIfNeeded()

        return effectiveNSRange
    }

}
