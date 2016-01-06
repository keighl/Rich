//
//  Document.swift
//  Rich
//
//  Created by Kyle Truscott on 1/5/16.
//  Copyright © 2016 seasalt. All rights reserved.
//

import Cocoa

enum TextDecoration: Int {
    case Bold
    case Italic
    case Underline
}

class Document: NSDocument {
    
    @IBOutlet var textView: NSTextView?
    @IBOutlet var textColorWell: NSColorWell?
    @IBOutlet var fontFamilyName: NSPopUpButton?
    @IBOutlet var fontMember: NSPopUpButton?
    @IBOutlet var fontSizeStepper: NSStepper?
    @IBOutlet var fontSizeField: NSTextField?
    @IBOutlet var textAlignmentSegment: NSSegmentedControl?
    @IBOutlet var textDecorationSegment: NSSegmentedControl?
    
    dynamic var contentString = NSAttributedString(string: "")
    
    // List of all font family names on the system
    dynamic let fontFamilyNames = NSFontManager.sharedFontManager().availableFontFamilies

    // Labels for the members menu (e.g. Bold, Oblique) in the current font family
    // assigned inside textViewDidChangeTypingAttributes
    dynamic var fontMemberLabels: [String] = []
    // Postscript font names for members in the current font family
    // These values are needed to actually construct NSFont objects
    // assigned inside textViewDidChangeTypingAttributes
    dynamic var fontMemberNames: [String] = []
    
    // Attributes for the textview extracted from the actual typingAttributes
    // textView.typingAttributes info can't be bound directly since sometimes it's missing.
    // Looking at you, NSParagraphStyleAttributeName...
    dynamic var currentFontFamilyName: String? = ""
    dynamic var currentFontMemberLabel: String? = ""
    dynamic var currentFontSize: CGFloat = 0
    dynamic var currentTextColor = NSColor.blackColor()
    dynamic var currentTextAlignment = NSTextAlignment.Left
    
    // Multiple selection in NSSegmentControl is easier to manage using didSet
    // as opppised to binding
    dynamic var currentTextIsBold = false {
        didSet {
            self.textDecorationSegment?.setSelected(currentTextIsBold, forSegment: TextDecoration.Bold.rawValue)
        }
    }
    dynamic var currentTextIsItalic = false {
        didSet {
            self.textDecorationSegment?.setSelected(currentTextIsItalic, forSegment: TextDecoration.Italic.rawValue)
        }
    }
    dynamic var currentTextIsUnderline = false {
        didSet {
            self.textDecorationSegment?.setSelected(currentTextIsUnderline, forSegment: TextDecoration.Underline.rawValue)
        }
    }

    override func windowControllerDidLoadNib(aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
        
        // Add a little padding to the text view
        textView!.textContainerInset = CGSize(width: 20, height: 20)
        
        let opts: [String: AnyObject] = [
            // For instances when the font-family or member don't exist on the system
            NSNullPlaceholderBindingOption: "----",
        ]
        
        // I like doing bindings here instead of IB, since it's easier to see
        
        // text view
        textView!.bind("attributedString", toObject: self, withKeyPath: "contentString", options: nil)
    
        // color well
        textColorWell!.bind("value", toObject: self, withKeyPath: "currentTextColor", options: nil)
        
        // font family
        fontFamilyName!.bind("content", toObject: self, withKeyPath: "fontFamilyNames", options: opts)
        fontFamilyName!.bind("selectedValue", toObject: self, withKeyPath: "currentFontFamilyName", options: nil)

        // font member
        fontMember!.bind("content", toObject: self, withKeyPath: "fontMemberLabels", options: opts)
        fontMember!.bind("selectedValue", toObject: self, withKeyPath: "currentFontMemberLabel", options: nil)
        
        // size
        fontSizeField!.bind("value", toObject: self, withKeyPath: "currentFontSize", options: opts)
        fontSizeStepper!.bind("value", toObject: self, withKeyPath: "currentFontSize", options: nil)
        
        // alignment
        textAlignmentSegment!.bind("selectedTag", toObject: self, withKeyPath: "currentTextAlignment", options: nil)
    }

    override class func autosavesInPlace() -> Bool {
        return true
    }

    override var windowNibName: String? {
        return "Document"
    }
    
    // MARK: Read/Write methods
    
    override func dataOfType(typeName: String) throws -> NSData {
        let range = NSRange(location: 0, length: contentString.length)
        do {
            return try contentString.dataFromRange(range, documentAttributes: [NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType])
        } catch {
            throw error
        }
    }

    override func readFromData(data: NSData, ofType typeName: String) throws {
        contentString = NSAttributedString(RTF: data, documentAttributes: nil)!
    }
    
