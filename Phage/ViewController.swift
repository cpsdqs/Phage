//
//  ViewController.swift
//  Phage
//
//  Created by cpsd on 2018-07-20.
//  Copyright © 2018 cpsdqs. All rights reserved.
//

import Cocoa
import Fragaria

class ViewController: NSViewController, NSOutlineViewDelegate, MGSFragariaTextViewDelegate, MGSDragOperationDelegate {

    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var editorView: MGSFragariaView!
    @IBOutlet weak var saveButton: NSButton!
    @IBOutlet weak var enabledButton: NSButton!
    @IBOutlet weak var asScriptButton: NSButton!
    @IBOutlet weak var createNewScriptButton: NSButton!
    var scripts: DataStorage!
    var selectedScript: String?

    override func viewDidLoad() {
        super.viewDidLoad()

//        textView.font = NSFont(name: "Menlo", size: 12.0)
//        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
//        textView.isHorizontallyResizable = true
//        textView.textContainer!.widthTracksTextView = false
//        textView.textContainer!.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
//        textView.delegate = self

        editorView.syntaxDefinitionName = "javascript"
        editorView.backgroundColor = NSColor.textBackgroundColor
        editorView.gutterBackgroundColour = NSColor.underPageBackgroundColor
        editorView.gutterTextColour = NSColor.secondaryLabelColor
        editorView.currentLineHighlightColour = NSColor.textBackgroundColor
        editorView.textInvisibleCharactersColour = NSColor.quaternaryLabelColor
        editorView.defaultSyntaxErrorHighlightingColour = NSColor.systemRed
        editorView.isSyntaxColoured = true
        editorView.showsLineNumbers = true
        editorView.autoCompleteEnabled = true
        editorView.lineWrap = false
        editorView.indentWidth = 2
        editorView.indentWithSpaces = true
        editorView.showsInvisibleCharacters = true
        editorView.insertClosingBraceAutomatically = true
        editorView.insertClosingParenthesisAutomatically = true
        editorView.tabWidth = Int(editorView.indentWidth)
        editorView.addSubstitute("¬", forInvisibleCharacter: 0xA)
        let syntaxColoring = JSSyntaxColoring(fragaria: editorView)
        editorView.syntaxColouring = syntaxColoring
        editorView.gutterFont = syntaxColoring.textFont
        editorView.textViewDelegate = self

        setEditorVisible(false)

        var jsonData: Data
        do {
            jsonData = try Data(contentsOf: storageURL)
        } catch _ {
            NSLog("Failed to read data, assuming it doesn’t exist")
            jsonData = "{\"scripts\":{}}".data(using: .utf8)!
        }

        do {
            scripts = try DataStorage(json: jsonData)
        } catch _ {
            fatalError("Failed to decode JSON data")
        }

        outlineView.dataSource = scripts
        outlineView.delegate = self

        enabledButton.isHidden = true
        asScriptButton.isHidden = true
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    func writeDataToFile() {
        do {
            try self.scripts.toJSON().write(to: storageURL, options: .atomic)
        } catch _ {
            fatalError("Failed to encode and write data as JSON")
        }
    }

    func setDirty(_ dirty: Bool) {
        saveButton.title = dirty ? "Save*" : "Save"
        view.window?.isDocumentEdited = dirty
    }

    @IBAction func newScript(_ sender: Any) {
        let id = UUID().uuidString
        scripts.scriptList.scripts[id] = ScriptData(script: scriptTemplate, enabled: true)
        outlineView.reloadData()
        let row = scripts.scriptList.orderedKeys.index(of: id)!
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        editorView.window?.makeFirstResponder(editorView)
    }

    @IBAction func savePressed(_ sender: Any) {
        if let selectedScript = selectedScript {
            let script = scripts.scriptList.scripts[selectedScript]!
            script.script = editorView.string as String
            script.updateMetadata()
            outlineView.reloadItem(selectedScript)
        }
        writeDataToFile()
        setDirty(false)
    }

    @IBAction func deletePressed(_ sender: Any) {
        if let selected = selectedScript {
            let script = scripts.scriptList.scripts[selected]!
            let alert = NSAlert()
            alert.messageText = "Delete “\(script.metadata.name)” forever?"
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "OK")
            if alert.runModal() != .alertFirstButtonReturn {
                scripts.scriptList.scripts.removeValue(forKey: selected)
                outlineView.deselectAll(nil)
                outlineView.reloadData()
            }
            setDirty(true)
        }
    }

    @IBAction func enabledStateChanged(_ sender: Any) {
        if let selectedScript = selectedScript {
            let script = scripts.scriptList.scripts[selectedScript]!
            script.enabled = enabledButton.state == .on
            outlineView.reloadItem(selectedScript)
            setDirty(true)
        }
    }

    @IBAction func asScriptStateChanged(_ sender: Any) {
        if let selectedScript = selectedScript {
            let script = scripts.scriptList.scripts[selectedScript]!
            script.injectAsScriptTag = asScriptButton.state == .on
            setDirty(true)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "DataCell"), owner: self)!
        let checkMark = view.subviews[0] as! NSImageView
        let textField = view.subviews[1] as! NSTextField

        if let item = item as? String {
            let value = scripts.scriptList.scripts[item]!
            textField.stringValue = value.metadata.name
            checkMark.isHidden = !value.enabled
        } else {
            textField.stringValue = "???"
            checkMark.isHidden = true
            debugPrint(item)
        }
        return view
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        if outlineView.selectedRow >= 0 {
            selectedScript = scripts.scriptList.orderedKeys[outlineView.selectedRow]
        } else {
            selectedScript = nil
        }
        updateContentView()
    }

    func setEditorVisible(_ visible: Bool) {
        // editorView.isHidden = !visible // breaks layout
        editorView.showsGutter = visible // hide gutter instead
        createNewScriptButton.isHidden = visible
    }

    func updateContentView() {
        if let selectedScript = selectedScript {
            let scriptData = scripts.scriptList.scripts[selectedScript]!
            editorView.string = scriptData.script as NSString
            // TODO: investigate why it doesn’t invalidate automatically
            editorView.syntaxColouring?.invalidateAllColouring()
            setEditorVisible(true)
            enabledButton.state = scriptData.enabled ? .on : .off
            asScriptButton.state = scriptData.injectAsScriptTag ? .on : .off
        } else {
            editorView.string = ""
            setEditorVisible(false)
        }
        asScriptButton.isHidden = enabledButton.isHidden
    }

    func textDidChange(_ notification: Notification) {
        setDirty(true)
    }

    func textShouldBeginEditing(_ textObject: NSText) -> Bool {
        return selectedScript != nil
    }

}
