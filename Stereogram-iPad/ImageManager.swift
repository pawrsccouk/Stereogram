//
//  ImageManager.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 21/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

private let defaultError = NSError(domain: ErrorDomain.PhotoStore.rawValue, code: ErrorCode.UnknownError.rawValue, userInfo: [NSLocalizedDescriptionKey : "Unknown Error"])

/// A collection of functions for handling images.
class ImageManager {
    
    /// Load an image from the disk
    /// 
    /// :param: filePath - Path to the image on disk.
    /// :returns: A UIImage object on success or an error object on failure
    class func imageFromFile(filePath: String) -> ResultOf<UIImage> {
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
    
    /// Compose two photos to make a stereogram.
    ///
    /// :param: leftPhoto - The left image.
    /// :param: rightPhoto - The right image.
    /// :returns: A UIImage on success or an NSError on failure.
    class func makeStereogramWithLeftPhoto(leftPhoto: UIImage, rightPhoto: UIImage) -> ResultOf<UIImage> {
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
    
    /// Returns a copy of the specifed image with the viewing method swapped.
    ///
    /// :param: image The image to swap.
    /// :returns: The new image on success, or an NSError object on failure.
    ///
    /// Note that this only works by chopping the image in half and rearranging the halves.
    class func changeViewingMethod(image: UIImage) -> ResultOf<UIImage> {
        return and( self.getHalfOfImage(image, whichHalf: .LeftHalf),
                    self.getHalfOfImage(image, whichHalf: .RightHalf) )
            .map( { (leftImage,rightImage) in
                return ImageManager.makeStereogramWithLeftPhoto(rightImage, rightPhoto: leftImage) } )
    }

    /// Enum to describe which half of an image to retrieve.
    ///
    /// - RightHalf: The right half of the image
    /// - LeftHalf: The left half of the image
    enum WhichHalf {
        case RightHalf, LeftHalf
    }
    
    /// Function to return half an image.
    ///
    /// :param: image - The image to split
    /// :returns: A UIImage on success or an NSError object on failure.
    class func getHalfOfImage(image: UIImage,  whichHalf: WhichHalf) -> ResultOf<UIImage> {
        let rectToKeep = (whichHalf == .LeftHalf)
            ? CGRectMake(0, 0, image.size.width / 2.0, image.size.height)
            : CGRectMake(image.size.width / 2.0, 0, image.size.width / 2.0, image.size.height )
        
        let imgPartRef = CGImageCreateWithImageInRect(image.CGImage, rectToKeep)
        if let i = UIImage(CGImage:imgPartRef) { return ResultOf(i) }
        let userInfo = [NSLocalizedDescriptionKey : "Unable to create thumbnail. Unknown error."]
        return .Error(NSError(domain: ErrorDomain.PhotoStore.rawValue, code: ErrorCode.UnknownError.rawValue, userInfo: userInfo))
    }

}