    @IBAction func fontFamilyChanged(sender: NSPopUpButton) {
        let newIDX = fontFamilyName!.indexOfSelectedItem
        if let currentFont = textView?.typingAttributes[NSFontAttributeName] as? NSFont {
            let newFont = NSFontManager.sharedFontManager().convertFont(currentFont, toFamily: fontFamilyNames[newIDX])
            applyNewAttributes([NSFontAttributeName: newFont])
        } else {
            // no current font
        }
    }
    
    // MARK: Font management
    
    @IBAction func fontMemberChanged(sender: NSPopUpButton) {
        let newIDX = fontMember!.indexOfSelectedItem
        if let currentFont = textView?.typingAttributes[NSFontAttributeName] as? NSFont {
            let newMemberName = fontMemberNames[newIDX]
            
            if let newFont = NSFontManager.sharedFontManager().convertFont(currentFont, toFace: newMemberName) {
                applyNewAttributes([NSFontAttributeName: newFont])
            } else {
                // TODO
            }
        } else {
            // TODO
        }
    }
    
    @IBAction func fontSizeChanged(sender: NSControl) {
        var newSize = CGFloat(sender.floatValue)
        // No negative sizes fonts, pleez
        if newSize < 0.0 {
            newSize *= -1.0
        }
        
        if let currentFont = textView?.typingAttributes[NSFontAttributeName] as? NSFont {
            let newFont = NSFontManager.sharedFontManager().convertFont(currentFont, toSize: newSize)
            applyNewAttributes([NSFontAttributeName: newFont])
        } else {
            // TODO
        }
    }
    
    // MARK: Alignment management
    
    @IBAction func paragraphAlignmentChanged(sender: NSSegmentedControl) {
        
        // A fun cocktail of swift casting goofiness
        // Alignment value is stored in cell tag
        var alignment = NSTextAlignment.Left
        let selectedTag = (sender.cell as! NSSegmentedCell).tagForSegment(sender.selectedSegment)
        if let a = NSTextAlignment(rawValue: UInt(bitPattern: selectedTag)) {
            alignment = a
        }
        
        if let changeRanges = textView?.rangesForUserParagraphAttributeChange {
            // Important to wrap batch changes to textStorage in shouldChangeTextInRanges/beginEditing ... endEditing/didChangeText
            textView?.shouldChangeTextInRanges(changeRanges, replacementStrings: nil)
            textView?.textStorage?.beginEditing()
            // Loop over the range values, and apply new paragraph style for each
            for (_, value) in changeRanges.enumerate() {
                
                // Watch out for ranges like (558,0) when the cursor is at the end of the string
                if value.rangeValue.length == 0 {
                    continue
                }
                
                // Build a default paragraph style
                var paragraphStyle = NSMutableParagraphStyle()
                
                // Attempt to pull a current paragraph style for the range
                if let existingPStyle = textView?.textStorage?.attribute(NSParagraphStyleAttributeName, atIndex: value.rangeValue.location, longestEffectiveRange: nil, inRange: value.rangeValue)?.mutableCopy() as? NSMutableParagraphStyle {
                    paragraphStyle = existingPStyle
                }
                
                // Assign the alignment, and add it
                paragraphStyle.alignment = alignment
                textView?.textStorage?.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: value.rangeValue)
            }
            textView?.textStorage?.endEditing()
            textView?.didChangeText()
            
            // Apply the new alignment to the typing attributes
            if var typingAttributes = textView?.typingAttributes {
                var paragraphStyle = NSMutableParagraphStyle()
                if let existingPStyle = typingAttributes[NSParagraphStyleAttributeName] as? NSParagraphStyle {
                    paragraphStyle = existingPStyle.mutableCopy() as! NSMutableParagraphStyle
                }
                paragraphStyle.alignment = alignment
                typingAttributes[NSParagraphStyleAttributeName] = paragraphStyle
                textView?.typingAttributes = typingAttributes
            }
        }
    }
    
    // MARK: Decoration management
    
    @IBAction func decorationChanged(sender: NSSegmentedControl) {
        // `selectedSegment` is the last segment the user interacted with
        // regardless of whether it was enabled/disable... confusing!
        
        var decoration = TextDecoration.Underline
        if let d = TextDecoration(rawValue: sender.selectedSegment) {
            decoration = d
        }
        
        let enabled = sender.isSelectedForSegment(sender.selectedSegment)

        // Grab the typing font
        if var font = textView?.typingAttributes[NSFontAttributeName] as? NSFont {
            if decoration == .Bold {
                if enabled {
                    font = NSFontManager.sharedFontManager().convertFont(font, toHaveTrait: .BoldFontMask)
                } else {
                    font = NSFontManager.sharedFontManager().convertFont(font, toNotHaveTrait: .BoldFontMask)
                }
                applyNewAttributes([NSFontAttributeName: font])
            }
            
            if decoration == .Italic {
                if enabled {
                    font = NSFontManager.sharedFontManager().convertFont(font, toHaveTrait: .ItalicFontMask)
                } else {
                    font = NSFontManager.sharedFontManager().convertFont(font, toNotHaveTrait: .ItalicFontMask)
                }
                applyNewAttributes([NSFontAttributeName: font])
            }
            
            if decoration == .Underline {
                if enabled {
                    applyNewAttributes([NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue])
                } else {
                    applyNewAttributes([NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleNone.rawValue])
                }
            }
            
        } else {
            // TODO
        }
    }
    
    // Takes new attributes and applies it to rangesForUserCharacterAttributeChange, and updates typing attributes
    func applyNewAttributes(attributes: [String: AnyObject]) {
        if let changeRanges = textView?.rangesForUserCharacterAttributeChange {
            
            // Important to wrap batch changes to textStorage in shouldChangeTextInRanges/beginEditing ... endEditing/didChangeText
            textView?.shouldChangeTextInRanges(changeRanges, replacementStrings: nil)
            textView?.textStorage?.beginEditing()
            // Loop over the range values and add the new font as an attribute
            for (_, value) in changeRanges.enumerate() {
                textView?.textStorage?.addAttributes(attributes, range: value.rangeValue)
            }
            textView?.textStorage?.endEditing()
            textView?.didChangeText()
        }
        
        // Apply the new font to the typing attributes
        if var typingAttributes = textView?.typingAttributes {
            typingAttributes.updateWithDictionary(attributes)
            textView?.typingAttributes = typingAttributes
        }
    }
}

