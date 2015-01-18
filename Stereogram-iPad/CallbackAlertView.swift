//
//  CallbackAlertView.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 17/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

class CallbackAlertView : NSObject, UIAlertViewDelegate {
    
    typealias ActionBlock = () -> Void
    typealias TitleActionDict = [ String : ActionBlock ]
    
    private var buttonTitlesAndBlocks = TitleActionDict()
    private var cancelButtonTitle = "Cancel"
    private var alertView = UIAlertView()
    
    init(title: String, message: String, buttonTitlesAndBlocks: TitleActionDict, cancelButtonTitle: String) {
        super.init()
        
        self.buttonTitlesAndBlocks = buttonTitlesAndBlocks
        self.cancelButtonTitle = cancelButtonTitle
        
        assert(buttonTitlesAndBlocks[cancelButtonTitle] != nil, "The dictionary does not contain an action for cancel button title \(cancelButtonTitle)")
        alertView.title = title
        alertView.message = message
        alertView.delegate = self
        
        // Add the buttons, noting the index of the cancel button for later.
        var cancelIndex = -1
        for title in buttonTitlesAndBlocks.keys {
            let buttonIndex = alertView.addButtonWithTitle(title)
            if title == cancelButtonTitle {
                cancelIndex = buttonIndex
            }
        }
        alertView.cancelButtonIndex = cancelIndex
    }
    
    convenience init(title:String, message:String, confirmButtonTitle:String, confirmBlock: ActionBlock, cancelButtonTitle:String, cancelBlock: ActionBlock) {
        let titlesAndBlocks = [confirmButtonTitle : confirmBlock, cancelButtonTitle : cancelBlock]
        self.init(title: title, message: message, buttonTitlesAndBlocks: titlesAndBlocks, cancelButtonTitle: cancelButtonTitle)
    }
    
    func show() {
        alertView.show()
    }
    
    // MARK: - Alert View Delegate
    
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        let buttonTitle = alertView.buttonTitleAtIndex(buttonIndex)
        if let action = buttonTitlesAndBlocks[buttonTitle] {
            action()
        } else {
            assert(false, "No action for button title \(buttonTitle) index \(buttonIndex)")
        }
    }
}

