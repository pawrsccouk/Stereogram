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

    func urlIsDirectory(directory: NSURL) -> Bool {
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

	/// Create a directory at the given URL, returning a Result with the error if unsuccessful.
	///
	/// :Note:
	/// :param: url - A file URL that specifies the directory to create.
	/// :param: withIntermediateDirectories - If YES, this method creates any non-existent parent
	///         directories as part of creating the directory in url.
	/// :param: attributes - The file attributes for the new directory.
	/// :result: .Success() on success, .Error(error) on error.

	func createDirectoryAtURL(    url: NSURL
		, withIntermediateDirectories: Bool = false
		,                  attributes: [NSObject: AnyObject]? = nil) -> Result {
		var error: NSError?
		if !createDirectoryAtURL(url
			,   withIntermediateDirectories: withIntermediateDirectories
			,                    attributes: attributes
			,                         error: &error) {
				return .Error(error!)
		}
		return .Success()
	}

}
