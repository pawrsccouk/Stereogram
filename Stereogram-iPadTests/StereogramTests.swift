//
//  Stereogram_Tests.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 29/04/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit
import XCTest

/// Copy stereograms from a bundle directory into a url
///
/// :param: url        File URL to copy stereograms into.
/// :param: fromBundle Bundle to search for the directory named _sourceName_
/// :param: sourceName Name of a directory in the test bundle which has stereograms to copy.
/// :returns: An array of file URLs of the stereograms copied.

private func copyStereogramsIntoURL(url: NSURL
	,                 fromBundle bundle: NSBundle
	,                   sourceName name: String) -> [NSURL] {
		var error: NSError?
		var subdirs = [NSURL]()
		if let bundleRootURL = bundle.URLForResource(name, withExtension: nil) {
			let options = NSDirectoryEnumerationOptions.SkipsSubdirectoryDescendants
				|         NSDirectoryEnumerationOptions.SkipsHiddenFiles
			let fileManager = NSFileManager.defaultManager()
			if let dirs = fileManager.contentsOfDirectoryAtURL(
				bundleRootURL
				, includingPropertiesForKeys: nil
				,                    options: options
				,                      error: &error) as? [NSURL] {
					subdirs = dirs
					assert(dirs.count == 2
						, "Wrong number of URLs under \(bundleRootURL). "
							+ "Was \(subdirs.count) expected 2")
					for subdir in dirs {
						let fullNewPath = url.URLByAppendingPathComponent(subdir.lastPathComponent!
							,                                isDirectory: true)
						let success = fileManager.copyItemAtURL(subdir
							,                            toURL: fullNewPath
							,                            error: &error)
						assert(success,
							"Failed to copy stereogram from \(subdir) to \(url): error \(error)")
					}
			} else {
				assert(false, "File manager failed to search URL \(bundleRootURL): error \(error)")
			}
		} else {
			assert(false, "Failed to find directory \(name) in bundle \(bundle)")
		}
		return subdirs
}

// MARK: -

class StereogramTests: StereogramTestCase {

	// MARK: Properties

	// Name of a directory under our testing bundle containing 2 stereograms.
	let photoStore2Directory = "PhotoStore 2 Directory"

	// MARK: Private methods

	//    override func setUp() {
	//        super.setUp()
	//        // This method is called before the invocation of each test method in the class.
	//    }
	//
	//    override func tearDown() {
	//        // This method is called after the invocation of each test method in the class.
	//        super.tearDown()
	//     }

	/// Returns the filename part of a URL.
	///
	/// :param: url A File URL to strip.
	/// :returns: The name of the file without the preceding directory.

	private func fileNameFromURL(url: NSURL) -> String {
		let leaf = url.lastPathComponent
		assert(leaf != nil, "Couldn't get the directory name during the test.")
		return leaf!
	}

	private func fileNamesFromURLs(urls: [NSURL]) -> [String] {
		return urls.map(fileNameFromURL)
	}

	/// Fails the unit test if result is an error, otherwise returns whatever the result contained.
	///
	/// :param: result The result to test.
	/// :param: errorMessage The text to print out if the message fails.
	///                      I append the error text to this.
	/// :returns: The value contained in result if successful, or aborts if unsuccessful.

	private func checkAndReturn<T>(result: ResultOf<T>
		,       @autoclosure errorMessage: () -> String) -> T! {
			switch result {
			case .Success(let value):
				return value.value
			case .Error(let error):
				XCTFail(errorMessage() + ": Error \(error)")
				return nil
			}
	}

	/// Creates a new stereogram object under the base URL provided, and returns it.
	/// Asserts if the construction fails.
	///
	/// :note: This fails with a regular assert, not XCTFail()).
	///        So don't use when testing the Stereogram constructor,
	///        only when creating a Stereogram to test something else.
	///
	/// :param: url The URL to create the stereogram under.
	/// :returns: The stereogram created.

	private func makeStereogram(url: NSURL) -> Stereogram {
		var error: NSError?
		let stereogram = Stereogram(leftImage: leftImage
			,                      rightImage: rightImage
			,                         baseURL: url
			,                           error: &error)
		assert(stereogram != nil, "Stereogram.init() failed. Error: \(error)")
		return stereogram!
	}

}


// MARK: - Unit Test methods
extension StereogramTests {

	/// Test that initializing with images and a base URL
	/// actually creates the stereogram as a subdirectory of the base URL.
	func testInit_BaseURL() {
		var error: NSError?

		assert(URLContainsSubdirs(newDirURL, numSubdirs: 0)
			, "After setup 'empty' array \(newDirURL) is not really empty.")
		if let sgm = Stereogram(leftImage: leftImage
			,                  rightImage: rightImage
			,                     baseURL: newDirURL
			,                       error: &error) {
				XCTAssert(URLContainsSubdirs(newDirURL, numSubdirs: 1)
					, "Stereogram create - Creating stereogram in the wrong place.")
				let sgmURL = sgm.baseURL
				let sgmBaseURL = sgmURL.URLByDeletingLastPathComponent!
				XCTAssertEqual(newDirURL, sgmBaseURL
					, "Base URL \(sgmBaseURL) is not the url we gave it \(newDirURL)")
		} else {
			XCTFail("Stereogram initializer failed with error \(error)")
		}
	}

	/// Test the class function to ensure searching an empty directory returns no stereograms.
	func testFindStereogramsUnderURL_Empty() {

		// Test against an empty directory.
		let errorText = "allStereogramsUnderURL failed to search \(newDirURL)"
		let stereograms = checkAndReturn(Stereogram.allStereogramsUnderURL(newDirURL)
			,              errorMessage: errorText)
		XCTAssertEqual(stereograms.count, 0, "Returned a value when searching an empty directory.")
	}


