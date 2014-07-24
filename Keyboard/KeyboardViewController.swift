//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Alexei Baboulevitch on 6/9/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

import UIKit

let layout: [String:Double] = [
    "leftGap": 3,
    "rightGap": 3,
    "topGap": 9,
    "bottomGap": 7,
    "keyWidth": 26,
    "keyHeight": 39,
    "popupKeyHeight": 53,
    "keyGap": 6, // 5 for russian, though still 6 on lower row
    "shiftAndBackspaceMaxWidth": 36,
    "specialKeyWidth": 34,
    "doneKeyWidth": 50,
    "spaceWidth": 138,
    "debugWidth": 2
]

let colors: [String:UIColor] = [
    "lightColor": UIColor.whiteColor(),
    "lightShadowColor": UIColor(hue: (220/360.0), saturation: 0.04, brightness: 0.56, alpha: 1),
    "lightTextColor": UIColor.blackColor(),
    "darkColor": UIColor(hue: (217/360.0), saturation: 0.09, brightness: 0.75, alpha: 1),
    "darkShadowColor": UIColor(hue: (220/360.0), saturation: 0.04, brightness: 0.56, alpha: 1),
    "darkTextColor": UIColor.whiteColor(),
    "blueColor": UIColor(hue: (211/360.0), saturation: 1.0, brightness: 1.0, alpha: 1),
    "blueShadowColor": UIColor(hue: (216/360.0), saturation: 0.05, brightness: 0.43, alpha: 1),
    "borderColor": UIColor(hue: (214/360.0), saturation: 0.04, brightness: 0.65, alpha: 1.0)
]

// shift/backspace: 72x78, but shrinks to 48x78
// lower row: 68x78, 100x78, 276

class KeyboardViewController: UIInputViewController {
    
    var elements: Dictionary<String, UIView>
    var keyboard: Keyboard
    var keyViewToKey: Dictionary<KeyboardKey, Key>
    var forwardingView: ForwardingView!

    init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        self.elements = Dictionary<String, UIView>()
        self.keyboard = defaultKeyboard()
        self.keyViewToKey = Dictionary<KeyboardKey, Key>()
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.forwardingView = ForwardingView(frame: self.view.bounds)
        self.view.addSubview(self.forwardingView)
        
        self.elements["superview"] = self.view
        createViews(keyboard)
        
        addEdgeConstraints()
        
