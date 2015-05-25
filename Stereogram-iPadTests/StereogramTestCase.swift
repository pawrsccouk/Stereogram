//
//  StereogramTestCase.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 29/04/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit
import XCTest

/// This is a subclass which creates and tears down common objects used when handling stereograms
/// (such as a temp directory to put stereograms into).

class StereogramTestCase: XCTestCase {

	let tmpdirURL = NSURL(fileURLWithPath: "Photostore Temp Empty Directory")!
	let fileManager = NSFileManager.defaultManager()
	lazy var bundle = StereogramTestCase.getBundle()
	let leftImage: UIImage! = UIImage(  named: "LeftImage"
		,                            inBundle: StereogramTestCase.getBundle()
		,       compatibleWithTraitCollection: nil)
	let rightImage: UIImage! = UIImage( named: "RightImage"
		,                            inBundle: StereogramTestCase.getBundle()
		,       compatibleWithTraitCollection: nil)
	var newDirURL: NSURL!
	let emptyDirectoryName = "PhotoStore Empty Directory"

	private func makeEmptyDirectory() -> NSURL? {
		if let
			tmpDir = NSTemporaryDirectory(),
			tmpURL = NSURL(fileURLWithPath: tmpDir, isDirectory: true),
			srcURL = bundle.URLForResource(emptyDirectoryName, withExtension: nil) {
				let newDir = tmpURL.URLByAppendingPathComponent(tmpdirURL.path!)
				var error: NSError?
				let result = fileManager.copyItemAtURL(srcURL, toURL: newDir, error: &error)
				assert(result
					, "File Manager copy from \(srcURL) to \(newDir) failed with error \(error)")
				return newDir.URLByStandardizingPath
		}
		return nil // Copy failed.
	}

	override func setUp() {
		super.setUp()
		// This method is called before the invocation of each test method in the class.
		// Delete the temporary directory in case any previous test left it behind.
		deleteTempDirectory()
		newDirURL = makeEmptyDirectory()
	}

	override func tearDown() {
		// This method is called after the invocation of each test method in the class.
		super.tearDown()

		// Ensure nothing has deleted the temporary directory during the tests.
		XCTAssert(fileManager.urlIsDirectory(newDirURL)
			, "URL \(newDirURL) has been deleted during the previous test.")

		// Delete the temporary directory in case any previous test left it behind.
		deleteTempDirectory()
	}

	class func getBundle() -> NSBundle {
		return NSBundle(forClass: PhotoStoreTests.self)
	}

	func doForEach(stereograms: [Stereogram!], f: (Int, Stereogram!) -> Void) {
		var i = 0
		for s in stereograms {
			f(i++, s)
		}
	}

	func deleteTempDirectory() -> Bool {
		if let
			path      = NSTemporaryDirectory(),
			tmpURL = NSURL(fileURLWithPath: path, isDirectory: true),
			dirName = tmpdirURL.path {
				let mydirURL = tmpURL.URLByAppendingPathComponent(dirName)
				var error: NSError?
				if fileManager.removeItemAtURL(mydirURL, error: &error) {
					return true
				}
		}
		return false
	}


	/// Asserts that the directory under URL contains the number of sub-directories in NUMSUBDIRS.
	///
	/// Makes no assumptions about any other contents under the URL, just counts the directories.
	func URLContainsSubdirs(url: NSURL, numSubdirs: Int) -> Bool {
		var error: NSError?
		if let fileArray = fileManager.contentsOfDirectoryAtURL(url
			,                        includingPropertiesForKeys:nil
			,                                           options:.SkipsHiddenFiles
			,                                             error:&error) {
				var numStereograms = fileArray.filter {
					self.fileManager.urlIsDirectory(($0 as? NSURL) ?? NSURL())
					}.count ?? 0
				return numStereograms == numSubdirs
		} else {
			assert(false, "Error searching test directory: \(error)")
			return false
		}
	}

}
