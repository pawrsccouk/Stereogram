// UIImage+RoundedCorner.m
// Created by Trevor Harmon on 9/20/09.
// Free for personal or commercial use, with or without modification.
// No warranty is expressed or implied.

import UIKit

extension UIImage {
    
    // Creates a copy of this image with rounded corners
    // If borderSize is non-zero, a transparent border of the given size will also be added
    // Original author: Björn Sållarp. Used with permission. See: http://blog.sallarp.com/iphone-uiimage-round-corners/
    public func roundedCornerImage(cornerSize: UInt, borderSize: UInt) -> UIImage {
        let image = self.imageWithAlpha()
        
        // Build a context that's the same dimensions as the new size
        let width = Int(image.size.width), height = Int(image.size.height)
        let context = CGBitmapContextCreate(nil, width, height, CGImageGetBitsPerComponent(image.CGImage), 0, CGImageGetColorSpace(image.CGImage), CGImageGetBitmapInfo(image.CGImage))
        
        // Create a clipping path with rounded corners
        let ovalSize = CGFloat(cornerSize), border = CGFloat(borderSize)
        let ovalRect = CGRectMake(border, border, image.size.width - border * 2, image.size.height - border * 2)
        CGContextBeginPath(context)
        addRoundedRectToPath(ovalRect, context:context, ovalWidth:ovalSize, ovalHeight:ovalSize)
        CGContextClosePath(context)
        CGContextClip(context)
        
        // Draw the image to the context; the clipping path will make anything outside the rounded rect transparent
        CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage)
        
        // Create a CGImage from the context and create a UIImage from the CGImage
        return UIImage(CGImage: CGBitmapContextCreateImage(context))!
    }
    
    
    //// Adds a rectangular path to the given context and rounds its corners by the given extents
    //// Original author: Björn Sållarp. Used with permission. See: http://blog.sallarp.com/iphone-uiimage-round-corners/
    private func addRoundedRectToPath(rect: CGRect, context: CGContextRef, ovalWidth: CGFloat, ovalHeight: CGFloat) {
        if ovalWidth == 0 || ovalHeight == 0 {
            CGContextAddRect(context, rect)
            return
        }
        
        CGContextSaveGState(context)
        CGContextTranslateCTM(context, CGRectGetMinX(rect), CGRectGetMinY(rect))
        CGContextScaleCTM(context, ovalWidth, ovalHeight)
        let fw = CGRectGetWidth(rect) / ovalWidth
        let fh = CGRectGetHeight(rect) / ovalHeight
        CGContextMoveToPoint(context, fw, fh/2)
        CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1)
        CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1)
        CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1)
        CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1)
        CGContextClosePath(context)
        CGContextRestoreGState(context)
    }
}