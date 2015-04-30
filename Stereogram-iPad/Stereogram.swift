//
//  Stereogram.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 19/04/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

/// How the stereogram should be viewed.
///
/// - Crosseyed: Adjacent pictures, view crosseyed.
/// -  Walleyed: Adjacent pictures, view wall-eyed
/// -  RedGreen: Superimposed pictures, use red green glasses.
/// -  RandomDot: "Magic Eye" format.
/// -  AnimatedGIF: As a cycling animation.
///
public enum ViewMode: Int {
    case Crosseyed,
    Walleyed,
    RedGreen,
    RandomDot,
    AnimatedGIF
}

private let kViewingMethod = "ViewingMethod"
private let LeftPhotoFileName = "LeftPhoto.jpg", RightPhotoFileName = "RightPhoto.jpg", PropertyListFileName = "Properties.plist"

/// A Stereogram contains URLs to a left and a right image and composites these according to a viewing method.
///
/// The stereogram assumes you have created a new directory with three files in it: 
/// LeftPhoto.jpg, RightPhoto.jpg and Properties.plist. 
/// There are class methods to create this directory structure, and to search a directory for stereogram objects.
///
/// The stereogram normally contains just three URLs to find these resources. When needed, it will load and cache the images.
/// It will also respond to memory-full notifications and clear the images, which can be re-calculated or reloaded later. 
///
/// Calculating the main stereogram image can take time, so you can use the reset method, which will clear all the loaded images and then explicitly reload them all. This can be done in a background thread.
public class Stereogram: NSObject {
    
    //MARK: Public class functions.
    
    /// Find all the stereograms found in the given directory
    ///
    /// :param: url -  A File URL pointing to the directory to search.
    /// :returns: An array of Stereogram objects on success or an NSError on failure.
    
    class func allStereogramsUnderURL(url: NSURL) -> ResultOf<[Stereogram]> {
        let fileManager = NSFileManager.defaultManager()
       
        /// Initialize this object by loading image data from the specified URL.
        ///
        /// :param: url -  A File URL pointing to the root directory of a stereogram object
        /// :returns: A Stereogram object on success or an NSError object on failure.
        
        func stereogramFromURL(url: NSURL) -> ResultOf<Stereogram> {
            // URL should be pointing to a directory. Inside this there should be 3 files: LeftImage.jpg, RightImage.jpg, Properties.plist. Return an error if any of these are missing. Also load the properties file.
            
            /// Checks if a file exists given a base directory URL and filename.
            ///
            /// :param: baseURL The Base URL to look in.
            /// :param: fileName The name of the file to check for.
            /// :returns: .Success if the file was present, .Error(NSError) if it was not.
            
            func fileExists(baseURL: NSURL, fileName: String) -> Result {
                let fullURLPath = baseURL.URLByAppendingPathComponent(fileName).path
                if let fullPath = fullURLPath {
                    if fileManager.fileExistsAtPath(fullPath) {
                        return .Success()
                    }
                }
                let userInfo = [NSFilePathErrorKey : NSString(string: fullURLPath ?? "<no path>")]
                return .Error(NSError(errorCode:.FileNotFound, userInfo: userInfo))
            }
            
            
            
            
            let defaultPropertyDict: PropertyDict = [kViewingMethod : ViewMode.Crosseyed.rawValue]
            
            
            // if any of the files don't exist, then return an error.
            let result = and([
                fileExists(url, LeftPhotoFileName),
                fileExists(url, RightPhotoFileName),
                fileExists(url, PropertyListFileName)])
            if let err = result.error {
                return .Error(err)
            }
            
            // Load the property list at the given URL.
            var propertyList = defaultPropertyDict
            switch loadPropertyList(url.URLByAppendingPathComponent(PropertyListFileName)) {
            case .Success(let propList):
                propertyList = propList.value
            case .Error(let error):
                return .Error(error)
            }
            return ResultOf(Stereogram(baseURL: url, propertyList: propertyList))
        }
        
        
        
