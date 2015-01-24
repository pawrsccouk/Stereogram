//
//  NSError+Alert.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 16/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

extension NSError {
    
    // Display the error in an alert view with the specified title. Get the error text from some known places in the NSError description.
    // The alert will just have a close button and no extra specifications.
    func showAlertWithTitle(title: String, parentViewController parent: UIViewController) {
        // Get text from the error's help anchor if it exists. If not, try the localizedFailureReason. Otherwise try the localizedDescription.
        var errorText = self.localizedDescription
        if let t = self.helpAnchor { errorText = t }
        else if let t = self.localizedFailureReason { errorText = t }

        NSLog("Showing error \(self) final text \(errorText)")
        
        let alertController = UIAlertController(title: title, message: errorText, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "Close", style: .Default, handler: nil))
        parent.presentViewController(alertController, animated: true, completion: nil)
    }
}

