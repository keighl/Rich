//
//  Document.swift
//  Rich
//
//  Created by Kyle Truscott on 1/5/16.
//  Copyright © 2016 seasalt. All rights reserved.
//

import Cocoa

class Document: NSDocument {
    
    var contentString = NSAttributedString(string: "")
    @IBOutlet var textView: RichTextView?
    @IBOutlet var textColorWell: NSColorWell?
    @IBOutlet var fontFamilyName: NSPopUpButton?
    @IBOutlet var fontMemberName: NSPopUpButton?
    
    let fontFamilyNames = NSFontManager.sharedFontManager().availableFontFamilies
    
    override init() {
        super.init()
    }

    override func windowControllerDidLoadNib(aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
      
        textColorWell?.bind("value", toObject: textView!, withKeyPath: "typingAttributes.\(NSForegroundColorAttributeName)", options: nil)
        
        fontFamilyName?.bind("content", toObject: self, withKeyPath: "fontFamilyNames", options: nil)
        fontFamilyName?.bind("selectedValue", toObject: textView!, withKeyPath: "fontFamilyName", options: nil)

        fontMemberName?.bind("content", toObject: textView!, withKeyPath: "fontMemberNames", options: nil)
        fontMemberName?.bind("selectedValue", toObject: textView!, withKeyPath: "fontMemberName", options: nil)
    }

    override class func autosavesInPlace() -> Bool {
        return true
    }

    override var windowNibName: String? {
        return "Document"
    }

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
}

extension Document: NSTextViewDelegate {
    
}

class RichTextView: NSTextView {
    
    dynamic var fontFamilyName: String? = ""
    dynamic var fontMemberName: String? = ""
    dynamic var fontMemberNames: [String]? = []
    
    override func didChangeValueForKey(key: String) {

        super.didChangeValueForKey(key)
        if key == "typingAttributes" {
            if let font = typingAttributes[NSFontAttributeName] as? NSFont {
                fontFamilyName = font.familyName
                if let members = NSFontManager.sharedFontManager().availableMembersOfFontFamily(fontFamilyName!) {
                    // e.g [[Helvetica, Regular, 5, 0], [Helvetica-Light, Light, 3, 0], [Helvetica-Oblique, Oblique, 5, 1], [Helvetica-LightOblique, Light Oblique, 3, 1], [Helvetica-Bold, Bold, 9, 2], [Helvetica-BoldOblique, Bold Oblique, 9, 3]]
                    // https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSFontManager_Class/#//apple_ref/occ/instm/NSFontManager/availableMembersOfFontFamily:
                    fontMemberNames = members.map({member in (member[1] as! String)})
                    
                    if let matchedMember = members.filter({ member in
                        if let memberFontName = member[0] as? String {
                            return memberFontName == font.fontName
                        }
                        return false
                    }).first {
                        fontMemberName = matchedMember[1] as? String
                    } else {
                        // TODO handle missing font
                    }
                    
                } else {
                    // TODO handle missing font
                }
                
            } else {
                // TODO handle missing font
            }
        }
    }
}