//
//  Stereogram_iPadTests.swift
//  Stereogram-iPadTests
//
//  Created by Patrick Wallace on 11/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit
import XCTest

// MARK: Setup & Support
class PhotoStoreTests: StereogramTestCase {


	private func stereogramIsInArray(stereogram: Stereogram, seq: PhotoStore) -> Bool {
		// Now check the stereograms.
		for existingStereogram in seq {
			if existingStereogram == stereogram {
				return true
			}
		}
		return false
	}


	private func addStereogram(url: NSURL, photoStore: PhotoStore) -> Stereogram! {
		var error: NSError?
		if let stereogram = Stereogram(leftImage: leftImage
			,                         rightImage: rightImage
			,                            baseURL: url
			,                              error: &error) {
			photoStore.addStereogram(stereogram)
			return stereogram
		}
		else {
			assert(false, "Failed to create stereogram with error \(error)")
		}
	}

	private func addStereograms(url: NSURL, photoStore: PhotoStore, count: Int) -> [Stereogram] {
		var sgms = [Stereogram]()
		for i in 0..<count {
			sgms.append(addStereogram(url, photoStore:photoStore))
		}
		return sgms
	}
}

// MARK: - Tests
extension PhotoStoreTests {

	/// Test that the store initializes with an empty directory
	func testInitEmptyDirectory() {
		var error: NSError?
		if let
			rootDir    = bundle.URLForResource(emptyDirectoryName, withExtension: nil),
			photoStore = PhotoStore(rootDirectory:rootDir, error:&error) {
				XCTAssertEqual(photoStore.count, 0
					, "Invalid no. of stereograms \(photoStore.count) should be 0")
		} else {
			XCTFail("Failed to create photo store.")
		}
	}

	/// Test the store initializes with an existing directory with exactly 1 entry.
	func testInitExistingDirectory_1Stereogram() {
		var error: NSError?
		if let
			folder1URL = bundle.URLForResource("PhotoStore 1 Directory", withExtension: nil),
			photoStore = PhotoStore(rootDirectory:folder1URL, error: &error) {
				XCTAssertEqual(photoStore.count, 1
					, "Invalid no. of stereograms \(photoStore.count) should be 1")
		}
		else {
			XCTFail("Failed to create photo store.")
		}
	}

	/// Test the store initializes with an existing directory with exactly 2 entries and finds them.
	func testInitExistingDirectory_2Stereograms() {
		var error: NSError?
		if let
			folder1URL = bundle.URLForResource("PhotoStore 2 Directory", withExtension: nil),
			photoStore = PhotoStore(rootDirectory:folder1URL, error: &error) {
				XCTAssertEqual(photoStore.count, 2
					, "Invalid no. of stereograms \(photoStore.count) should be 2")
		}
		else {
			XCTFail("Failed to create photo store.")
		}
	}

	/// Test the store fails if it cannot access the directory.
	func testInitBadDirectory() {
		if let badDirURL = NSURL(fileURLWithPath: "/asdfasfas") {
			var error: NSError?
			if let photoStore = PhotoStore(rootDirectory: badDirURL, error: &error) {
				XCTFail("PhotoStore \(photoStore) created with invalid URL \(badDirURL)")
			} else {
				XCTAssertNotNil(error
					, "PhotoStore setup with URL \(badDirURL) failed but didn't set an error.")
				NSLog("Photostore failed to setup and gave error \(error)")
			}
		}
	}

	/// Test adding one stereogram (as UIImages) creates it in the right place.
	func testAddOneStereogram() {
		var error: NSError?
		if let photoStore = PhotoStore(rootDirectory: newDirURL, error: &error) {
			assert(photoStore.count == 0, "Invalid photo store.")

			let sgm = addStereogram(newDirURL, photoStore: photoStore)

			XCTAssertEqual(photoStore.count, 1
				, "Photo Store \(photoStore) has \(photoStore.count) stereograms.")
			XCTAssert(super.URLContainsSubdirs(newDirURL, numSubdirs: 1)
				, "Stereogram created in wrong place.")
			XCTAssert(stereogramIsInArray(sgm, seq: photoStore)
				, "Stereogram is not in the photo store after addition.")
		} else {
			assert(false, "Failed to set up unit test.")
		}
	}

