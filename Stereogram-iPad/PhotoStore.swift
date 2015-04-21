//
//  PhotoStore.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 11/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit


// MARK: Error domain and codes for the Photo Store.

/// The error domain for errors returned when accessing the photo store.
public enum ErrorDomain: String { case PhotoStore = "PhotoStore" }

/// A list of error codes indicating what went wrong.
///
/// - UnknownError : Something failed but didn't say why.
/// - CouldntCreateSharedStore   : Error creating the main stereogram pictures store.
/// - CouldntLoadImageProperties : Error loading properties for an image
/// - IndexOutOfBounds           : Invalid index into the photo-store collection.
/// - CouldntCreateStereogram    : Error creating the stereogram object
/// - InvalidFileFormat          : A problem was found with the format of a stereogram object.
public enum ErrorCode : Int {
    case UnknownError             =   1,
         CouldntCreateSharedStore = 100,
         CouldntLoadImageProperties    ,
         IndexOutOfBounds              ,
         CouldntCreateStereogram       ,
         InvalidFileFormat
}

/// Stores a collection of Stereogram objects.
public class PhotoStore {
    
    /// Designated initializer. Attempts to create the store and returns an error if it fails.
    ///
    /// :param: error - An error object which holds the issue if the constructor fails.
    public init? (inout error: NSError?) {
        // Create the photo folder. Log an error if it fails and abort.
        switch PhotoStore.createPhotoFolderURL() {
        case .Success(let p):
            _photoFolderURL = p.value
        case .Error(let e):
            NSLog("Error creating photo folder: \(e)")
            error = e
            _photoFolderURL = NSURL()
            return nil
        }
        // Now find and load all the streograms under that URL.
        switch Stereogram.allStereogramsUnderURL(_photoFolderURL) {
        case .Success(let result):
            _stereograms = result.value
        case .Error(let err):
            error = err
            return nil
        }
    }
    

    // MARK: - Stereogram Storage
    
    /// Number of stereograms stored in here.
    var count: Int {
        return _stereograms.count
    }
    
    /// Create a new stereogram on disk using the images provided, then add it to the collection and return it
    ///
    /// :param: leftImage - The left-hand image
    /// :param: rightImage - The right-hand image
    /// :returns: A Stereogram object on success, or an error on failure
    func createStereogramFromLeftImage(leftImage: UIImage, rightImage: UIImage) -> ResultOf<Stereogram> {
        let result = Stereogram.stereogramFromLeftImage(leftImage, rightImage: rightImage, baseURL: _photoFolderURL)
        switch result {
        case .Success(let s):
            addStereogram(s.value)
        default: break
        }
        return result
    }
    
    /// Adds a stereogram to the collection.
    ///
    /// The stereogram will not be added if it already exists in the collection.
    ///
    /// :param: stereogram - The stereogram to add.
    func addStereogram(stereogram: Stereogram) {
        if !contains(_stereograms, stereogram) {
            _stereograms.append(stereogram)
        }
    }
    
    
    /// Retrieves a stereogram from the collection
    ///
    /// :param: index - The index of the stereogram to return.
    /// :returns: The stereogram if present or an error if not.
    func stereogramAtIndex(index: Int) -> Stereogram {
        return _stereograms[index]
    }
    
    
    /// Deletes multiple stereograms from the collection.
    ///
    /// :param: paths - An array of NSIndexPath object indicating which stereograms to delete.
    /// :returns: Success or Error with the NSError object attached.
    ///
    /// NB: As soon as an error is detected, this method stops immediately. No cleanup or rollback actions are performed.
    func deleteStereogramsAtIndexPaths(paths: [NSIndexPath]) -> Result {
        let stereogramsToDelete = paths.map { indexPath  in self._stereograms[indexPath.item] }
        
        return eachOf(stereogramsToDelete) { (index, stereogram) -> Result in
            return self.deleteStereogram(stereogram)
        }
    }
    