        var stereogramArray = [Stereogram]()
        var error: NSError?
        if let
            fileArray = fileManager.contentsOfDirectoryAtURL(url, includingPropertiesForKeys:nil, options:.SkipsHiddenFiles, error:&error),
            fileNames = fileArray as? [NSURL] {
            for stereogramURL in fileNames {
                switch stereogramFromURL(stereogramURL) {
                case .Success(let result):
                    stereogramArray.append(result.value)
                case .Error(let err):
                    return .Error(err)
                }
            }
        }
        return ResultOf(stereogramArray)
    }
    
    
    
    

    // MARK: - Properties
    
    /// The type of the property dictionary.
    typealias PropertyDict = [String : AnyObject]
   
    /// How to view this stereogram. This affects how the image returned by stereogramImage is computed.
    var viewingMethod: ViewMode {
        get {
            var viewMode: ViewMode? = nil
            if let viewingMethodNumber = _propertyList[kViewingMethod] as? NSNumber {
                viewMode = ViewMode(rawValue: viewingMethodNumber.integerValue)
                assert(viewMode != nil, "Invalid value \(viewingMethodNumber)")
            }
            return viewMode ?? .Crosseyed
        }
        set {
            if self.viewingMethod != newValue {
                _propertyList[kViewingMethod] = newValue.rawValue
                savePropertyList()
                // Delete any cached images so they are recreated with the new viewing method.
                _stereogramImage = nil
                _thumbnailImage = nil
            }
        }
    }
    
    /// The MIME type for the image that stereogramImage will generate. 
    ///
    /// This is based on the viewing method. Use to represent the image when saving.
    var mimeType: String {
        return viewingMethod == ViewMode.AnimatedGIF ? "image/gif" : "image/jpeg"
    }
    
    override public var description: String {
        return "\(super.description) <BaseURL: \(baseURL), Properties: \(_propertyList)>"
    }
    
    /// URLs to the base directory containing the images. Used to load the images when needed.
    let baseURL: NSURL
   
    //MARK: Initializers

    /// Initilizes the stereogram from two already-existing images.
    ///
    /// Save the images provided to the disk under a specified directory.
    ///
    /// :param: leftImage  -  The left image in the stereogram.
    /// :param: rightImage -  The right image in the stereogram.
    /// :param: baseURL    -  The URL to save the stereogram under.
    /// :returns: A Stereogram object on success, nil on failure.
    
    public convenience init?(leftImage: UIImage, rightImage: UIImage, baseURL: NSURL, inout error: NSError?) {
        let newStereogramURL = Stereogram.getUniqueStereogramURL(baseURL)
        let propertyList = [String : AnyObject]()
        self.init(baseURL: newStereogramURL, propertyList: propertyList)
        
        switch Stereogram.writeToURL(newStereogramURL, propertyList: propertyList, leftImage: leftImage, rightImage: rightImage) {
        case .Success:
            break
        case .Error(let e):
            error = e
            return nil
        }
    }

    /// Designated Initializer.
    /// Creates a new stereogram object from a URL and a property list.
    ///
    /// :param: baseImageURL File URL pointing to the main directory under which the images are stored.
    /// :param: propertyList A dictionary of default properties for this stereogram
    
    private init(baseURL url: NSURL, propertyList: PropertyDict) {
        baseURL = url
        _propertyList = propertyList
        super.init()
        
        _thumbnailImage = nil
        _stereogramImage = nil
        
        // Notify when memory is low, so I can delete this cache.
        let centre = NSNotificationCenter.defaultCenter()
        centre.addObserver(self, selector:"lowMemoryNotification:", name:UIApplicationDidReceiveMemoryWarningNotification, object:nil)
    }
    
    deinit {
        let centre = NSNotificationCenter.defaultCenter()
        centre.removeObserver(self)
    }
    
    // MARK: Methods
    
