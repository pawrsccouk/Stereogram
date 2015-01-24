//
//  FullImageViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 16/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

@objc protocol FullImageViewControllerDelegate {
    
    // Called if the controller is in Approval mode and the user has approved an image.
    optional func fullImageViewController(controller: FullImageViewController, approvedImage image: UIImage)

    // Called if the controller is viewing an image, and the image changed.
    // This will be called in both approval mode and regular viewing mode
    optional func fullImageViewController(controller: FullImageViewController, amendedImage newImage: UIImage, atIndexPath indexPath: NSIndexPath?)
    
    // Called when the user has requested the controller be closed. On receipt of this message, the delegagte must remove the view controller from the stack.
    func dismissedFullImageViewController(controller: FullImageViewController)
}


class FullImageViewController: UIViewController, UIScrollViewDelegate {

    
    // MARK: Housekeeping
    
    // Designated initialiser. image is the image to display. indexPath is the object where the image is stored (if any).
    // If forApproval is YES, the view gets a 'Keep' button, and if pressed, calls the delegate's approvedImage function, which should copy the image to permanent storage.
    init(image: UIImage, atIndexPath indexPath: NSIndexPath?, forApproval: Bool, delegate: FullImageViewControllerDelegate) {
        self.image = image
        self.indexPath = indexPath
        self.delegate = delegate
        super.init(nibName: "FullImageView", bundle: nil)
        let toggleViewMethodButtonItem = UIBarButtonItem(title: "Toggle View Method", style: .Bordered, target: self, action: "changeViewingMethod")
        // If we are using this to approve an image, then display "Keep" and "Discard" buttons.
        if forApproval {
            let keepButtonItem = UIBarButtonItem(title: "Keep", style: .Bordered, target: self, action: "keepPhoto")
            let discardButtonItem = UIBarButtonItem(title: "Discard", style: .Bordered, target: self, action: "discardPhoto")
            self.navigationItem.rightBarButtonItems = [keepButtonItem, discardButtonItem]
            self.navigationItem.leftBarButtonItem = toggleViewMethodButtonItem
        } else {
            self.navigationItem.rightBarButtonItem = toggleViewMethodButtonItem
        }
    }
    
    // Convenience initialiser. Open in normal mode, viewing the index at the selected index path.
    convenience init(image: UIImage, atIndexPath indexPath: NSIndexPath, delegate: FullImageViewControllerDelegate) {
        self.init(image: image, atIndexPath: indexPath, forApproval: false, delegate: delegate)
    }

    // Convenience initialiser. Open in approval mode.
    convenience init(imageForApproval: UIImage, delegate: FullImageViewControllerDelegate) {
        self.init(image: imageForApproval, atIndexPath: nil, forApproval: true, delegate: delegate)
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
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        setupActivityIndicator()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Called on resize or autorotate. Re-set up the scrollview to preserve the scaling factor.
        setupScrollviewAnimated(true)
    }
    
    // MARK: User-configurable properties.
    
    unowned var delegate: FullImageViewControllerDelegate
    
    // MARK: Callbacks for the buttons.
    
    func keepPhoto() {
        delegate.fullImageViewController?(self, approvedImage: self.image)
        delegate.dismissedFullImageViewController(self)
        // presentingViewController!.dismissViewControllerAnimated(true, completion: dismissCallback)
    }
    
    func discardPhoto() {
        delegate.dismissedFullImageViewController(self)
        // presentingViewController!.dismissViewControllerAnimated(true, completion: dismissCallback)
    }
    
    // Toggle from cross-eye to wall-eye and back for the selected items.
    // Create the new images on a separate thread, then call back to the main thread to replace them in the photo collection.
    func changeViewingMethod() {
        let oldImage = self.image
        let imageView = self.imageView
        self.showActivityIndicator = true
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            switch ImageManager.changeViewingMethod(oldImage) {
            case .Success(let newImage):
                dispatch_async(dispatch_get_main_queue()) {
                    // Clear the activity indicator and update the image in this view.
                    self.showActivityIndicator = false
                    self.image = newImage.value
                    imageView.image = newImage.value
                    imageView.sizeToFit()
                    // Notify the system that the image has been changed in the view.
                    self.delegate.fullImageViewController?(self, amendedImage: newImage.value, atIndexPath: self.indexPath)
                }
            case .Error(let error):
                dispatch_async(dispatch_get_main_queue()) {
                    self.showActivityIndicator = false
                    error.showAlertWithTitle("Error changing viewing method.", parentViewController: self)
                }
            }
        }
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
    private var indexPath: NSIndexPath?
    private let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    
    private var showActivityIndicator: Bool {
        get { return !activityIndicator.hidden }
        set {
            activityIndicator.hidden = !newValue
            if newValue {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        }
    }

    private func setupActivityIndicator() {
        // Add the activity indicator to the view if it is not there already. It starts off hidden.
        if !activityIndicator.isDescendantOfView(view) {
            view.addSubview(activityIndicator)
        }

        // Ensure the activity indicator fits in the frame.
        let activitySize = activityIndicator.bounds.size
        let parentSize = view.bounds.size
        let frame = CGRectMake((parentSize.width / 2) - (activitySize.width / 2), (parentSize.height / 2) - (activitySize.height / 2), activitySize.width, activitySize.height)
        activityIndicator.frame = frame
    }

    private func setupScrollviewAnimated(animated: Bool) {
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