        // TODO: autolayout class that can optionally "bake" values?
        createRowGapConstraints(keyboard)
        createKeyGapConstraints(keyboard)
        createKeyConstraints(keyboard)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.forwardingView.frame = self.view.bounds
    }
    
    func takeScreenshotDelay() {
        var timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: Selector("takeScreenshot"), userInfo: nil, repeats: false)
    }
    
    func takeScreenshot() {
        if !CGRectIsEmpty(self.view.bounds) {
            let oldViewColor = self.view.layer.backgroundColor
            self.view.layer.backgroundColor = UIColor(hue: (216/360.0), saturation: 0.05, brightness: 0.86, alpha: 1).CGColor
            
            var rect = self.view.bounds
            UIGraphicsBeginImageContextWithOptions(rect.size, true, 0)
            var context = UIGraphicsGetCurrentContext()
            self.view.layer.renderInContext(context)
            var capturedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            var imagePath = "/Users/archagon/Documents/Programming/OSX/TransliteratingKeyboard/Screenshot.png"
            UIImagePNGRepresentation(capturedImage).writeToFile(imagePath, atomically: true)
            
            self.view.layer.backgroundColor = oldViewColor
        }
    }
    
    func addEdgeConstraints() {
        let spacers = [
            "leftSpacer": Spacer(color: UIColor.redColor()),
            "rightSpacer": Spacer(color: UIColor.redColor()),
            "topSpacer": Spacer(color: UIColor.redColor()),
            "bottomSpacer": Spacer(color: UIColor.redColor())]
        
        // basic setup
        for (name, spacer) in spacers {
            spacer.setTranslatesAutoresizingMaskIntoConstraints(false)
            self.elements[name] = spacer
            self.forwardingView.addSubview(spacer)
        }
        
        let constraints = [
            // left/right spacers
            "|[leftSpacer(leftGap)]",
            "[rightSpacer(rightGap)]|",
            "V:[leftSpacer(debugWidth)]",
            "V:[rightSpacer(debugWidth)]",
            
            // top/bottom spacers
            "V:|[topSpacer(topGap)]",
            "V:[bottomSpacer(bottomGap)]|",
            "[topSpacer(debugWidth)]",
            "[bottomSpacer(debugWidth)]"]
        
        // edge constraints
        for constraint in constraints {
            let generatedConstraints = NSLayoutConstraint.constraintsWithVisualFormat(
                constraint,
                options: NSLayoutFormatOptions(0),
                metrics: layout,
                views: elements)
            self.view.addConstraints(generatedConstraints)
        }
        
        // centering constraints
        for (name, spacer) in spacers {
            if (name.hasPrefix("left") || name.hasPrefix("right")) {
                self.view.addConstraint(NSLayoutConstraint(
                    item: spacer,
                    attribute: NSLayoutAttribute.CenterY,
                    relatedBy: NSLayoutRelation.Equal,
                    toItem: self.view,
                    attribute: NSLayoutAttribute.CenterY,
                    multiplier: 1,
                    constant: 0))
            }
            else if (name.hasPrefix("top") || name.hasPrefix("bottom")) {
                self.view.addConstraint(NSLayoutConstraint(
                    item: spacer,
                    attribute: NSLayoutAttribute.CenterX,
                    relatedBy: NSLayoutRelation.Equal,
                    toItem: self.view,
                    attribute: NSLayoutAttribute.CenterX,
                    multiplier: 1,
                    constant: 0))
            }
        }
    }
    
    /*
    Everything here relies on a simple naming convention.
    
    The rows of the keyboard have invisible spacer rows between them.
    There are also invisible spacer rows on the top and bottom of the keyboard.
    These are all labeled "rowGap<y>", where 0 <= y <= row count.
    
    Similarly, there are invisible spacer gaps between every key.
    There are also invisible gaps at the start and end of every row.
    These are labeled "keyGap<x>x<y>, where 0 <= x <= key count and y <= 0 < row count.
    
    The keys are labeled "key<x>x<y>".
    */
    
    func createViews(keyboard: Keyboard) {
        func setColorsForKey(key: KeyboardKey, model: Key) {
            switch model.type {
            case
            Key.KeyType.Character,
            Key.KeyType.SpecialCharacter,
            Key.KeyType.Period:
                key.color = colors["lightColor"]!
                key.underColor = colors["lightShadowColor"]!
                key.borderColor = colors["borderColor"]!
                key.textColor = colors["lightTextColor"]!
            case
            Key.KeyType.Space:
                key.color = colors["lightColor"]!
                key.underColor = colors["lightShadowColor"]!
                key.borderColor = colors["borderColor"]!
                key.textColor = colors["lightTextColor"]!
                key.downColor = colors["darkColor"]!
            case
            Key.KeyType.Shift,
            Key.KeyType.Backspace:
                key.color = colors["darkColor"]!
                key.underColor = colors["darkShadowColor"]!
                key.borderColor = colors["borderColor"]!
                key.textColor = colors["darkTextColor"]!
                key.downColor = colors["lightColor"]!
                key.downUnderColor = colors["lightShadowColor"]!
                key.downTextColor = colors["lightTextColor"]!
            case
            Key.KeyType.ModeChange:
                key.color = colors["darkColor"]!
                key.underColor = colors["darkShadowColor"]!
                key.borderColor = colors["borderColor"]!
                key.textColor = colors["lightTextColor"]!
            case
            Key.KeyType.Return,
            Key.KeyType.KeyboardChange:
                key.color = colors["darkColor"]!
                key.underColor = colors["darkShadowColor"]!
                key.borderColor = colors["borderColor"]!
                key.textColor = colors["lightTextColor"]!
                key.downColor = colors["lightColor"]!
                key.downUnderColor = colors["lightShadowColor"]!
            }
        }
        
        let numRows = keyboard.rows.count
        
        for i in 0...numRows {
            var rowGap = Spacer(color: ((i == 0 || i == numRows) ? UIColor.purpleColor() : UIColor.yellowColor()))
            let rowGapName = "rowGap\(i)"
            rowGap.setTranslatesAutoresizingMaskIntoConstraints(false)
            self.elements[rowGapName] = rowGap
            self.forwardingView.addSubview(rowGap)
            
            if (i < numRows) {
                let numKeys = keyboard.rows[i].count
                
                for j in 0...numKeys {
                    var keyGap = Spacer(color: UIColor.blueColor())
                    let keyGapName = "keyGap\(j)x\(i)"
                    keyGap.setTranslatesAutoresizingMaskIntoConstraints(false)
                    
                    self.elements[keyGapName] = keyGap
                    self.forwardingView.addSubview(keyGap)
                    
                    if (j < numKeys) {
                        var key = keyboard.rows[i][j]
                        
                        var keyView = KeyboardKey(frame: CGRectZero, model: key) // TODO:
                        let keyViewName = "key\(j)x\(i)"
                        keyView.enabled = true
                        keyView.setTranslatesAutoresizingMaskIntoConstraints(false)
                        keyView.text = key.keyCap
//                        // should be UILayoutPriorityDefaultHigh
//                        keyView.setContentCompressionResistancePriority(1000, forAxis: .Vertical)
                        
                        self.forwardingView.addSubview(keyView)
                        
                        self.elements[keyViewName] = keyView
                        self.keyViewToKey[keyView] = key
                        
                        setColorsForKey(keyView, key)
                        
                        switch key.type {
                        case
                        Key.KeyType.ModeChange,
                        Key.KeyType.Space,
                        Key.KeyType.Return:
                            keyView.keyView.label.adjustsFontSizeToFitWidth = false
                            keyView.keyView.label.minimumScaleFactor = 0.1
                            keyView.keyView.label.font = keyView.keyView.label.font.fontWithSize(16)
                        default:
                            break
                        }
                        
                        switch key.type {
                        case Key.KeyType.KeyboardChange:
                            keyView.addTarget(self, action: "advanceToNextInputMode", forControlEvents: .TouchUpInside)
                        case Key.KeyType.Backspace:
                            keyView.addTarget(self, action: "backspacePressed:", forControlEvents: .TouchUpInside)
                        default:
                            break
                        }
                        
                        if key.outputText {
                            keyView.addTarget(self, action: "keyPressed:", forControlEvents: .TouchUpInside)
                            keyView.addTarget(self, action: "takeScreenshotDelay", forControlEvents: .TouchDown)
                        }
                        
                        let showOptions: UIControlEvents = .TouchDown | .TouchDragInside | .TouchDragEnter
                        let hideOptions: UIControlEvents = .TouchUpInside | .TouchUpOutside | .TouchDragOutside
                        
                        if key.type == Key.KeyType.Character || key.type == Key.KeyType.Period {
                            keyView.addTarget(keyView, action: Selector("showPopup"), forControlEvents: showOptions)
                            keyView.addTarget(keyView, action: Selector("hidePopup"), forControlEvents: hideOptions)
                        }
                        
                        //        self.nextKeyboardButton.setTitle(NSLocalizedString("Next Keyboard", comment: "Title for 'Next Keyboard' button"), forState: .Normal)
                        //        self.nextKeyboardButton.sizeToFit()
                    }
                }
            }
        }
    }
    
    func centerItems(item1: UIView, item2: UIView, vertical: Bool) {
        self.view.addConstraint(NSLayoutConstraint(
            item: item1,
            attribute: (vertical ? NSLayoutAttribute.CenterX : NSLayoutAttribute.CenterY),
            relatedBy: NSLayoutRelation.Equal,
            toItem: item2,
            attribute: (vertical ? NSLayoutAttribute.CenterX : NSLayoutAttribute.CenterY),
            multiplier: 1,
            constant: 0))
    }
    
    func addGapPair(nameFormat: String, row: Int, startIndex: Int, endIndex: Int, leftAnchor: String?, rightAnchor: String?, vertical: Bool, width: Double?) {
        var allConstraints: Array<String> = []
        
        var leftGapName = String(format: nameFormat, startIndex, row)
        var rightGapName = String(format: nameFormat, endIndex, row)
        var verticalFlag = (vertical ? "V:" : "")
        var inverseVerticalFlag = (!vertical ? "V:" : "")
        
        if leftAnchor {
            allConstraints += "\(verticalFlag)[\(leftAnchor!)][\(leftGapName)]"
        }
        
        if rightAnchor {
            allConstraints += "\(verticalFlag)[\(rightGapName)][\(rightAnchor!)]"
        }
        
        if width {
            allConstraints += "\(verticalFlag)[\(leftGapName)(\(width!))]"
        }
        
        allConstraints += "\(verticalFlag)[\(rightGapName)(\(leftGapName))]"
        
        allConstraints += "\(inverseVerticalFlag)[\(leftGapName)(debugWidth)]"
        allConstraints += "\(inverseVerticalFlag)[\(rightGapName)(debugWidth)]"
        
        if vertical {
            centerItems(self.elements[leftGapName]!, item2: self.elements["superview"]!, vertical: true)
            centerItems(self.elements[rightGapName]!, item2: self.elements["superview"]!, vertical: true)
        }
        else {
            centerItems(self.elements[leftGapName]!, item2: self.elements["key\(0)x\(row)"]!, vertical: false)
            centerItems(self.elements[rightGapName]!, item2: self.elements["key\(0)x\(row)"]!, vertical: false)
        }
        
        for constraint in allConstraints {
            let generatedConstraints = NSLayoutConstraint.constraintsWithVisualFormat(
                constraint,
                options: NSLayoutFormatOptions(0),
                metrics: layout,
                views: elements)
            self.view.addConstraints(generatedConstraints)
        }
    }
    
    func addGapsInRange(nameFormat: String, row: Int, startIndex: Int, endIndex: Int, vertical: Bool, width: Double?) {
        var allConstraints: Array<String> = []
        
        var firstGapName = String(format: nameFormat, startIndex, row)
        var verticalFlag = (vertical ? "V:" : "")
        var inverseVerticalFlag = (!vertical ? "V:" : "")
        
        if width {
            allConstraints +=  "\(verticalFlag)[\(firstGapName)(\(width!))]"
        }
        
        for i in startIndex...endIndex {
            var gapName = String(format: nameFormat, i, row)
            
            if i > 0 {
                allConstraints += "\(verticalFlag)[\(gapName)(\(firstGapName))]"
            }
            
            allConstraints += "\(inverseVerticalFlag)[\(gapName)(debugWidth)]"
            
            if vertical {
                centerItems(self.elements[gapName]!, item2: self.elements["superview"]!, vertical: true)
            }
            else {
                centerItems(self.elements[gapName]!, item2: self.elements["key\(0)x\(row)"]!, vertical: false)
            }
        }
        
        for constraint in allConstraints {
            let generatedConstraints = NSLayoutConstraint.constraintsWithVisualFormat(
                constraint,
                options: NSLayoutFormatOptions(0),
                metrics: layout,
                views: elements)
            self.view.addConstraints(generatedConstraints)
        }
    }
    
    func createRowGapConstraints(keyboard: Keyboard) {
        var allConstraints: Array<String> = []
        
        var canonicalMarginGap: String? = nil
        var canonicalRowGap: String? = nil
        
        for i in 0...keyboard.rows.count {
            let rowGapName = "rowGap\(i)"
            let rowGap = self.elements[rowGapName]
            
            let isTopMarginGap = (i == 0)
            let isBottomMarginGap = (i == keyboard.rows.count)
            
            if isTopMarginGap {
                canonicalMarginGap = rowGapName
                allConstraints += "V:[topSpacer][\(rowGapName)(0)]"
            }
            else if isBottomMarginGap {
                allConstraints += "V:[key\(0)x\(i-1)][\(rowGapName)(\(canonicalMarginGap!))][bottomSpacer]"
            }
            else {
                if !canonicalRowGap {
                    allConstraints += "V:[key\(0)x\(i-1)][\(rowGapName)]"
                    allConstraints += "V:[\(rowGapName)(>=5@50)]" // QQQ:
                    canonicalRowGap = rowGapName
                }
                else {
                    allConstraints += "V:[key\(0)x\(i-1)][\(rowGapName)(\(canonicalRowGap!))]"
                }
            }
            
            // each row has the same width
            allConstraints += "[\(rowGapName)(debugWidth)]"
            
            // and the same centering
            self.view.addConstraint(NSLayoutConstraint(
                item: rowGap,
                attribute: NSLayoutAttribute.CenterX,
                relatedBy: NSLayoutRelation.Equal,
                toItem: self.view,
                attribute: NSLayoutAttribute.CenterX,
                multiplier: 1,
                constant: 0))
        }
        
        for constraint in allConstraints {
            let generatedConstraints = NSLayoutConstraint.constraintsWithVisualFormat(
                constraint,
                options: NSLayoutFormatOptions(0),
                metrics: layout,
                views: elements)
            self.view.addConstraints(generatedConstraints)
        }
    }
    
    // TODO: make this a single constraint string??
    func createKeyGapConstraints(keyboard: Keyboard) {
        for i in 0..<keyboard.rows.count {
            // TODO: both of these should be determined based on the model data, not the row #
            let isSideButtonRow = (i == 2)
            let isEquallySpacedRow = (i == 3)
            let rowsCount = keyboard.rows[i].count
            
            if isSideButtonRow {
                addGapPair(
                    "keyGap%dx%d",
                    row: i,
                    startIndex: 0,
                    endIndex: rowsCount,
                    leftAnchor: "leftSpacer",
                    rightAnchor: "rightSpacer",
                    vertical: false,
                    width: 0)
                addGapPair(
                    "keyGap%dx%d",
                    row: i,
                    startIndex: 1,
                    endIndex: rowsCount - 1,
                    leftAnchor: nil,
                    rightAnchor: nil,
                    vertical: false,
                    width: nil)
                addGapsInRange(
                    "keyGap%dx%d",
                    row: i,
                    startIndex: 2,
                    endIndex: rowsCount - 2,
                    vertical: false,
                    width: layout["keyGap"]!)
            }
            else if isEquallySpacedRow {
                addGapPair(
                    "keyGap%dx%d",
                    row: i,
                    startIndex: 0,
                    endIndex: keyboard.rows[i].count,
                    leftAnchor: "leftSpacer",
                    rightAnchor: "rightSpacer",
                    vertical: false,
                    width: 0)
                addGapsInRange(
                    "keyGap%dx%d",
                    row: i,
                    startIndex: 1,
                    endIndex: rowsCount - 1,
                    vertical: false,
                    width: nil)
            }
            else {
                addGapPair(
                    "keyGap%dx%d",
                    row: i,
                    startIndex: 0,
                    endIndex: rowsCount,
                    leftAnchor: "leftSpacer",
                    rightAnchor: "rightSpacer",
                    vertical: false,
                    width: nil)
                addGapsInRange(
                    "keyGap%dx%d",
                    row: i,
                    startIndex: 1,
                    endIndex: rowsCount - 1,
                    vertical: false,
                    width: layout["keyGap"]!)
            }
        }
    }
    
    func createKeyConstraints(keyboard: Keyboard) {
        var allConstraints: Array<String> = []
        
        for i in 0..<keyboard.rows.count {
            for j in 0..<keyboard.rows[i].count {
                let keyModel = keyboard.rows[i][j]
                
                let keyName = "key\(j)x\(i)"
                let key = self.elements[keyName]
                
                var width = ""
                
                switch keyModel.type {
                case Key.KeyType.KeyboardChange, Key.KeyType.ModeChange, Key.KeyType.SpecialCharacter, Key.KeyType.Period:
                    width = "(specialKeyWidth)"
                case Key.KeyType.Space:
                    width = "(spaceWidth)"
                case Key.KeyType.Return:
                    width = "(doneKeyWidth)"
                default:
                    break
                }
                
                allConstraints += "[keyGap\(j)x\(i)][\(keyName)\(width)][keyGap\(j+1)x\(i)]"
                allConstraints += "V:[rowGap\(i)][\(keyName)]"
                
                let canonicalKey = elements["key0x0"]
                let isCanonicalKey = (key == canonicalKey) // TODO:
                
                // only the canonical key has a constant width
                if isCanonicalKey {
                    let keyWidth = layout["keyWidth"]!
                    allConstraints += "[\(keyName)(\(keyWidth)@19)]"
                    allConstraints += "[\(keyName)(\(keyWidth*2)@20)]"
                    allConstraints += "V:[\(keyName)(<=keyHeight@100,>=5@100)]"
                }
                else {
                    allConstraints += "V:[\(keyName)(key0x0)]"
                    
                    switch keyModel.type {
                    case Key.KeyType.Character:
                        var constraint0 = NSLayoutConstraint(
                            item: key,
                            attribute: NSLayoutAttribute.Width,
                            relatedBy: NSLayoutRelation.Equal,
                            toItem: canonicalKey,
                            attribute: NSLayoutAttribute.Width,
                            multiplier: 1,
                            constant: 0)
                        self.view.addConstraint(constraint0)
                    case Key.KeyType.Shift, Key.KeyType.Backspace:
                        let shiftAndBackspaceMaxWidth = layout["shiftAndBackspaceMaxWidth"]!
                        let keyWidth = layout["keyWidth"]!
                        var constraint = NSLayoutConstraint(
                            item: key,
                            attribute: NSLayoutAttribute.Width,
                            relatedBy: NSLayoutRelation.Equal,
                            toItem: canonicalKey,
                            attribute: NSLayoutAttribute.Width,
                            multiplier: CGFloat(shiftAndBackspaceMaxWidth/keyWidth),
                            constant: 0)
                        self.view.addConstraint(constraint)
                    default:
                        break
                    }
                }
            }
        }
        
        for constraint in allConstraints {
            let generatedConstraints = NSLayoutConstraint.constraintsWithVisualFormat(
                constraint,
                options: NSLayoutFormatOptions(0),
                metrics: layout,
                views: elements)
            self.view.addConstraints(generatedConstraints)
        }
    }
    
    var blah = 0
    func keyPressed(sender: KeyboardKey) {
        UIDevice.currentDevice().playInputClick()
        
        let model = self.keyViewToKey[sender]
        
        NSLog("context before input: \((self.textDocumentProxy as UITextDocumentProxy).documentContextBeforeInput)")
        NSLog("context after input: \((self.textDocumentProxy as UITextDocumentProxy).documentContextAfterInput)")
        
        if model && model!.outputText {
            if blah < 3 {
                (self.textDocumentProxy as UITextDocumentProxy as UIKeyInput).insertText(model!.outputText)
                blah += 1
            }
            else {
                (self.textDocumentProxy as UITextDocumentProxy as UIKeyInput).deleteBackward()
                (self.textDocumentProxy as UITextDocumentProxy as UIKeyInput).deleteBackward()
                (self.textDocumentProxy as UITextDocumentProxy as UIKeyInput).deleteBackward()
                (self.textDocumentProxy as UITextDocumentProxy as UIKeyInput).insertText("😽")
                blah = 0
            }
        }
    }
    
    func backspacePressed(sender: KeyboardKey) {
        UIDevice.currentDevice().playInputClick()
        
        (self.textDocumentProxy as UITextDocumentProxy as UIKeyInput).deleteBackward()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated
    }

    override func textWillChange(textInput: UITextInput) {
        // The app is about to change the document's contents. Perform any preparation here.
    }

    override func textDidChange(textInput: UITextInput) {
        // The app has just changed the document's contents, the document context has been updated.
    }
}

class Spacer: UIView {
    init(frame: CGRect) {
        super.init(frame: frame)
        self.hidden = true
        self.userInteractionEnabled = false
    }
    convenience init() {
        return self.init(frame: CGRectZero)
    }
    convenience init(color: UIColor) {
        self.init()
//        self.layer.backgroundColor = color.CGColor
//        self.hidden = false
    }
//    override class func requiresConstraintBasedLayout() -> Bool {
//        return true
//    }
}
