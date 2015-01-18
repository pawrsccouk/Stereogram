// UIImage+Resize.m
// Created by Trevor Harmon on 8/5/09.
// Free for personal or commercial use, with or without modification.
// No warranty is expressed or implied.

import UIKit

// Versions of UIViewContentMode applicable to scaling UIImage objects.
enum ImageResizeContentMode {
    case ScaleAspectFill, ScaleAspectFit
}

// Extends the UIImage object to support resizing and cropping.
extension UIImage {
    
    
    // Returns a copy of this image that is cropped to the given bounds.
    // The bounds will be adjusted using CGRectIntegral.
    // This method ignores the image's imageOrientation setting.
    public func croppedImage(bounds: CGRect) -> UIImage {
        let imageRef = CGImageCreateWithImageInRect(self.CGImage, bounds)
        return UIImage(CGImage:imageRef)!
    }

    
    // Returns a copy of this image that is squared to the thumbnail size.
    // If transparentBorder is non-zero, a transparent border of the given size will be added around the edges of the thumbnail. (Adding a transparent border of at least one pixel in size has the side-effect of antialiasing the edges of the image when rotating it using Core Animation.)

    func thumbnailImage(thumbnailSize thumbnailSizeFloat: Int, transparentBorderSize borderSize: UInt, cornerRadius: UInt, interpolationQuality quality: CGInterpolationQuality) -> UIImage {
        let thumbnailSize = CGFloat(thumbnailSizeFloat)
        let bounds = CGSizeMake(thumbnailSize, thumbnailSize)
        let resizedImage = resizedImageWithContentMode(.ScaleAspectFill, bounds: bounds, interpolationQuality: quality)
        
        // Crop out any part of the image that's larger than the thumbnail size
        // The cropped rect must be centered on the resized image
        // Round the origin points so that the size isn't altered when CGRectIntegral is later invoked
        let originX = round((resizedImage.size.width - thumbnailSize) / 2), originY = round((resizedImage.size.height - thumbnailSize) / 2)
        let cropRect = CGRectMake(originX, originY, thumbnailSize, thumbnailSize)
        let croppedImage = resizedImage.croppedImage(cropRect)
        
        let transparentBorderImage = borderSize > 0 ? croppedImage.transparentBorderImage(borderSize: borderSize) : croppedImage
        return transparentBorderImage.roundedCornerImage(cornerRadius, borderSize:borderSize)
    }
    
    // Returns a rescaled copy of the image, taking into account its orientation
    // The image will be scaled disproportionately if necessary to fit the bounds specified by the parameter
    func resizedImage(newSize: CGSize, interpolationQuality quality: CGInterpolationQuality) -> UIImage {
        var drawTransposed = false
        switch (imageOrientation) {
        case .Left, .LeftMirrored, .Right, .RightMirrored:
            drawTransposed = true
        default:
            drawTransposed = false
        }
        return resizedImage(newSize, transform: transformForOrientation(newSize), drawTransposed: drawTransposed, interpolationQuality: quality)
    }
    
    // Resizes the image according to the given content mode, taking into account the image's orientation
    // Throws an exception if passed an incorrect ContentMode.
    func resizedImageWithContentMode(contentMode: ImageResizeContentMode, bounds: CGSize, interpolationQuality quality: CGInterpolationQuality) -> UIImage {
        let horizontalRatio = bounds.width / self.size.width, verticalRatio = bounds.height / self.size.height
        
        var ratio: CGFloat = 0
        switch (contentMode) {
        case .ScaleAspectFill: ratio = max(horizontalRatio, verticalRatio)
        case .ScaleAspectFit:  ratio = min(horizontalRatio, verticalRatio)
        }
        
        let newSize = CGSizeMake(self.size.width * ratio, self.size.height * ratio)
        return resizedImage(newSize, interpolationQuality:quality)
    }
    
    // Returns an affine transform that takes into account the image orientation when drawing a scaled image
    private func transformForOrientation(newSize: CGSize) -> CGAffineTransform {
        let pi = CGFloat(M_PI), pi_2 = CGFloat(M_PI_2)
        
        var transform = CGAffineTransformIdentity
        switch (self.imageOrientation) {
        case .Down, .DownMirrored:     // EXIF = 3, 4
            transform = CGAffineTransformTranslate(transform, newSize.width, newSize.height)
            transform = CGAffineTransformRotate(transform, pi)
            
        case .Left, .LeftMirrored:      // EXIF = 6, 5
            transform = CGAffineTransformTranslate(transform, newSize.width, 0)
            transform = CGAffineTransformRotate(transform, pi_2)
            
        case .Right, .RightMirrored:  // EXIF = 8, 7
            transform = CGAffineTransformTranslate(transform, 0, newSize.height)
            transform = CGAffineTransformRotate(transform, -pi_2)
            
        default: break // use the identity transform.
        }
    
        switch (self.imageOrientation) {
        case .UpMirrored, .DownMirrored:     // EXIF = 2, 4
            transform = CGAffineTransformTranslate(transform, newSize.width, 0)
            transform = CGAffineTransformScale(transform, -1, 1)
            
        case .LeftMirrored, .RightMirrored:  // EXIF = 5, 7
            transform = CGAffineTransformTranslate(transform, newSize.height, 0)
            transform = CGAffineTransformScale(transform, -1, 1)
            
        default: break // use the transform already in place.
        }
    
        return transform
    }
    
    // Returns a copy of the image that has been transformed using the given affine transform and scaled to the new size
    // The new image's orientation will be UIImageOrientationUp, regardless of the current image's orientation
    // If the new size is not integral, it will be rounded up
    private func resizedImage(newSize: CGSize, transform: CGAffineTransform, drawTransposed transpose: Bool, interpolationQuality quality: CGInterpolationQuality) -> UIImage {
        let newRect = CGRectIntegral(CGRectMake(0, 0, newSize.width, newSize.height))
        let transposedRect = CGRectMake(0, 0, newRect.size.height, newRect.size.width)
        let imageRef = self.CGImage
        
        // Build a context that's the same dimensions as the new size
        //let data = UnsafeMutablePointer<Void>()
        let width = UInt(newRect.size.width), height = UInt(newRect.size.height), bitsPerComponent: UInt = CGImageGetBitsPerComponent(imageRef), bytesPerRow: UInt = 0
        let bitmap = CGBitmapContextCreate(nil, width, height, bitsPerComponent, bytesPerRow, CGImageGetColorSpace(imageRef), CGImageGetBitmapInfo(imageRef))
        
        CGContextConcatCTM(bitmap, transform)                                          // Rotate and/or flip the image if required by its orientation
        CGContextSetInterpolationQuality(bitmap, quality)                              // Set the quality level to use when rescaling
        CGContextDrawImage(bitmap, transpose ? transposedRect : newRect, imageRef)     // Draw into the context; this scales the image
        
        // Get the resized image from the context and a UIImage
        return UIImage(CGImage: CGBitmapContextCreateImage(bitmap))!
    }

}

