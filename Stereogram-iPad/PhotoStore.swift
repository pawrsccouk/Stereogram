//
//  PhotoStore.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 11/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit


// MARK: Error domain and codes for the Photo Store.

public enum ErrorDomain: String { case PhotoStore = "PhotoStore" }

public enum ErrorCode : Int {
    case UnknownError             =   1,
         CouldntCreateSharedStore = 100,
         CouldntLoadImageProperties    ,
         IndexOutOfBounds              ,
         CouldntCreateStereogram
}

// How the stereogram should be viewed.
public enum ViewMode {
    case Crosseyed,   // Adjacent pictures, view crosseyed.
         Walleyed,         // Adjacent pictures, view wall-eyed
         RedGreen,         // Superimposed pictures, use red green glasses.
         RandomDot         // "Magic Eye" format.
}



private var _singleInstance: PhotoStore!

public class PhotoStore {
    
    public init? (inout error: NSError?) {
        // Create the photo folder. Log an error if it fails and abort.
        switch photoFolder() {
        case .Success(let p):
            photoFolderPath = p.value
        case .Error(let e):
            NSLog("Error creating photo folder: \(e)")
            error = e
            return nil
        }
        
        switch loadProperties() {
        case .Success(let p):
            imageProperties = p.value
        case .Error(let e):
            error = e
            return nil
        }
    }
    
    
    // Size of a thumbnail in pixels.  Thumbnails are square, so this is the width and the height of it.
    let thumbnailSize = 100
    

    // MARK: - Image Storage
    
    // Number of images stored in here.
    var count: Int {
        return imageProperties.count
    }
    
    // Attempts to add the image to the store. dateTaken is when the original photo was taken, which is added to the properties.
    func addImage(image: UIImage, dateTaken: NSDate) -> Result {
        if let fileData = UIImageJPEGRepresentation(image, 1.0) {
            let filePath = getUniqueFilename(photoFolderPath)
            var error: NSError?
            if !fileData.writeToFile(filePath, options: .DataWritingAtomic, error: &error) {
                if error == nil { error = defaultError }
                return .Error(error!)
            }
            imageProperties[filePath] = [.DateTaken : dateTaken]
            self.addThumbnailToCache(key: filePath)(image: image)
            return .Success()
        }
        let userInfo = [NSLocalizedDescriptionKey : "Unable to add the image - the image is corrupt."]
        return .Error(NSError(domain: ErrorDomain.PhotoStore.rawValue, code: ErrorCode.CouldntCreateSharedStore.rawValue, userInfo: userInfo))
    }
    
    
    // Retrieves the image in the collection which is at index position <index> or an error if it is not found.
    func imageAtIndex(index: UInt) -> ResultOf<UIImage> {
        return imageFromFile(thumbnailPaths[Int(index)])
    }
    
    // Like imageAtIndex but receives a smaller thumbnail image.
    func thumbnailAtIndex(index: UInt) -> ResultOf<UIImage> {
        let path = thumbnailPaths[Int(index)]
        if let propertyDict = imageProperties[path] {
            if let thumb = propertyDict[PropertyKey.Thumbnail] as? UIImage {
                return ResultOf(thumb) // Success, return the cached image.
            }
        }
        // If the thumbnail was not already cached, create it and return it now.
        return imageFromFile(path).map(
            addThumbnailToCache(key: path))
    }
    
    
    // Deletes the images at the specified index paths.
    func deleteImagesAtIndexPaths(paths: [NSIndexPath]) -> Result {
        return eachOf(paths.map{ self.thumbnailPaths[$0.item]}) { (index, path) -> Result in
            var error: NSError?
            if !self.fileManager.removeItemAtPath(path, error: &error) {
                if error == nil { error = self.defaultError }
                return .Error(error!)
            }
            self.imageProperties.removeValueForKey(path)
            return .Success()
       }
    }
 
    // Overwrites the image at the given position with a new image.
    // Returns an error if there is no image at index already.
    func replaceImageAtIndex(index: UInt, withImage newImage: UIImage) -> Result {
        let filePath = thumbnailPaths[Int(index)]
        let fileData = UIImageJPEGRepresentation(newImage, 1.0)
        var error: NSError?
        if !fileData.writeToFile(filePath, options: .DataWritingAtomic, error: &error) {
            if error == nil { error = defaultError }
            return .Error(error!)
        }
        // Update the thumbnail to display the new image.
        return addThumbnailToCache(key: filePath)(image: newImage).result
     }