    /// Combine leftImage and rightImage according to viewingMethod, loading the images if they are not already available.
    ///
    /// :returns: The new image on success or an NSError object on failure.
    func stereogramImage() -> ResultOf<UIImage> {
        // The image is cached. Just return the cached image.
        if _stereogramImage != nil {
            return ResultOf(_stereogramImage!)
        }
        // Get the left and right images, loading them if they are not in cache.
        var leftImage: UIImage?
        switch loadImage(.Left) {
        case .Error(let error): return .Error(error)
        case .Success(let result): leftImage = result.value
        }
        
        var rightImage: UIImage?
        switch loadImage(.Right) {
        case .Error(let error): return .Error(error)
        case .Success(let result): rightImage = result.value
        }
    
        // Create the stereogram image, cache it and return it.
        assert(leftImage != nil && rightImage != nil, "Failed to load images: Left <\(leftImage)> or Right <\(rightImage)>")
        if let left = leftImage, right = rightImage {
            
            switch (self.viewingMethod) {
            case .Crosseyed:
                switch ImageManager.makeStereogramWithLeftPhoto(left, rightPhoto:right) {
                case .Error(let error): return .Error(error)
                case .Success(let result): _stereogramImage = result.value
                }
                
            case .Walleyed:
                switch ImageManager.makeStereogramWithLeftPhoto(right, rightPhoto:left) {
                case .Error(let error): return .Error(error)
                case .Success(let result): _stereogramImage = result.value
                }
                
            case .AnimatedGIF:
                _stereogramImage = UIImage.animatedImageWithImages([left, right], duration: 0.25)
                
            default:
                NSException(name: "Not implemented", reason: "Viewing method \(self.viewingMethod) is not implemented yet.", userInfo: nil).raise()
                break
            }
        }
        return ResultOf(_stereogramImage!)
    }
    
    /// Alias for a string representing a MIME Type (e.g. "image/jpeg")
    typealias MIMEType = String
    
    /// Data format when returning data for exporting a stereogram
    typealias ExportData = (NSData, MIMEType)
    
    /// Returns the stereogram image in a format for sending outside this application. 
    ///
    /// :returns: .Success(ExportData) or .Error(NSError)
    ///
    /// ExportData is a tuple: The data representing the image, and a MIME type indicating the format of the data.
    
    func exportData() -> ResultOf<ExportData> {
        return stereogramImage().map { (image) -> ResultOf<ExportData> in
            let data: NSData
            let mimeType: MIMEType
            if self.viewingMethod == .AnimatedGIF {
                mimeType = "image/gif"
                data = image.GIFData
            } else {
                mimeType = "image/jpeg"
                data = image.JPEGData
            }
            return ResultOf((data, mimeType))
        }
    }
    
    /// URL of the left image file (computed from the base URL)
    var leftImageURL: NSURL {
        return baseURL.URLByAppendingPathComponent(LeftPhotoFileName)
    }
    
    /// URL of the right image file (computed from the base URL)
    var rightImageURL: NSURL {
        return baseURL.URLByAppendingPathComponent(RightPhotoFileName)
    }
    
    /// URL of the property list file (computed from the base URL)
    var propertiesURL: NSURL {
        return baseURL.URLByAppendingPathComponent(PropertyListFileName)
    }
    
    /// Return a thumbnail image, caching it if necessary.
    ///
    /// :returns: The thumbnail image on success or an NSError object on failure.
    func thumbnailImage() -> ResultOf<UIImage> {
        
        let options = NSDataReadingOptions.allZeros
        var error: NSError?
        if _thumbnailImage == nil {
            // Get either the left or the right image file URL to use as the thumbnail.
            var data: NSData? = NSData(contentsOfURL:leftImageURL, options:options, error:&error)
            if data == nil {
                data = NSData(contentsOfURL:rightImageURL, options:options, error:&error)
            }
            if data == nil {
                return .Error(error!)
            }
            
            if let
                d = data,
                image = UIImage(data: d) {
                    
                // Create the image, and then return a thumbnail-sized copy.
                _thumbnailImage = image.thumbnailImage(thumbnailSize: Int(thumbnailSize.width), transparentBorderSize:0, cornerRadius:0, interpolationQuality:kCGInterpolationLow)
            } else {
                let userInfo: [String : AnyObject] = [
                    NSLocalizedDescriptionKey : "Invalid image format in file",
                    NSFilePathErrorKey        : leftImageURL.path!]
                let err = NSError(errorCode:.InvalidFileFormat, userInfo:userInfo)
                return .Error(err)
            }
        }
        return ResultOf(_thumbnailImage!)
    }
    
    /// Update the stereogram and thumbnail, replacing the cached images.  Usually called from a background thread just after some property has been changed.
    ///
    /// :returns: Success or an NSError object on failure.
    func refresh() -> Result {
        _thumbnailImage = nil
        _stereogramImage = nil
        return and(thumbnailImage().result, stereogramImage().result)
    }
    