	/// Check adding a stereogram to a photoStore looking over an existing directory.
	func testAddMultipleStereograms() {
		var error: NSError?
		if let
			leftImage = leftImage, rightImage = rightImage,
			photoStore = PhotoStore(rootDirectory: newDirURL, error: &error) {
				assert(photoStore.count == 0, "Invalid photo store.")

				let sgms = addStereograms(newDirURL, photoStore: photoStore, count: 3)

				XCTAssertEqual(photoStore.count, 3
					, "Photo Store \(photoStore) has \(photoStore.count) stereograms.")
				XCTAssert(URLContainsSubdirs(newDirURL, numSubdirs: 3)
					, "Stereograms created in wrong place.")

				super.doForEach(sgms) { i,sgm in
					XCTAssertEqual(sgm, photoStore.stereogramAtIndex(i)
						, "After addition, stereogram is missing.")
				}
		} else {
			assert(false, "Couldn't set up unit test.")
		}
	}

	func testRemoveOneStereogram() {
		var error: NSError?
		if let photoStore = PhotoStore(rootDirectory: newDirURL, error: &error) {
			addStereogram(newDirURL, photoStore: photoStore)
			assert(URLContainsSubdirs(newDirURL, numSubdirs: 1), "addStereogram failed.")
			// Now add 2 steregrams and test we can remove one.
			// I add twice to avoid anything where the 'last' created stereogram is cached somewhere
			// as I want to do a 'real' delete.
			switch photoStore.createStereogramFromLeftImage(leftImage, rightImage: rightImage) {
			case .Error(let e):
				assert(false, "Error setting up test: \(e)")

			case .Success(let stereogram):
				assert(URLContainsSubdirs(newDirURL, numSubdirs: 2)
					, "createStereogramFrom... failed.")

				addStereogram(newDirURL, photoStore: photoStore)
				assert(URLContainsSubdirs(newDirURL, numSubdirs: 3)
					, "createStereogramFrom... failed.")
				assert(stereogramIsInArray(stereogram.value, seq: photoStore)
					, "add failed when testing remove.")

				switch photoStore.deleteStereogram(stereogram.value) {
				case .Error(let e):
					XCTFail("Error deleting stereogram: \(e)")
				case .Success():
					XCTAssert(!stereogramIsInArray(stereogram.value, seq: photoStore)
						, "The stereogram was not removed.")
					XCTAssert(URLContainsSubdirs(newDirURL, numSubdirs: 2)
						, "Should be 2 stereograms after the deletion.")
				}
			}
		}
	}

	func testRemoveAllStereograms() {
		var error: NSError?
		if let
			photoStore = PhotoStore(rootDirectory: newDirURL, error: &error) {
				assert(photoStore.count == 0, "Creating new photo store error.")
				let sgms = addStereograms(newDirURL, photoStore: photoStore, count: 5)
				assert(photoStore.count == 5, "addStereograms failed.")
				assert(URLContainsSubdirs(newDirURL, numSubdirs: 5)
					, "addStereogram failed testing remove all stereograms.")

				for sgm in sgms {
					switch photoStore.deleteStereogram(sgm) {
					case .Error(let err):
						XCTFail("deleteStereogram failed.")
					case .Success:
						break
					}
				}

				XCTAssertEqual(photoStore.count, 0
					, "One or more stereograms present after full delete.")
				XCTAssert(URLContainsSubdirs(newDirURL, numSubdirs: 0)
					, "Subdirs present after full delete.")
		}
	}

	/// Tests that indexing the photo store works as expected.

