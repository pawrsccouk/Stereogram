//
//  FullImageViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 16/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

class FullImageViewController: UIViewController, UIScrollViewDelegate {

    // Initialise the image view to display the given image.
    // If forApproval is YES, the view gets a 'Keep' button, and if pressed, calls approvalBlock
    // which should copy the image to permanent storage.
    
    // MARK: Housekeeping
    
    init(image: UIImage, forApproval: Bool) {
        self.image = image
        super.init(nibName: "FullImageView", bundle: nil)
        // If we are using this to approve an image, then display "Keep" and "Discard" buttons.
        if forApproval {
            let keepButtonItem = UIBarButtonItem(title: "Keep", style: .Bordered, target: self, action: "keepPhoto")
            let discardButtonItem = UIBarButtonItem(title: "Discard", style: .Bordered, target: self, action: "discardPhoto")
            self.navigationItem.leftBarButtonItem = keepButtonItem
            self.navigationItem.rightBarButtonItem = discardButtonItem
        }
    }

    // We create this manually instead of storing it in a NIB file.
    // If we decide to allow this, I'll need to do the equivalent to init(image:, forApproval:) outside the class.
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Set the image now we know the view is loaded, and use that to set the bounds of the scrollview it's contained in.
        imageView.image = image
        imageView.sizeToFit()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Called on resize or autorotate. Re-set up the scrollview to preserve the scaling factor.
        setupScrollviewAnimated(true)
    }
    
    // MARK: User-configurable properties.
    
    typealias ApprovalBlock = () -> Void
    var approvalBlock: ApprovalBlock = {}  // Function to execute when the user clicks the "Approve" button.
    
    
    // MARK: Callbacks for the Keep and Discard buttons.
    
    func keepPhoto() {
        approvalBlock()
        presentingViewController!.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func discardPhoto() {
        presentingViewController!.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: Interface Builder
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var scrollView: UIScrollView!
    
    // MARK: - Scrollview Delegate
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    // MARK: - Private Data
    
    private var image: UIImage
    
    func setupScrollviewAnimated(animated: Bool) {
        if let viewedImage = imageView.image {
            scrollView.contentSize = imageView.bounds.size
        
            // set the zoom info so the image fits in the window by default but can be zoomed in. Respect the aspect ratio.
            let imageSize = viewedImage.size, viewSize = scrollView.bounds.size
            scrollView.maximumZoomScale = 1.0   // Cannot zoom in past original/full-size.
            scrollView.minimumZoomScale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
            // Default to showing the whole image.
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: animated)
        }
    }
}
