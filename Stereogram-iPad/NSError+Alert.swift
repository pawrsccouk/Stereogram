//
//  NSError+Alert.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 16/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

private let kLocation = "Location", kCaller = "Caller", kTarget = "Target", kSelector = "Selector"

extension NSError {
    
    /// Display the error in an alert view.
    ///
    /// Gets the error text from some known places in the NSError description.
    /// The alert will just have a close button and no extra specifications.
    ///
    /// :param: title The title to display above the alert.
    /// :param: parent The view controller to present the alert on top of.
    
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
    
    /// Convenience initializer.
    /// Create a new error object using the photo store error domain and code.
    ///
    /// :param: errorCode The PhotoStore error code to return.
    /// :param: userInfo  NSDicationary with info to associate with this error.

    convenience init(errorCode code: ErrorCode, userInfo:[String : AnyObject]?) {
        self.init(domain:ErrorDomain.PhotoStore.rawValue, code:code.rawValue, userInfo:userInfo)
    }

    
    /// Class function to create an error to return when something failed but didn't give any indication why.
    ///
    /// :param: location A string which is included in the error text and returned in the userInfo dict.
    ///         This should give a clue as to what operation was being performed.
    /// :param: target   A string which is included in the error text and returned in the userInfo dict.
    ///         This should give a clue as to which function returned this error (i.e. the function in 3rd party code that returned the unexpected error.)
    
    class func unknownErrorWithLocation(location: String, target: String = "") -> NSError {
        var errorMessage = "Unknown error at location \(location)"
        if target != "" {
            errorMessage = "\(errorMessage) calling \(target)"
        }
        let userInfo = [
            NSLocalizedDescriptionKey : errorMessage,
            kLocation                 : location,
            kTarget                   : target]
        return NSError(errorCode:.UnknownError, userInfo:userInfo)
    }
    
    /// Class function to create an error to return when a method call failed but didn't say why.
    ///
    /// :param: target The object we called a method on.
    /// :param: selector Selector for the method we called on TARGET.
    /// :param: caller The method or function which called the method that went wrong. I.e. where in my code it is.
    
    class func unknownErrorWithTarget(target: AnyObject, method: String, caller: String) -> NSError {
        let callee = "\(target).(\(method))"
        let errorText = "Unknown error calling \(callee) from caller \(caller)"
        let userInfo = [
            NSLocalizedDescriptionKey : errorText,
            kCaller                   : caller,
            kTarget                   : target,
            kSelector                 : method]
        return NSError(errorCode: .UnknownError, userInfo: userInfo)
    }
    
}