    // MARK: Image manipulation
    
    // Copies the image at position <index> into the camera roll.
    func copyImageToCameraRoll(index: UInt) -> Result {
        return imageAtIndex(index).map0(alwaysOk{ UIImageWriteToSavedPhotosAlbum($0, nil, nil, nil) })
    }
    
    
    // Compose the two photos given to make a stereogram.
    func makeStereogramWithLeftPhoto(leftPhoto: UIImage, rightPhoto: UIImage) -> ResultOf<UIImage> {
        assert(leftPhoto.scale == rightPhoto.scale, "Image scales \(leftPhoto.scale) and \(rightPhoto.scale) must be the same.")
        let stereogramSize = CGSizeMake(leftPhoto.size.width + rightPhoto.size.width, max(leftPhoto.size.height, rightPhoto.size.height))
        
        var stereogram: UIImage?
        UIGraphicsBeginImageContextWithOptions(stereogramSize, false, leftPhoto.scale)
        // try
        leftPhoto.drawAtPoint(CGPointZero)
        rightPhoto.drawAtPoint(CGPointMake(leftPhoto.size.width, 0))
        stereogram = UIGraphicsGetImageFromCurrentImageContext()
        // finally
        UIGraphicsEndImageContext()

        if let s = stereogram {
            return ResultOf(s)
        }
        return .Error(NSError(domain: ErrorDomain.PhotoStore.rawValue, code: ErrorCode.CouldntCreateStereogram.rawValue, userInfo: nil))
    }
    

    // Toggles the viewing method from crosseye to walleye and back for the image at position <index>.
    func changeViewingMethod(index: UInt) -> Result {
        
        let swapImageHalves = { (img: UIImage) -> ResultOf<UIImage> in
            return and( self.getHalfOfImage(img, whichHalf: .LeftHalf), self.getHalfOfImage(img, whichHalf: .RightHalf) )
            .map( { (leftImage,rightImage) in return self.makeStereogramWithLeftPhoto(rightImage, rightPhoto: leftImage) } )
        }
        
        return imageAtIndex(index)
            .map( swapImageHalves )
            .map0 { (swappedImage: UIImage) -> Result in return self.replaceImageAtIndex(index, withImage: swappedImage) }
    }
    
    
    // Save the image property file.
    func saveProperties() -> Result {
        
        // Make a copy of the properties dict which does not include the thumbnails, converting the type from a Swift dict to an NSDictionary
        var propertyArrayToSave = NSMutableDictionary()
        for (filePath, imgPropertyDict)  in imageProperties {
            let newProperties = NSMutableDictionary()
            for (k,v) in imgPropertyDict {
                if k != .Thumbnail {
                    newProperties.setValue(v, forKey: k.rawValue)
                }
            }
            propertyArrayToSave.setValue(newProperties, forKey: filePath)
        }
        
        // Add a version number in case I change the format.
        let masterProperties = NSMutableDictionary(object: NSNumber(integer: 1), forKey: PropertyKey.Version.rawValue)
        propertyArrayToSave.setValue(masterProperties, forKey: MasterPropertyKey.Version.rawValue)
        
        // Save the data, and return an error if it went wrong.
        if propertyArrayToSave.writeToFile(propertiesFilePath, atomically: true) {
            return .Success()
        }
        let userInfo = [NSLocalizedDescriptionKey : "Couldn't save the properties file at [\(propertiesFilePath)"]
        return .Error(NSError(domain: ErrorDomain.PhotoStore.rawValue, code: ErrorCode.CouldntLoadImageProperties.rawValue, userInfo: userInfo))
    }

    private func loadProperties() -> ResultOf<MasterPropertyDict> {
        // Load the image properties and then compare them to the actual images, adding or removing entries until they match.
        return and(loadImageProperties(propertiesFilePath), loadImageFilenames(photoFolderPath)).map { (tuple) -> ResultOf<MasterPropertyDict> in
            var (allProperties, filesystemFilenames) = tuple
            let allFilenames: [FileName] = allProperties.keys.array
            let propertyFilenames = Set<FileName>(array: allFilenames)
            
            // Remove entries in propertyFilenames which are not in the file system.
            let filesToRemove = propertyFilenames.filter {  !filesystemFilenames.contains($0) }
            for file in filesToRemove {
                allProperties[file] = nil
            }
            
            // Add any entries in the filesystem which are not in the property list.
            let filesToAdd = filesystemFilenames.filter { !propertyFilenames.contains($0) }
            for file in filesToAdd {
                allProperties[file] = PropertyDict()
            }
            return ResultOf(allProperties)
        }
    }
    
