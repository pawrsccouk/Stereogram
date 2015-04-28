//
//  Stereogram_iPadTests.swift
//  Stereogram-iPadTests
//
//  Created by Patrick Wallace on 11/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit
import XCTest

class PhotoStore_Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // Delete the temporary directory in case any previous test left it behind.
        deleteTempDirectory()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        // Delete the temporary directory in case any previous test left it behind.
        deleteTempDirectory()
    }
    
    private let _tmpdirName = "Photostore Temp Empty Directory"
    private let _fileManager = NSFileManager.defaultManager()
    private class func getBundle() -> NSBundle {
        return NSBundle(forClass: PhotoStore_Tests.self)
    }
    private lazy var _bundle = PhotoStore_Tests.getBundle()
    private let _leftImage  : UIImage! = UIImage(named: "LeftImage" , inBundle: PhotoStore_Tests.getBundle(), compatibleWithTraitCollection: nil)
    private let _rightImage : UIImage! = UIImage(named: "RightImage", inBundle: PhotoStore_Tests.getBundle(), compatibleWithTraitCollection: nil)
    
    private func createEmptyDirectory() -> NSURL? {
        if let path = NSTemporaryDirectory(),
            tmpdirURL = NSURL(fileURLWithPath: path, isDirectory: true)
        {
            var error: NSError?
            let newDirURL = tmpdirURL.URLByAppendingPathComponent(_tmpdirName)
            if _fileManager.createDirectoryAtURL(newDirURL
                ,   withIntermediateDirectories:false
                ,                    attributes:nil
                ,                         error:&error) {
                    return newDirURL
            } else {
                NSLog("Unit test: Error \(error) creating temp directory \(newDirURL)")
            }
        }
        return nil
    }
    
    private func deleteTempDirectory() -> Bool {
        if let
            path      = NSTemporaryDirectory(),
            tmpdirURL = NSURL(fileURLWithPath: path, isDirectory: true) {
                let mydirURL = tmpdirURL.URLByAppendingPathComponent(_tmpdirName)
                var error: NSError?
                if !_fileManager.removeItemAtURL(mydirURL, error: &error) {
                    return false
                }
        }
        return true
    }
    
    private let BUNDLE_EMPTY_DIRECTORY = "PhotoStore Empty Directory"
    
    /// Test that the store initializes with an empty directory
    func testInitEmptyDirectory() {
        var error: NSError?
        if let
            rootDir    = _bundle.URLForResource(BUNDLE_EMPTY_DIRECTORY, withExtension: nil),
            photoStore = PhotoStore(rootDirectory:rootDir, error:&error) {
                XCTAssertEqual(photoStore.count, 0, "Invalid no. of stereograms \(photoStore.count) should be 0")
        } else {
            XCTFail("Failed to create photo store.")
        }
    }
    
    /// Test the store initializes with an existing directory with exactly 1 entry and finds the entry.
    func testInitExistingDirectory_1Stereogram() {
        var error: NSError?
        if let
            folder1URL = _bundle.URLForResource("PhotoStore 1 Directory", withExtension: nil),
            photoStore = PhotoStore(rootDirectory:folder1URL, error: &error) {
                XCTAssertEqual(photoStore.count, 1, "Invalid no. of stereograms \(photoStore.count) should be 1")
            }
        else {
            XCTFail("Failed to create photo store.")
        }
    }
    
    /// Test the store initializes with an existing directory with exactly 2 entries and finds them.
    func testInitExistingDirectory_2Stereograms() {
        var error: NSError?
        if let
            folder1URL = _bundle.URLForResource("PhotoStore 2 Directory", withExtension: nil),
            photoStore = PhotoStore(rootDirectory:folder1URL, error: &error) {
                XCTAssertEqual(photoStore.count, 2, "Invalid no. of stereograms \(photoStore.count) should be 2")
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
                XCTAssertNotNil(error, "PhotoStore setup with URL \(badDirURL) failed but didn't set an error.")
                NSLog("Photostore failed to setup and gave error \(error)")
            }
        }
    }
    
    private func makeEmptyDirectory() -> NSURL? {
        if let
            tmpDir = NSTemporaryDirectory(),
            tmpURL = NSURL(fileURLWithPath: tmpDir, isDirectory: true),
            srcURL = _bundle.URLForResource(BUNDLE_EMPTY_DIRECTORY, withExtension: nil) {
                let newDir = tmpURL.URLByAppendingPathComponent(_tmpdirName)
                var error: NSError?
                let result = _fileManager.copyItemAtURL(srcURL, toURL: newDir, error: &error)
                assert(result, "File Manager copy from \(srcURL) to \(newDir) failed with error \(error)")
                return newDir
        }
        return nil // Copy failed.
    }
    
    /// Test adding one stereogram (as UIImages) creates it in the right place.
    func testAddOneStereogram() {
        var error: NSError?
        if let
            newDirURL = makeEmptyDirectory(),
            photoStore = PhotoStore(rootDirectory: newDirURL, error: &error) {
                assert(photoStore.count == 0, "Invalid photo store.")
                
                let sgm = addStereogram(newDirURL, photoStore: photoStore)
                
                XCTAssertEqual(photoStore.count, 1, "Photo Store \(photoStore) has \(photoStore.count) stereograms.")
                XCTAssert(URLContainsSubdirs(newDirURL, numSubdirs: 1), "Stereogram created in wrong place.")
                XCTAssert(stereogramIsInArray(sgm, seq: photoStore), "Stereogram is not in the photo store after addition.")
        } else {
            assert(false, "Failed to set up unit test.")
        }
    }
    
    /// Ensures that adding a stereogram to a photoStore looking over an existing directory doesn't break anything.
    func testAddMultipleStereograms() {
        var error: NSError?
        if let
            leftImage = _leftImage, rightImage = _rightImage,
            newDirURL = makeEmptyDirectory(),
            photoStore = PhotoStore(rootDirectory: newDirURL, error: &error) {
                assert(photoStore.count == 0, "Invalid photo store.")
                
                addStereogram(newDirURL, photoStore: photoStore)
                addStereogram(newDirURL, photoStore: photoStore)
                addStereogram(newDirURL, photoStore: photoStore)
                
                XCTAssertEqual(photoStore.count, 3, "Photo Store \(photoStore) has \(photoStore.count) stereograms.")
                XCTAssert(URLContainsSubdirs(newDirURL, numSubdirs: 3), "Stereograms created in wrong place.")
        } else {
            assert(false, "Couldn't set up unit test.")
        }
    }
    
    private func stereogramIsInArray(stereogram :Stereogram, seq: PhotoStore) -> Bool {
        // Now check the stereograms.
        for existingStereogram in seq {
            if existingStereogram == stereogram {
                return true
            }
        }
        return false
    }

    func testRemoveOneStereogram() {
        var error: NSError?
        if let
            newDirURL = makeEmptyDirectory(),
            photoStore = PhotoStore(rootDirectory: newDirURL, error: &error) {
                addStereogram(newDirURL, photoStore: photoStore)
                assert(URLContainsSubdirs(newDirURL, numSubdirs: 1), "addStereogram failed.")
                // Now add 2 steregrams and test we can remove one.
                // I add twice to avoid anything where the 'last' created stereogram is cached somewhere, I want to do a 'real' delete.
                switch photoStore.createStereogramFromLeftImage(_leftImage, rightImage: _rightImage) {
                case .Error(let e):
                    assert(false, "Error setting up test: \(e)")
                    
                case .Success(let stereogram):
                    
                    NSLog("Created stereogram %@", stereogram.value)
                    
                    assert(URLContainsSubdirs(newDirURL, numSubdirs: 2), "createStereogramFrom... failed.")
                   
                    addStereogram(newDirURL, photoStore: photoStore)
                    assert(URLContainsSubdirs(newDirURL, numSubdirs: 3), "createStereogramFrom... failed.")
                    assert(stereogramIsInArray(stereogram.value, seq: photoStore), "add failed when testing remove.")

                    
                    switch photoStore.deleteStereogram(stereogram.value) {
                    case .Error(let e):
                        XCTFail("Error deleting stereogram: \(e)")
                    case .Success():
                        XCTAssert(!stereogramIsInArray(stereogram.value, seq: photoStore), "The stereogram was not removed.")
                        XCTAssert(URLContainsSubdirs(newDirURL, numSubdirs: 2), "Should be 2 stereograms after the deletion.")
                    }
                }
                
                
        }
    }
    
    /// Asserts that the directory under URL contains the number of sub-directories in NUMSUBDIRS.
    /// 
    /// Makes no assumptions about any non-directory contents under the URL, just counts the directories.
    private func URLContainsSubdirs(url: NSURL, numSubdirs: Int) -> Bool {
        var error: NSError?
        let fileArray = _fileManager.contentsOfDirectoryAtURL(
            url
            , includingPropertiesForKeys:nil
            , options:.SkipsHiddenFiles
            , error:&error)
        assert(fileArray != nil, "Error searching test directory: \(error)")
        var numStereograms = fileArray!.filter { self._fileManager.URLIsDirectory($0 as! NSURL) }.count
        return numStereograms == numSubdirs
    }
    
    private func addStereogram(url: NSURL, photoStore: PhotoStore) -> Stereogram! {
        var error: NSError?
        if let stereogram = Stereogram(leftImage: _leftImage, rightImage: _rightImage, baseURL: url, error: &error) {
            photoStore.addStereogram(stereogram)
            return stereogram
        }
        else {
            assert(false, "Failed to create stereogram with error \(error)")
        }
    }
    
    
    
//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        self.measureBlock() {
//            // Put the code you want to measure the time of here.
//        }
//    }
    
}
