//
//  CallbackActionSheet.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 16/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

class CallbackActionSheet : NSObject, UIActionSheetDelegate {
    
    typealias ActionCallback = () -> Void
    typealias TitleBlockDict = [ String : ActionCallback ]
        
    init(title: String, buttonTitlesAndBlocks: TitleBlockDict, cancelButtonTitle: String?, destructiveButtonTitle: String?) {
        self.buttonTitlesAndBlocks = buttonTitlesAndBlocks
        self.destructiveButtonTitle = destructiveButtonTitle
        self.cancelButtonTitle = cancelButtonTitle
        self.actionSheet = UIActionSheet()
        
        super.init()
        
        // Take a copy of this dictionary without the cancel and destructive titles.
        var otherButtons = self.buttonTitlesAndBlocks
        if let cancelTitle = cancelButtonTitle {
            otherButtons[cancelTitle] = nil
        }
        if let destructiveTitle = destructiveButtonTitle {
            otherButtons[destructiveTitle] = nil
        }
        
        actionSheet.title = title
        actionSheet.delegate = self
        
        // Add the destructive button first (if any) and the cancel button last.
        // Note that the iPad action sheet will always hide the cancel button as you are supposed to click outside
        // the sheet to cancel it. This will generate a call to the delegate with the index of the cancel button automatically.
        if let title = destructiveButtonTitle {
            actionSheet.destructiveButtonIndex = actionSheet.addButtonWithTitle(title)
        }
        
        for title in otherButtons.keys {
            actionSheet.addButtonWithTitle(title)
        }
        if let title = cancelButtonTitle {
            actionSheet.cancelButtonIndex = actionSheet.addButtonWithTitle(title)
        }
    }

    convenience init(title: String, confirmButtonTitle: String, confirmBlock: ActionCallback, cancelButtonTitle: String, cancelBlock: ActionCallback) {
        let titlesAndBlocks = [confirmButtonTitle : confirmBlock, cancelButtonTitle : cancelBlock]
        self.init(title: title, buttonTitlesAndBlocks: titlesAndBlocks, cancelButtonTitle: cancelButtonTitle, destructiveButtonTitle: nil)
    }

    convenience init(title: String, destructiveButtonTitle: String, destructiveBlock: ActionCallback, cancelButtonTitle: String, cancelBlock: ActionCallback) {
        let titlesAndBlocks = [destructiveButtonTitle : destructiveBlock, cancelButtonTitle : cancelBlock]
        self.init(title: title, buttonTitlesAndBlocks: titlesAndBlocks, cancelButtonTitle: cancelButtonTitle, destructiveButtonTitle: destructiveButtonTitle)
    }
    
    func showFromBarButtonItem(barButtonItem: UIBarButtonItem, animated: Bool) {
        actionSheet.delegate = self  // Ensure this is always set.
        actionSheet.showFromBarButtonItem(barButtonItem, animated: animated)
    }
    
    // MARK: - Action Sheet Delegate
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        // If the user didn't specify a cancel handler, the system can trigger a cancel anyway under some conditions
        // e.g. user clicks outside the popover on an iPad. In that case the system should return the cancel index, but it
        // actually returns -1. Handle both these conditions.
        if( (buttonIndex == -1) || ( (cancelButtonTitle == nil) && (buttonIndex == actionSheet.cancelButtonIndex)) ) {
            return
        }
        
        // Find the button that was clicked and execute the action associated with it.
        let buttonTitle = actionSheet.buttonTitleAtIndex(buttonIndex)
        assert(buttonTitlesAndBlocks[buttonTitle] != nil, "Button index \(buttonIndex), title \(buttonTitle) has no associated action")
        if let action = buttonTitlesAndBlocks[buttonTitle] {
            action()
        }
    }
    
    // MARK: - Private methods.
    private let buttonTitlesAndBlocks: TitleBlockDict
    private let cancelButtonTitle: String?, destructiveButtonTitle: String?
    private let actionSheet: UIActionSheet
}