    // MARK: - Private Data
    
    // Dictionary of properties for each image.
    
    // Keys for the image properties.
    private enum PropertyKey: String {
        // Keys for the individual image property dicts.
    case Orientation   = "Orientation",     // Portrait or Landscape.
         Thumbnail     = "Thumbnail",       // Image thumbnail.
         DateTaken     = "DateTaken",       // Date original photo was taken.
         ViewMode      = "ViewMode"         // Crosseyed, Walleyed, Red/Green, Random-dot
        // Keys for the master property dict.
        case Version = "Version"            // Version number of this file.
    }
    private typealias PropertyDict = [PropertyKey : AnyObject]
    
    // Properties are stored in a master dictionary, keyed by file path - the full path to the image's file.
    // Extra master-specific entries are stored using fake keys stored in the MasterPropertyKey enum.
    
    private typealias FileName = String
    private enum MasterPropertyKey: FileName { case Version = "Version" }
    private typealias MasterPropertyDict = [FileName : PropertyDict]
    private var imageProperties = MasterPropertyDict()
    
    // A file manager object to use for loading and saving.
    private let fileManager = NSFileManager.defaultManager()
    
    // Path to where we are keeping the photos.
    private var photoFolderPath: String!
    
    // Path to the properties file for the photos.
    private var propertiesFilePath: String {
        let folders = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        assert(!folders.isEmpty, "No document directory specified.")
        return folders[0].stringByAppendingPathComponent("Properties")
    }
    
    // Array of paths to image thumbnails.
    private var thumbnailPaths: [FileName] {
        return sorted(imageProperties.keys)
    }
    
    // A default error to return if the OS doesn't provide one. Nothing we can do in that case, as we have no idea what went wrong.
    private let defaultError = NSError(domain: ErrorDomain.PhotoStore.rawValue, code: ErrorCode.UnknownError.rawValue, userInfo: [NSLocalizedDescriptionKey : "Unknown error"])
    
    // Should be called once during setup, to create the photos folder if it doesn't already exists.
    // Returns the folder path once set up.
    
    private func photoFolder() -> ResultOf<String> {
        let folders = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let photoDir = folders[0].stringByAppendingPathComponent("Pictures") as String
        
        var isDirectory = UnsafeMutablePointer<ObjCBool>.alloc(1)
        isDirectory.initialize(ObjCBool(false))
        let fileExists = fileManager.fileExistsAtPath(photoDir, isDirectory: isDirectory)
        if fileExists && isDirectory.memory {
            return ResultOf(photoDir)
        }
        
        // If the directory doesn't exist, then let the file manager try and create it.
        var error: NSError?
        if fileManager.createDirectoryAtPath(photoDir, withIntermediateDirectories:false, attributes:nil, error:&error) {
            return ResultOf(photoDir)
        }
        else {
            if error == nil { error = defaultError }
            return .Error(error!)
        }
    }

    // Return a filename which should not already be used. I do this by creating a GUID for the name part.
    private func getUniqueFilename(photoDir: String) -> String {
        let newUIDString = CFUUIDCreateString(kCFAllocatorDefault, CFUUIDCreate(kCFAllocatorDefault))
        var filePath = photoDir.stringByAppendingPathComponent(newUIDString).stringByAppendingString(".jpg")
        assert(!fileManager.fileExistsAtPath(filePath)) // Name should be unique so no photo should exist yet.
        return filePath
    }
    
    // Function to return half an image.
    private enum WhichHalf { case RightHalf, LeftHalf }
    private func getHalfOfImage(image: UIImage,  whichHalf: WhichHalf) -> ResultOf<UIImage> {
        let rectToKeep = (whichHalf == .LeftHalf)
            ? CGRectMake(0, 0, image.size.width / 2.0, image.size.height)
            : CGRectMake(image.size.width / 2.0, 0, image.size.width / 2.0, image.size.height )
        
        let imgPartRef = CGImageCreateWithImageInRect(image.CGImage, rectToKeep)
        if let i = UIImage(CGImage:imgPartRef) { return ResultOf(i) }
        let userInfo = [NSLocalizedDescriptionKey : "Unable to create thumbnail. Unknown error."]
        return .Error(NSError(domain: ErrorDomain.PhotoStore.rawValue, code: ErrorCode.UnknownError.rawValue, userInfo: userInfo))
    }
    