	func testStereogramAtIndex() {
		var error: NSError?
		if let photoStore = PhotoStore(rootDirectory: newDirURL, error: &error) {
			let sgms = addStereograms(newDirURL, photoStore: photoStore, count: 5)
			assert(URLContainsSubdirs(newDirURL, numSubdirs: 5)
				, "addStereograms failed testing stereogram at index.")

			doForEach(sgms) { i, sgm in XCTAssertEqual(sgm, photoStore.stereogramAtIndex(i)
				, "Stereogram index \(i) failed.") }
		} else {
			assert(false, "Error setting up photo store")
		}
	}

	func testDeleteByIndexPaths() {
		var error: NSError?
		if let photoStore = PhotoStore(rootDirectory: newDirURL, error: &error) {
			let sgms = addStereograms(newDirURL, photoStore: photoStore, count: 6)
			assert(URLContainsSubdirs(newDirURL, numSubdirs: 6), "addSteregrams failed.")

			// Remove the 2nd and 4th items.
			let indexPaths: [NSIndexPath] = [NSIndexPath(forItem: 1, inSection: 0)
				,                            NSIndexPath(forItem: 3, inSection: 0)]
			switch photoStore.deleteStereogramsAtIndexPaths(indexPaths) {
			case .Error(let e): XCTFail("deleteStereogramsAtIndexPaths failed: Error \(e)")
			case .Success():
				XCTAssertEqual(photoStore.count, 4
					, "Photostore has \(photoStore.count) items, should be 4")
				XCTAssert(URLContainsSubdirs(newDirURL, numSubdirs: 4)
					, "Photo URL should have 4 subdirs.")
				doForEach(sgms) { (i, sgm) in
					NSLog("Testing stereogram index \(i): \(sgm)")
					switch i {
					case 1, 3:
						XCTAssert(!self.stereogramIsInArray(sgm, seq: photoStore)
							, "Stereogram \(sgm) at index \(i) is present after delete.")
					default:
						XCTAssert(self.stereogramIsInArray(sgm, seq: photoStore)
							, "Stereogram \(sgm) at index \(i) is not in the photo store.")
					}
				}
			}
		} else {
			assert(false, "PhotoStore setup failed.")
		}
	}

	func testReplaceAtIndex() {
		var error: NSError?
		if let photoStore = PhotoStore(rootDirectory: newDirURL, error: &error) {
			let sgms = addStereograms(newDirURL, photoStore: photoStore, count: 2)
			assert(URLContainsSubdirs(newDirURL, numSubdirs: 2), "addSteregrams failed.")
			if let newSgm = Stereogram(leftImage: leftImage
				,                     rightImage: rightImage
				,                        baseURL: newDirURL
				,                          error: &error) {
				photoStore.replaceStereogramAtIndex(1, withStereogram: newSgm)
				XCTAssert(photoStore.count == 2
					, "Replace changed the number of stereograms in the store.")
				XCTAssert(URLContainsSubdirs(newDirURL, numSubdirs: 2)
					, "Replace changed the number of stereograms in the base URL")
				XCTAssertEqual(photoStore.stereogramAtIndex(0), sgms[0]
					, "Replace changed item 0 which shouldn't change.")
				XCTAssertNotEqual(photoStore.stereogramAtIndex(1), sgms[1]
					, "Replace item 1 but the original is still present.")
				XCTAssertEqual(photoStore.stereogramAtIndex(1), newSgm
					, "Replacement stereogram is not present.")
			} else {
				assert(false, "Failed to create stereogram.")
			}
		}
	}

	func testCopyToCameraRoll() {
		// I'm not testing this as it would fill up my camera roll.
		// I don't think I can retrieve pictures from there. So just do nothing in this test.
	}

	//    func testPerformanceExample() {
	//        // This is an example of a performance test case.
	//        self.measureBlock() {
	//            // Put the code you want to measure the time of here.
	//        }
	//    }

}
