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
/// - UnknownError               : Something failed but didn't say why.
/// - CouldntCreateSharedStore   : Error creating the main stereogram pictures store.
/// - CouldntLoadImageProperties : Error loading properties for an image
/// - IndexOutOfBounds           : Invalid index into the photo-store collection.
/// - CouldntCreateStereogram    : Error creating the stereogram object
/// - InvalidFileFormat          : A problem was found with the format of a stereogram object.
/// - FileNotFound               : One of the internal files that make up a stereogram is missing.
/// - FeatureUnavailable         : The device does not support a requested feature.

public enum ErrorCode: Int {
    case UnknownError             =   1

    case CouldntCreateSharedStore = 100,
         CouldntLoadImageProperties    ,
         IndexOutOfBounds              ,
         CouldntCreateStereogram       ,
         InvalidFileFormat             ,
         FileNotFound                  ,
         FeatureUnavailable
}

/// Stores a collection of Stereogram objects.
public class PhotoStore: SequenceType {

    public struct Generator: GeneratorType {
        public typealias Element = Stereogram
        var array: [Stereogram]
        var index: Int

        // MARK: Initializers
        init(array: [Stereogram]) {
            self.array = array
            index = array.startIndex
        }
        // MARK: Methods
        mutating public func next() -> Element? {
            var st: Stereogram?
            if index < array.endIndex {
                st = array[index++]
            }
            return st
        }
    }


    // MARK: - Initializers

    /// Designated initializer. Attempts to create the store and returns an error if it fails.
    ///
    /// :param: rootDirectory - File URL to a directory which will hold the stereograms.
    /// :param: error - An error object which holds the issue if the constructor fails.

    public init? (rootDirectory: NSURL, inout error: NSError?) {


        photoFolderURL = rootDirectory

        // Ensure _photoFolderURL is a valid folder URL.
        if !NSFileManager.defaultManager().urlIsDirectory(photoFolderURL) {
            error = NSError(errorCode: ErrorCode.CouldntCreateSharedStore, userInfo: [
                NSFilePathErrorKey        : rootDirectory,
                NSLocalizedDescriptionKey : "Couldn't open directory."])
            return nil
        }

        // Now find and load all the streograms under that URL.
        switch Stereogram.allStereogramsUnderURL(photoFolderURL) {
        case .Success(let result):
            stereograms = result.value
        case .Error(let err):
            error = err
            return nil
        }
    }


    // MARK: Stereogram Storage

    /// Number of stereograms stored in here.
    var count: Int {
        return stereograms.count
    }

    /// Function returning a generator, so you can use this object in foreach loops.
    public func generate() -> Generator {
        return Generator(array: stereograms);
    }



    /// Create a new stereogram on disk using the images provided,
    /// then add it to the collection and return it
    ///
    /// :param: leftImage - The left-hand image
    /// :param: rightImage - The right-hand image
    /// :returns: A Stereogram object on success, or an error on failure
    func createStereogramFromLeftImage(leftImage: UIImage
		,                             rightImage: UIImage) -> ResultOf<Stereogram> {
        var error: NSError?
        if let stereogram = Stereogram(leftImage: leftImage
			,                         rightImage: rightImage
			,                            baseURL: photoFolderURL
			,                              error: &error) {
            addStereogram(stereogram)
            return ResultOf(stereogram)
        }
        return .Error(error!)
    }

    /// Adds a stereogram to the collection.
    ///
    /// The stereogram will not be added if it already exists in the collection.
    ///
    /// :param: stereogram - The stereogram to add.
    func addStereogram(stereogram: Stereogram) {
        if !contains(stereograms, stereogram) {
            stereograms.append(stereogram)
        }
    }


    /// Retrieves a stereogram from the collection
    ///
    /// :param: index - The index of the stereogram to return.
    /// :returns: The stereogram if present or an error if not.
    func stereogramAtIndex(index: Int) -> Stereogram {
        return stereograms[index]
    }


    /// Deletes multiple stereograms from the collection.
    ///
    /// :param: paths - An array of NSIndexPath object indicating which stereograms to delete.
    /// :returns: Success or Error with the NSError object attached.
    ///
    /// NB: As soon as an error is detected, this method stops immediately.
	/// No cleanup or rollback actions are performed.
    func deleteStereogramsAtIndexPaths(paths: [NSIndexPath]) -> Result {
        let stereogramsToDelete = paths.map { indexPath  in self.stereograms[indexPath.item] }

        return eachOf(stereogramsToDelete) { (index, stereogram) -> Result in
            return self.deleteStereogram(stereogram)
        }
    }

    /// Deletes a single stereogram from the collection.
    ///
    /// :param: stereogram - The stereogram to remove.
    /// :returns: Success or an error if the operation faied.
    ///
    /// This deletes the stereogram from the disk as well as from the current collection.
    /// Once completed, this stereogram object is then invalid.
    func deleteStereogram(stereogram: Stereogram) -> Result {
        assert(contains(stereograms, stereogram)
			,  "Array \(stereograms) doesn't contain \(stereogram)")
        let result = stereogram.deleteFromDisk()
        if result.success {  // Remove the stereogram from the list.
            stereograms = stereograms.filter { sg in sg != stereogram }
        }
        return result
    }

    /// Overwrites the image at the given position with a new image.
    ///
    /// :param: index          - The index of the stereogram to replace in the collection.
    /// :param: stereogram     - The new stereogram replacing the one at index.
    /// :returns: An error if there is no image at index already, or if the replacement failed.
    ///
    /// NB: The stereogram object is invalid after this method returns successfully.
	/// You should not use it once it has been deleted.
    /// If you want to swap the stereogram between Photo stores,
    /// then you will need to physically move the files instead of just the stereogram objects
    /// as each photo store will expect it's stereograms to be located under it's base URL.
    /// So don't use this method for that.

    func replaceStereogramAtIndex(index: Int, withStereogram newStereogram: Stereogram) -> Result {
        let stereogramToGo = stereograms[index]
        if stereogramToGo != newStereogram {
            let result = stereogramToGo.deleteFromDisk()
            if !result.success {
                return result
            }
            stereograms[index] = newStereogram
        }
        return .Success()
    }

    // MARK: Actions

    /// Copies a stereogram into the device's camera roll.
    ///
    /// :param: index - Index of the image to copy.
    /// :returns: Success or an error indicating what went wrong.
    func copyStereogramToCameraRoll(index: Int) -> Result {
        let stereogram = stereograms[index]
        return stereogram.stereogramImage().map0( alwaysOk {
            UIImageWriteToSavedPhotosAlbum($0, nil, nil, nil)
        })
    }

    // MARK: - Private Data

    /// Array of the stereogram objects we are storing.
    private var stereograms = [Stereogram]()

    /// Path to where we are keeping the photos.
    private let photoFolderURL: NSURL
}