    // Load an image from the file path specified.
    private func imageFromFile(filePath: String) -> ResultOf<UIImage> {
        let exists = fileManager.fileExistsAtPath(filePath)
        assert(exists, "filePath [\(filePath)] does not point to a file.")
        var error: NSError?
        
        let data = NSData(contentsOfFile:filePath, options:.allZeros, error:&error)
        if data == nil {
            if error == nil { error = defaultError }
            return .Error(error!)
        }
        
        let img = UIImage(data:data!)
        let userInfo = [NSLocalizedDescriptionKey : "Unable to create the image from the data in the stored file."]
        if img == nil { return .Error(NSError(domain: ErrorDomain.PhotoStore.rawValue, code: ErrorCode.CouldntLoadImageProperties.rawValue, userInfo: userInfo)) }
        
        return ResultOf(img!)
    }
 
    // Create a thumbnail for the image provided and add it to the thumbnail cache under the specified key.
    // Returns the thumbnail if successful.
    private func addThumbnailToCache(#key: String)(#image: UIImage) -> ResultOf<UIImage> {
        // Use the left half of the image for the thumbnail, as having both makes the actual image content too small to see.
        return getHalfOfImage(image, whichHalf: .LeftHalf).map { leftHalf in
            let thumbnail = leftHalf.thumbnailImage(thumbnailSize: self.thumbnailSize, transparentBorderSize: 0, cornerRadius: 0, interpolationQuality: kCGInterpolationLow)
            var properties: PropertyDict! = self.imageProperties[key]
            if properties == nil {
                properties = PropertyDict()
                self.imageProperties[key] = properties!
            }
            properties[.Thumbnail] = thumbnail
            return ResultOf(thumbnail)
        }
    }
    
    private func loadImageProperties(path: String) -> ResultOf<[FileName : PropertyDict]> {
        let nsDictionary = NSDictionary(contentsOfFile: path)
        // If we have a dictionary, check the version is valid.
        let INVALID_VERSION = -1.0
        var version = INVALID_VERSION
        if let dict = nsDictionary {
            if let propDict = dict[MasterPropertyKey.Version.rawValue] as? NSDictionary {
                if let versionObject = propDict[PropertyKey.Version.rawValue] as? NSNumber {
                    version = versionObject.doubleValue
                }
            }
            assert(version == 1.0, "Invalid data version \(version)")
            
            // Copy the NSDictionary contents into a [FileName : PropertyDict] dictionary.
            // TODO: Implement proper load/save routines for the dictionary.
            // This is a hack.  Load as an NSDictionary, then copy the values across.
            var result = [FileName : PropertyDict]()
            for (key, subDict) in dict {
                var subResult = PropertyDict()
                for (subKey, subValue) in (subDict as NSDictionary) {
                    if let propertyKey = PropertyKey(rawValue: subKey as String) {
                        subResult[propertyKey] = subValue
                    } else {
                        let errorMessage = "The string [\(subKey)] is not a valid property list key"
                        return .Error(NSError(domain: ErrorDomain.PhotoStore.rawValue, code: ErrorCode.CouldntLoadImageProperties.rawValue, userInfo: [NSLocalizedDescriptionKey : errorMessage]))
                    }
                }
                result[key as FileName] = subResult
            }
            return ResultOf(result)
        }
        return ResultOf([FileName : PropertyDict]())
    }
    
    
    // Return all the filenames in the image directory.
    private typealias FilenameSet = Set<FileName>
    private func loadImageFilenames(folderPath: String) -> ResultOf<FilenameSet> {
        var error: NSError?
        if let fileNames = fileManager.contentsOfDirectoryAtPath(folderPath, error: &error) as? [String] {
            let fullNames = fileNames.map { folderPath.stringByAppendingPathComponent($0) }
            return ResultOf(FilenameSet(array: fullNames))
        } else {
            if error == nil {
                let userInfo = [NSLocalizedDescriptionKey : "Unknown error reading directory [\(folderPath)]"]
                error = NSError(domain: ErrorDomain.PhotoStore.rawValue, code: ErrorCode.CouldntLoadImageProperties.rawValue, userInfo: userInfo)
            }
            return .Error(error!)
        }
    }
    

    
    
}
