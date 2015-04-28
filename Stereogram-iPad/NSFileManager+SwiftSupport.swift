//
//  NSFileManager+SwiftSupport.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 28/04/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import Foundation

extension NSFileManager {
    
    /// Check if a URL is a file URL pointing at a valid directory.
    ///
    /// :param: directory The URL to test.
    /// :returns: True if this URL points to a directory, False if it doesn't or cannot be accessed.
    
    func URLIsDirectory(directory: NSURL) -> Bool {
        var isValid: ObjCBool = false
        var mgr = NSFileManager.defaultManager()
        if let path = directory.path {
            var isDir = UnsafeMutablePointer<ObjCBool>.alloc(1)
            if mgr.fileExistsAtPath(path, isDirectory: isDir) {
                isValid = isDir.memory
            }
        }
        return isValid.boolValue
    }
}
