//
//  ImageThumbnailCell.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 15/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

/// A collection view cell designed to show thumbnail images and overlay a tick if the cell is selected.
class ImageThumbnailCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Create and add the image thumbnail view (as a temporary first, as imageView is a weak reference)
        let iv = UIImageView(frame: contentView.frame)
        contentView.addSubview(iv)
        imageView = iv
        
        // Add the overlay view showing if the object is selected or not (as a temporary first, as selectionOverlayView is a weak reference).
        let selImageSize = selectedImageSize
        let selImageOrigin = CGPointMake(frame.size.width - selImageSize.width, frame.size.height - selImageSize.height)
        var selOverlayFrame = CGRectZero
        selOverlayFrame.origin = selImageOrigin
        selOverlayFrame.size = selImageSize
        let sv = UIImageView(frame: selOverlayFrame)
        //sv.image = ImageThumbnailCell.unselectedImage
        contentView.addSubview(sv)
        selectionOverlayView = sv
    }

    // See if this is needed.
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    weak var imageView: UIImageView!
    weak var selectionOverlayView: UIImageView!
    
    /// Image which will be displayed in the collection view.
    var image: UIImage = UIImage() {
        didSet {
            imageView.image = self.image
        }
    }
    
    /// Size of the selected overlay image.
    private let selectedImageSize = CGSizeMake(46, 46)
    
    // Override the description to return the image view and selection state.
    override var description:  String {
        let superDesc = super.description
        return "\(superDesc): <imageView=\(imageView), selected=\(selected)>"
    }
    
    // Track when the cell becomes selected or not, and update the image to show this.
    override var selected: Bool {
        didSet {
            selectionOverlayView.image = selected ? ImageThumbnailCell.selectedImage : nil //ImageThumbnailCell.unselectedImage
        }
    }
    
    // Images which are overlaid on the thumbnail to indicate if it is selected or not.
    
    /// Image shown when the cell is selected.
    private static let selectedImage   = UIImage(named: "Tick")
    
    /// Image shown when the cell is not selected.
    //private static let unselectedImage = UIImage(named: "Unselected Overlay")
}