    /// Delete the folder representing this stereogram from the disk.  After this, the stereogram will be invalid.
    ///
    /// :returns: Success or an NSError object on failure.
    func deleteFromDisk() -> Result {
        var error: NSError?
        let fileManager = NSFileManager.defaultManager()
        let success = fileManager.removeItemAtURL(baseURL, error:&error)
        if success {
            _thumbnailImage = nil
            _stereogramImage = nil
            return .Success()
        }
        return .Error(error!)
    }
    
    
    //MARK: Private Data

    /// Properties file for each stereogram. Probably not cached, just load them when we open the object.
    private var _propertyList: PropertyDict
    
    /// Cached images in memory. Free these if needed.
    private var _stereogramImage: UIImage?
    private var _thumbnailImage:  UIImage?
    
    //MARK: Private methods
    
    /// Save the left and right images and the property list into the directory specified by url.
    ///
    /// :param: url -  A File URL to the directory to store the images in.
    /// :param: propertyList -  The property list to output
    /// :param: leftImage -  The left image to save.
    /// :param: rightImage -  The right image to save.
    /// :returns: Success or  .Error(NSError) on failure.
    
    private class func writeToURL(url: NSURL
        ,                propertyList: [String : AnyObject]
        ,                   leftImage: UIImage
        ,                  rightImage: UIImage) -> Result {
            
            assert(url.path != nil, "URL \(url) has an invalid path")
            
            // Save the left and right images, and the property list into the directory specified by URL.
            let fileManager = NSFileManager.defaultManager()
            if urlIsDirectory(url) {
                let userInfo = [
                    NSLocalizedDescriptionKey : "File exists and is not a directory.",
                    NSFilePathErrorKey        : url.path!]
                let error = NSError(domain:ErrorDomain.PhotoStore.rawValue, code:ErrorCode.InvalidFileFormat.rawValue, userInfo:userInfo)
                return .Error(error)
            }
        
            // Create the directory (ignoring any errors about it already existing).
            var error: NSError?
            if !fileManager.createDirectoryAtURL(url, withIntermediateDirectories:false, attributes:nil, error:&error) {
                return .Error(error!)
            }
            // Directory exists now. Add the files underneath it.
            let leftImageURL = url.URLByAppendingPathComponent(LeftPhotoFileName)
            let leftResult = saveImageIntoURL(leftImage, url: leftImageURL)
            if let err = leftResult.error {
                return .Error(err)
            }
            
            let rightImageURL = url.URLByAppendingPathComponent(RightPhotoFileName)
            let rightResult = saveImageIntoURL(rightImage, url: rightImageURL)
            if let err = rightResult.error {
                return .Error(err)
            }
            
            if let propertyListData = NSPropertyListSerialization.dataWithPropertyList(
                propertyList
                ,     format: .XMLFormat_v1_0
                ,    options: .allZeros
                ,      error: &error) {
                    let propertyListURL = url.URLByAppendingPathComponent(PropertyListFileName)
                    if !propertyListData.writeToURL(propertyListURL, options:.AtomicWrite, error:&error) {
                        return .Error(error!)
                    }
                    return .Success()
            }
            return .Error(NSError.unknownErrorWithLocation("Stereogram.writeToURL(_propertyList:leftImage:rightImage:)"
                ,                                  target: "calling NSData.writeToURL(_:options:error)"))
    }

    /// Load a property list stored at URL and return it.
    ///
    /// :param: url -  File URL describing a path to a .plist file.
    /// :returns: A PropertyDict on success, an NSError on failure.
    
    private class func loadPropertyList(url: NSURL) -> ResultOf<PropertyDict> {
        var error: NSError?
        if let propertyData = NSData(contentsOfURL:url, options:.allZeros, error:&error) {
            var formatPtr: UnsafeMutablePointer<NSPropertyListFormat> = nil
            let options = Int(NSPropertyListMutabilityOptions.MutableContainersAndLeaves.rawValue)
            if let propObject: AnyObject = NSPropertyListSerialization.propertyListWithData(propertyData
                ,                                                                   options:options
                ,                                                                    format:formatPtr
                ,                                                                     error:&error) {
                    let propDict = propObject as? PropertyDict
                    assert(propDict != nil, "Property list object \(propObject) cannot be converted to a dictionary")
                    return ResultOf(propDict!)
            }
        }
        return .Error(error!)
    }
    
