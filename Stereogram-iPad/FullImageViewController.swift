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
        // Add the activity indicator to the view if it is not there already. It starts off hidden.
        if !activityIndicator.isDescendantOfView(view) {
            view.addSubview(activityIndicator)
        }
        resizeActivityIndicator()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Called on resize or autorotate. Re-set up the scrollview to preserve the scaling factor.
        setupScrollviewAnimated(true)
    }
    
    // MARK: User-configurable properties.
    
    typealias ImageCallback = (UIImage) -> Void          // A callback that takes an image.
    var imageUpdatedCallback: ImageCallback = { image in }  // Function to execute when the user updates an image we were tracking.
    var approvalCallback: ImageCallback = { image in }      // Function to execute when the user approves this image. Should add it to the image collection.
    
    
    // MARK: Callbacks for the buttons.
    
    func keepPhoto() {
        approvalCallback(self.image)
        presentingViewController!.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func discardPhoto() {
        presentingViewController!.dismissViewControllerAnimated(true, completion: nil)
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
                    // If we were tracking an already-existing image, then notify the system that the image has updated.
                    self.imageUpdatedCallback(newImage.value)
                }
            case .Error(let error):
                dispatch_async(dispatch_get_main_queue()) {
                    self.showActivityIndicator = false
                    error.showAlertWithTitle("Error changing viewing method.")
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
    private let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    
    private var showActivityIndicator: Bool {
        get { return !activityIndicator.hidden }
        set {
            // TODO: Check the activity indicator still works.
            activityIndicator.hidden = !newValue
            if newValue {
                // view.addSubview(activityIndicator)
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
                // activityIndicator.removeFromSuperview()
            }
        }
    }

    private func resizeActivityIndicator() {
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