	/// Test the class function to ensure it returns the right number of stereograms.
	func testFindStereogramsUnderURL_Existing() {

		// Set up a base URL to search by copying two stereograms in from the bundle.
		// Returns an array with the full file URLs of the stereograms copied.
		let subdirs = copyStereogramsIntoURL(newDirURL
			,                    fromBundle: bundle
			,                    sourceName: photoStore2Directory)

		// Test that we find them.
		let errorText = "allStereogramsUnderURL failed to search \(newDirURL)"
		let stereograms: [Stereogram] = checkAndReturn(Stereogram.allStereogramsUnderURL(newDirURL)
			,                                          errorMessage: errorText)

		// Check that the right number of stereograms have been retrieved.
		XCTAssertEqual(stereograms.count, 2
			, "Returned the wrong number of stereograms when searching a directory.")

		let fileNames = subdirs.map(fileNameFromURL)
		// Check that each stereogram in the list has the same name as one in the source directory.
		doForEach(stereograms) { _, s in
			if let stereogramName = s.baseURL.lastPathComponent {
				let numFound = fileNames.filter { $0 == stereogramName }.count
				XCTAssertEqual(numFound, 1
					, "Stereogram \(s) name \(stereogramName) not found in subdirs \(fileNames)")
			} else {
				XCTFail("Bad URL Stereogram.baseURL <\(s.baseURL)>")
			}
		}
	}

	func testProperty_ViewingMethod() {
		let stereogram = makeStereogram(newDirURL)

		XCTAssertEqual(stereogram.viewingMethod, ViewMode.Crosseyed
			, "Default viewing method \(stereogram.viewingMethod) is not CrossEyed")
		stereogram.viewingMethod = .Walleyed
		XCTAssertEqual(stereogram.viewingMethod, ViewMode.Walleyed
			, "Changing mode to walleyed resulted in a method of \(stereogram.viewingMethod)")
		stereogram.viewingMethod = .AnimatedGIF
		XCTAssertEqual(stereogram.viewingMethod, ViewMode.AnimatedGIF
			, "Changing mode to Animated resulted in a method of \(stereogram.viewingMethod)")

	}

	func testProperty_BaseURL() {
		let s = makeStereogram(newDirURL)
		let stereogramParentURL = s.baseURL.URLByDeletingLastPathComponent?.URLByStandardizingPath
		XCTAssertNotNil(stereogramParentURL
			, "Stereogram.baseURL of \(s.baseURL): Couldn't get parent directory.")
		XCTAssertEqual(stereogramParentURL!, newDirURL
			, "Stereogram.baseURL \(s.baseURL) is not under parent URL \(newDirURL), "
				+ "but under \(stereogramParentURL!)")
	}

	func testProperty_MimeType() {
		let stereogram = makeStereogram(newDirURL)
		assert(stereogram.viewingMethod == ViewMode.Crosseyed
			, "Default viewing mode is not crosseyed.")
		XCTAssertEqual(stereogram.mimeType, "image/jpeg"
			, "Default mime type \(stereogram.mimeType) should be image/jpeg")
		stereogram.viewingMethod = .Walleyed
		XCTAssertEqual(stereogram.mimeType, "image/jpeg"
			, "Mime type for Walleyed is \(stereogram.mimeType) should be image/jpeg")
		stereogram.viewingMethod = .AnimatedGIF
		XCTAssertEqual(stereogram.mimeType, "image/gif"
			, "Mime type for AnimatedGIF is \(stereogram.mimeType) should be image/gif")
	}

	func testStereogramImage() {
		let combinedSize = CGSizeMake(leftImage.size.width + rightImage.size.width
			,                         leftImage.size.height)
		let stereogram = makeStereogram(newDirURL)

		func checkCrosseyed() {
			stereogram.viewingMethod = .Crosseyed
			let crossImage = checkAndReturn(stereogram.stereogramImage()
				, errorMessage: "Stereogram \(stereogram) failed to create stereogram image.")
			XCTAssertEqual(crossImage.size, combinedSize
				, "Resultant image \(crossImage) size \(crossImage.size) should be \(combinedSize)")
			XCTAssertNil(crossImage.images
				, "Crosseyed image should not have animation frames.")
		}
		checkCrosseyed()

		func checkWalleyed() {
			stereogram.viewingMethod = .Walleyed
			let wallImage = checkAndReturn(stereogram.stereogramImage()
				, errorMessage: "Stereogram \(stereogram) failed to create stereogram image.")
			XCTAssertEqual(wallImage.size, combinedSize
				, "Resultant image \(wallImage) size \(wallImage.size) should be \(combinedSize)")
			XCTAssertNil(wallImage.images
				, "Walleyed image should not have animation frames.")
		}
		checkWalleyed()

		func checkAnimated() {
			stereogram.viewingMethod = .AnimatedGIF
			let gifImage = checkAndReturn(stereogram.stereogramImage()
				, errorMessage: "Stereogram \(stereogram) failed to create stereogram image.")
			XCTAssertEqual(gifImage.size, leftImage.size
				, "Resultant image \(gifImage)  size mismatch")
			XCTAssertNotNil(gifImage.images, "Animated image has no animation frames.")
			XCTAssertEqual(gifImage.images?.count ?? 0, 2
				, "Animated image has \(gifImage.images?.count) animation frames, should be 2")
		}
		checkAnimated()
	}

	func testThumbnailImage() {
//		XCTFail("Test not implemented.")
	}

	func testImageCaching() {
//		XCTFail("Test not implemented.")
	}
}