    /// Deletes a single stereogram from the collection.
    ///
    /// :param: stereogram - The stereogram to remove.
    /// :returns: Success or an error if the operation faied.
    ///
    /// This deletes the stereogram data from the disk as well as removing it from the current collection. 
    /// Once completed, this stereogram object is then invalid.
    func deleteStereogram(stereogram: Stereogram) -> Result {
        assert(contains(_stereograms, stereogram), "Array \(_stereograms) doesn't contain \(stereogram)")
        let result = stereogram.deleteFromDisk()
        if result.success {  // Remove the stereogram from the list.
            _stereograms = _stereograms.filter { sg in sg != stereogram }
        }
        return result
    }
 
    /// Overwrites the image at the given position with a new image.
    ///
    /// :param: index - The index of the stereogram to replace in the collection.
    /// :param: stereogram - The new stereogram replacing the one at index.
    /// :returns: An error if there is no image at index already, or if the replacement failed. Otherwise success.
    ///
    /// NB: This deletes the old stereogram from the disk as well as removing it from the collection. 
    /// The stereogram object is invalid after this method returns successfully.
    func replaceStereogramAtIndex(index: Int, withStereogram newStereogram: Stereogram) -> Result {
        let stereogramToGo = _stereograms[index]
        if stereogramToGo != newStereogram {
            let result = stereogramToGo.deleteFromDisk()
            if !result.success {
                return result
            }
            _stereograms[index] = newStereogram
        }
        return .Success()
    }
    
    // MARK: Actions
    
    /// Copies a stereogram into the device's camera roll.
    ///
    /// :param: index - Index of the image to copy.
    /// :returns: Success or an error indicating what went wrong.
    func copyStereogramToCameraRoll(index: Int) -> Result {
        let stereogram = _stereograms[index]
        return stereogram.stereogramImage().map0( alwaysOk {
            UIImageWriteToSavedPhotosAlbum($0, nil, nil, nil)
        })
    }
   
    // MARK: - Private Data
    
    /// Array of the stereogram objects we are storing.
    private var _stereograms = [Stereogram]()
    
    /// Path to where we are keeping the photos.
    private let _photoFolderURL: NSURL
    
    
    /// Creates the global photos folder if it doesn't already exist.
    ///
    /// :returns: The folder path once set up.
    ///
    /// You should call this only once during setup.
    private class func createPhotoFolderURL() -> ResultOf<NSURL> {
        let fileManager = NSFileManager.defaultManager()
        let folders = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        if let
            firstObject: String = folders[0] as? String,
            rootURL = NSURL(fileURLWithPath:firstObject, isDirectory: true) {
                let photoDir = rootURL.URLByAppendingPathComponent("Pictures")
                if PhotoStore.urlIsDirectory(photoDir) {
                    return ResultOf(photoDir)
                } else {
                    // If the directory doesn't exist, then let the file manager try and create it.
                    var error: NSError?
                    if fileManager.createDirectoryAtURL(photoDir, withIntermediateDirectories:false, attributes:nil, error:&error) {
                        return ResultOf(photoDir)
                    } else {
                        return .Error(error!)
                    }
                }
        }
        return .Error(NSError.unknownError("createPhotoFolderURL"))
    }
    
    /// Returns true if url exists and points to a directory.
    ///
    /// :param: url - A file URL to test.
    /// :returns: True if url is a directory, False otherwise.
    private class func urlIsDirectory(url: NSURL) -> Bool {
        var isDirectory = UnsafeMutablePointer<ObjCBool>.alloc(1)
        isDirectory.initialize(ObjCBool(false))
        let fileManager = NSFileManager.defaultManager()
        if let path = url.path {
            let fileExists = fileManager.fileExistsAtPath(url.path!, isDirectory:isDirectory)
            let isDir = isDirectory.memory
            return fileExists && isDir
        }
        return false
    }
    
}
