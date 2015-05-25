//
//  NSURL+Extensions.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 25/05/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import Foundation

extension NSURL {

	/// True if the URL already exists and points to a directory.
	/// False if it doesn't exist or points to another object type.

	var isDirectory: Bool {
		var isDirectory = UnsafeMutablePointer<ObjCBool>.alloc(1)
		isDirectory.initialize(ObjCBool(false))
		let fileManager = NSFileManager.defaultManager()
		if let path = path {
			let fileExists = fileManager.fileExistsAtPath(path, isDirectory:isDirectory)
			let isDir = isDirectory.memory.boolValue
			return fileExists && isDir
		}
		return false
	}

}