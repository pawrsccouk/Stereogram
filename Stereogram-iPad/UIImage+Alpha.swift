// UIImage+Alpha.h
// Created by Trevor Harmon on 9/20/09.
// Free for personal or commercial use, with or without modification.
// No warranty is expressed or implied.

import UIKit

// Helper methods for adding an alpha layer to an image
extension UIImage {
    
    // true if this image has an alpha layer.
    var hasAlpha: Bool {
        let alpha = CGImageGetAlphaInfo(self.CGImage)
        return (alpha == .First || alpha == .Last || alpha == .PremultipliedFirst || alpha == .PremultipliedLast)
    }
    
    // Returns the given image if it already has an alpha channel, or a copy of the image adding an alpha channel if it doesn't already have one
    func imageWithAlpha() -> UIImage {
        if self.hasAlpha {
            return self
        }
        
        let imageRef = self.CGImage, width = CGImageGetWidth(imageRef), height = CGImageGetHeight(imageRef)
        
        // The bitsPerComponent and bitmapInfo values are hard-coded to prevent an "unsupported parameter combination" error
        let bitmapInfo = CGBitmapInfo.ByteOrderDefault.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue
        let offscreenContext = CGBitmapContextCreate(nil, width, height, 8, 0, CGImageGetColorSpace(imageRef), CGBitmapInfo(rawValue: bitmapInfo))
        
        // Draw the image into the context and retrieve the new image, which will now have an alpha layer
        CGContextDrawImage(offscreenContext, CGRectMake(0, 0, CGFloat(width), CGFloat(height)), imageRef)
        let imageRefWithAlpha = CGBitmapContextCreateImage(offscreenContext)
        return UIImage(CGImage: imageRefWithAlpha)!
    }
    
    // Returns a copy of the image with a transparent border of the given size added around its edges.
    // If the image has no alpha layer, one will be added to it.
    func transparentBorderImage(borderSize borderSizeUInt: UInt) -> UIImage {
        let borderSize = CGFloat(borderSizeUInt)
        // If the image does not have an alpha layer, add one
        let image = self.imageWithAlpha()
        
        let newRect = CGRectMake(0, 0, image.size.width + borderSize * 2, image.size.height + borderSize * 2)
        
        // Build a context that's the same dimensions as the new size
        let width = UInt(newRect.size.width), height = UInt(newRect.size.height)
        let bitmap = CGBitmapContextCreate(nil, width, height, CGImageGetBitsPerComponent(self.CGImage), 0, CGImageGetColorSpace(self.CGImage), CGImageGetBitmapInfo(self.CGImage))
        
        // Draw the image in the center of the context, leaving a gap around the edges
        let imageLocation = CGRectMake(borderSize, borderSize, image.size.width, image.size.height);
        CGContextDrawImage(bitmap, imageLocation, self.CGImage);
        let borderImageRef = CGBitmapContextCreateImage(bitmap);
        
        // Create a mask to make the border transparent, and combine it with the image
        let maskImageRef = newBorderMask(borderSizeUInt, size:newRect.size)
        let transparentBorderImageRef = CGImageCreateWithMask(borderImageRef, maskImageRef)
        return UIImage(CGImage: transparentBorderImageRef)!
    }
    
    
    
    
    // Creates a mask that makes the outer edges transparent and everything else opaque
    // The size must include the entire mask (opaque part + transparent border)
    // The caller is responsible for releasing the returned reference by calling CGImageRelease
    private func newBorderMask(borderSize: UInt, size: CGSize) -> CGImageRef {
         let border = CGFloat(borderSize)
       
        // Build a context that's the same dimensions as the new size
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.ByteOrderDefault.rawValue | CGImageAlphaInfo.None.rawValue)
        let width = UInt(size.width), height = UInt(size.height)
        let maskContext = CGBitmapContextCreate(nil, width, height, 8 /* 8-bit grayscale*/, 0, colorSpace, bitmapInfo)
        
        // Start with a mask that's entirely transparent
        CGContextSetFillColorWithColor(maskContext, UIColor.blackColor().CGColor)
        CGContextFillRect(maskContext, CGRectMake(0, 0, size.width, size.height))
        
        // Make the inner part (within the border) opaque
        CGContextSetFillColorWithColor(maskContext, UIColor.whiteColor().CGColor)
        CGContextFillRect(maskContext, CGRectMake(border, border, size.width - border * 2, size.height - border * 2))
        
        // Return an image of the context
        return CGBitmapContextCreateImage(maskContext)
    }
}