extension Document: NSTextViewDelegate {
    
    func textViewDidChangeTypingAttributes(notification: NSNotification) {

        // Sniff the typing color
        if let color = textView?.typingAttributes[NSForegroundColorAttributeName] as? NSColor {
            currentTextColor = color
        } else {
            currentTextColor = NSColor.blackColor()
        }
        
        // Sniff the typing alignment
        if let pStyle = textView?.typingAttributes[NSParagraphStyleAttributeName] as? NSParagraphStyle {
            currentTextAlignment = pStyle.alignment
        } else {
            currentTextAlignment = .Left
        }
        
        // Sniff the typing underline style
        if let underlineStyle = textView?.typingAttributes[NSUnderlineStyleAttributeName] as? Int {
            debugPrint("currentTextIsUnderline", underlineStyle, NSUnderlineStyle.StyleSingle.rawValue)
            currentTextIsUnderline = (underlineStyle == NSUnderlineStyle.StyleSingle.rawValue)
        } else {
            currentTextIsUnderline = false
        }
        
        if let font = textView?.typingAttributes[NSFontAttributeName] as? NSFont {
            currentFontFamilyName = font.familyName
            currentFontSize = font.pointSize
            currentTextIsBold = NSFontManager.sharedFontManager().fontNamed(font.fontName, hasTraits: .BoldFontMask)
            currentTextIsItalic = NSFontManager.sharedFontManager().fontNamed(font.fontName, hasTraits: .ItalicFontMask)
            if currentFontFamilyName == nil {
                return
            }
            if let members = NSFontManager.sharedFontManager().availableMembersOfFontFamily(currentFontFamilyName!) {
                // e.g [[Helvetica, Regular, 5, 0], [Helvetica-Light, Light, 3, 0], [Helvetica-Oblique, Oblique, 5, 1], [Helvetica-LightOblique, Light Oblique, 3, 1], [Helvetica-Bold, Bold, 9, 2], [Helvetica-BoldOblique, Bold Oblique, 9, 3]]
                // https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSFontManager_Class/#//apple_ref/occ/instm/NSFontManager/availableMembersOfFontFamily:
                fontMemberNames = members.map({member in (member[0] as! String)})
                fontMemberLabels = members.map({member in (member[1] as! String)})
                if let matchedMember = members.filter({ member in
                    if let memberFontName = member[0] as? String {
                        return memberFontName == font.fontName
                    }
                    return false
                }).first {
                    currentFontMemberLabel = matchedMember[1] as? String
                } else {
                    // TODO handle missing font
                }
                
            } else {
                // TODO handle missing font
            }
        } else {
            currentTextIsBold = false
            currentTextIsItalic = false
            // TODO handle missing font
        }
    }
}

extension Dictionary {
    mutating func updateWithDictionary(dictionary: Dictionary) {
        for (key, value) in dictionary {
            self.updateValue(value, forKey:key)
        }
    }
}
