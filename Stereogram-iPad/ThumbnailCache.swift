//
//  ThumbnailManager.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 21/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

// XCode does not implement class variables yet, only functions.
// Thumbnails must be square.
private let thumbSize = 100
let thumbnailSize = CGSizeMake(CGFloat(thumbSize), CGFloat(thumbSize))

// Stores a collection of image thumbnails, with code to generate and cache them.
class ThumbnailCache {

	// Size of a thumbnail in pixels.  Thumbnails are square, so this is the width and the height.

	// Array of paths to image thumbnails.
	typealias FileName = String
	typealias ThumbnailDict = [FileName : UIImage]
	private var thumbnailDict = ThumbnailDict()

	private var notificationCenter = NSNotificationCenter.defaultCenter()

	init() {
		// Notify when memory is low, so I can delete this cache.
		notificationCenter.addObserverForName(UIApplicationDidReceiveMemoryWarningNotification
			,                         object: nil
			,                          queue: NSOperationQueue.mainQueue()) {
				(note) -> Void in
				NSLog("Low memory notification received. Deleting the cache.")
				self.freeCache()
		}
	}

	deinit {
		// Remove myself from the notification tables once this object is destroyed.
		notificationCenter.removeObserver(self)
	}

	func freeCache() {
		thumbnailDict.removeAll(keepCapacity: false)
	}

	/// Returns a thumbnail for the image specified by filePath.
	/// If there is no thumbnail yet, creates one and adds it to the cache.
	/// If successful, returns .Success(the-thumbnail), otherwise returns an error.
	///
	/// :param: filePath - The path to the image file on disk.
	/// :returns: ResultOf holding a thumbnail-sized image of the given file.

	func thumbnailForImage(imagePath: FileName) -> ResultOf<UIImage> {
		if let thumb = thumbnailDict[imagePath] {
			return ResultOf(thumb) // Success, return the cached image.
		}
		// If the thumbnail was not already cached, create it and return it now.
		return ImageManager.imageFromFile(imagePath).map { (img) -> ResultOf<UIImage> in
			self.addThumbnailForImage(img, forKey: imagePath)
		}
	}



	/// Create a thumbnail for the image provided and add it to the thumbnail cache
	/// under the specified key, which is the full path to the real image on disk.
	///
	/// :param: image - The image to retrieve a thumbnail from.
	/// :param: key - A key to store the thumbnail under.
	/// :returns: The thumbnail if successful.
	func addThumbnailForImage(image: UIImage, forKey key: String) -> ResultOf<UIImage> {
		// Use the left half of the image for the thumbnail
		// as having both makes the actual image content too small to see.
		return ImageManager.getHalfOfImage(image, whichHalf: .LeftHalf).map {
			leftHalf in
			let thumbnail = leftHalf.thumbnailImage(thumbnailSize: thumbSize
				,                           transparentBorderSize: 0
				,                                    cornerRadius: 0
				,                            interpolationQuality: kCGInterpolationLow)
			self.thumbnailDict[key] = thumbnail
			return ResultOf(thumbnail)
		}
	}

}