    /// Save the property list into it's appointed place.
    ///
    /// :returns: .Success or .Error(NSError) on failure.
    
    private func savePropertyList() -> Result {
        var error: NSError?
        if let data = NSPropertyListSerialization.dataWithPropertyList(_propertyList
            ,  format: .XMLFormat_v1_0
            , options: 0
            ,   error: &error) {
                if data.writeToURL(propertiesURL, options: .allZeros, error: &error) {
                    return .Success()
                }
        }
        return .Error(error ?? NSError.unknownErrorWithLocation("Stereogram.savePropertyList()"
            ,                                            target:"NSData.writeToURL(_, options:, error:)"))
    }
    
    
    
    /// Returns true if the path provided already exists and points to a directory.
    ///
    /// :param: url - A file URL.
    /// :returns: True if the url points to a directory, False if it doesn't exist or points to another object type.
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

    /// Saves the specified image into a file provided by the given URL
    ///
    /// :param: image -  The image to save.
    /// :param: url -  File URL of the location to save the image.
    /// :returns: Success on success, or an NSError on failure.
    ///
    /// Currently this saves as a JPEG file, but it doesn't check the extension in the URL
    /// so it is possible it could save JPEG data into a file ending in .png for example.
    private class func saveImageIntoURL(image: UIImage, url: NSURL) -> Result {
        let fileData = UIImageJPEGRepresentation(image, 1.0)
        var error: NSError?
        if fileData.writeToURL(url, options:.AtomicWrite, error:&error) {
            return .Success()
        }
        return .Error(error!)
    }

    /// Create a new unique URL which will not already reference a stereogram.
    /// This URL is relative to photoDir.
    /// 
    /// :param: photoDir - The base directory with all the stereograms in it.
    /// :returns: A file URL pointing to a new directory under photoDir which has not already been used.
    private class func getUniqueStereogramURL(photoDir: NSURL) -> NSURL {
        
        // Create a CF GUID, then turn it into a string, which we will return.  Add the object into the backing store using this key.
        let newUID = CFUUIDCreate(kCFAllocatorDefault);
        let newUIDString = CFUUIDCreateString(kCFAllocatorDefault, newUID)
        
        let uid = newUIDString as String
        let newURL = photoDir.URLByAppendingPathComponent(uid, isDirectory:true)
        
        // Name should be unique so no photo should exist yet.
        assert(newURL.path != nil, "URL \(newURL) has no path.")
        assert(!NSFileManager.defaultManager().fileExistsAtPath(newURL.path!), "'Unique' file URL \(newURL) already exists")
        return newURL;
    }
    
    private enum WhichImage {
        case Left, Right
    }
    
    /// Loads one of the two images, caching it if necessary.
    ///
    /// :param: whichImage - Left or Right specifying which image to load.
    /// :returns: The UIImage object on success or NSError on failure.
    private func loadImage(whichImage: WhichImage) -> ResultOf<UIImage> {
        
        func loadData(url: NSURL) -> ResultOf<UIImage> {
            var error: NSError?
            if let
                imageData = NSData(contentsOfURL:url, options:.allZeros, error:&error),
                image = UIImage(data: imageData) {
                    return ResultOf(image)
            } else {
                return ResultOf.Error(error!)
            }
        }
        
        switch whichImage {
        case .Left:
            return loadData(leftImageURL)
        case .Right:
            return loadData(rightImageURL)
        }
    }
    
    /// Searches a given directory and returns all the entries under it.
    ///
    /// :param: url -  A file URL pointing to the directory to search.
    /// :returns: An array of URL objects, one each for each file in the directory
    ///
    /// This does not include hidden files in the search.
    private class func contentsUnderURL(url: NSURL) -> ResultOf<[NSURL]> {
        let fileManager = NSFileManager.defaultManager()
        var error: NSError?
        if let
            fileArray = fileManager.contentsOfDirectoryAtURL(url, includingPropertiesForKeys:nil, options:.SkipsHiddenFiles, error:&error),
            urlArray = fileArray as? [NSURL] {
                return ResultOf(urlArray)
        }
        return .Error(error!)
    }
    

}
