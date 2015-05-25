//
//  UIImage+Representations.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 22/04/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit
import ImageIO
import MobileCoreServices


extension UIImage {

    /// Return this image as an NSData object representing a GIF.

    var asGIFData: NSData! {
        let mutableData = NSMutableData()
        let cgImage = CGImageDestinationCreateWithData(mutableData
			, kUTTypeGIF, self.images?.count ?? 1, nil)
        if let allFrames = self.images as? [UIImage] {
            for frame in allFrames {
                CGImageDestinationAddImage(cgImage, frame.CGImage, nil)
            }
        } else { // Only one image.
            CGImageDestinationAddImage(cgImage, self.CGImage, nil)
        }
        CGImageDestinationFinalize(cgImage)
        return mutableData
    }

    /// Return this image as an NSData object representing a JPEG.

    var asJPEGData: NSData! {
        return UIImageJPEGRepresentation(self, 1.0)
    }

}

