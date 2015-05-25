//
//  ImageThumbnailCell.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 15/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

/// A cell designed to show thumbnail images and overlay a tick if the cell is selected.
class ImageThumbnailCell: UICollectionViewCell {

    override init(frame: CGRect) {
        super.init(frame: frame)

        // Create and add the image thumbnail view
        let iv = UIImageView(frame: contentView.frame)
        contentView.addSubview(iv)
        imageView = iv

        // Add the overlay view showing if the object is selected or not
        let selImageSize = selectedImageSize
        let selImageOrigin = CGPointMake(frame.size.width - selImageSize.width
			,                            frame.size.height - selImageSize.height)
        var selOverlayFrame = CGRectZero
        selOverlayFrame.origin = selImageOrigin
        selOverlayFrame.size = selImageSize
        let sv = UIImageView(frame: selOverlayFrame)
        //sv.image = ImageThumbnailCell.unselectedImage
        contentView.addSubview(sv)
        selectionOverlayView = sv
    }

    /// Initialize from a decoder. Not currently implemented.
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The image view which will display the main thumbnail image.
    weak var imageView: UIImageView!

    /// The image view which will display the 'tick' icon if the cell is selected.
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
    override var description: String {
        let superDesc = super.description
        return "\(superDesc): <imageView=\(imageView), selected=\(selected)>"
    }

    override var selected: Bool {
        // Track when the cell becomes selected or not, and update the image to show this.
        didSet {
            selectionOverlayView.image = selected ? ImageThumbnailCell.selectedImage : nil
        }
    }

    /// Image overlaid above the thumbnail when the cell is selected.
    private static let selectedImage   = UIImage(named: "Tick")
}


