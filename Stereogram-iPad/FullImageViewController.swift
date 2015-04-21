//
//  FullImageViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 16/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//
// TODO: Add an explicit state enum or split this into two classes.

import UIKit

@objc enum ApprovalResult: Int {
    case Accepted, Discarded
}

/// Protocol for Image controller delegate. 
/// Used to notify the caller when the user approves or rejects an image and to dismiss the controller.

@objc protocol FullImageViewControllerDelegate {
    
    /// Called if the controller is in Approval mode and the user has approved an image.
    ///
    /// :param: controller - The controller that triggered the message.
    /// :param: stereogram - The stereogram the user took
    /// :param: result     - Whether the user approved or rejected the stereogram.
    
    optional func fullImageViewController(controller: FullImageViewController
        ,             approvingStereogram stereogram: Stereogram
        ,                                     result: ApprovalResult)

    /// Called if the controller is viewing an image, and the image changed.
    ///
    /// This will be called in both approval mode and regular viewing mode
    ///
    /// :param: controller - The controller that triggered the message.
    /// :param: stereogram - The stereogram the user took
    /// :param: indexPath  - The path to the image the user is editing in the photo view controller.
 
    optional func fullImageViewController(controller: FullImageViewController
        ,            amendedStereogram newStereogram: Stereogram
        ,                      atIndexPath indexPath: NSIndexPath?)
    
    // Called when the user has requested the controller be closed. 
    /// On receipt of this message, the delegagte must remove the view controller from the stack.
    ///
    /// :param: controller - The controller that triggered the message.
    
    func dismissedFullImageViewController(controller: FullImageViewController)
}

/// View controller presenting a view which will show a stereogram image at full size 
///
/// There are two modes this controller can be in. 
///  - View Mode: Show an existing image read-only.
///  - Approval Mode: Show a new image and allow the user to accept or reject it.

class FullImageViewController: UIViewController, UIScrollViewDelegate {

    
    // MARK: Initialisers
    
    /// Designated initialiser. image is the image to display. indexPath is the object where the image is stored (if any).
    /// If forApproval is YES, the view gets a 'Keep' button, and if pressed, calls the delegate's approvedImage function, which should copy the image to permanent storage.
    ///
    /// :param: stereogram  -  The stereogram to view
    /// :param: indexPath   -  Index path of the stereogram in the photo store.
    /// :param: forApproval -  True if this presents a stereogram just taken for the user to accept or reject. False if this just displays a stereogram from the photo collection.
    /// :param: delegate    -  The delegate to send approval and dismissal messages.

    private init(    stereogram: Stereogram
        , atIndexPath indexPath: NSIndexPath?
        ,           forApproval: Bool
        ,              delegate: FullImageViewControllerDelegate) {
        self._stereogram = stereogram
        self._indexPath = indexPath
        self.delegate = delegate
        super.init(nibName: "FullImageView", bundle: nil)
        let toggleViewMethodButtonItem = UIBarButtonItem(title: "Toggle View Method"
            ,                                            style: .Plain
            ,                                           target: self
            ,                                           action: "changeViewingMethod:")
        // If we are using this to approve an image, then display "Keep" and "Discard" buttons.
        if forApproval {
            let keepButtonItem = UIBarButtonItem(title: "Keep"
                ,                                style: .Plain
                ,                               target: self
                ,                               action: "keepPhoto")
            let discardButtonItem = UIBarButtonItem(title: "Discard"
                ,                                   style: .Plain
                ,                                  target: self
                ,                                  action: "discardPhoto")
            self.navigationItem.rightBarButtonItems = [keepButtonItem, discardButtonItem]
            self.navigationItem.leftBarButtonItem = toggleViewMethodButtonItem
        } else {
            self.navigationItem.rightBarButtonItem = toggleViewMethodButtonItem
        }
    }
    
    /// Open in normal mode, viewing the index at the selected index path.
    ///
    /// :param: stereogram  -  The stereogram to view
    /// :param: indexPath   -  Index path of the stereogram in the photo store.
    /// :param: delegate    -  The delegate to send approval and dismissal messages.
    
    convenience init(stereogram: Stereogram, atIndexPath indexPath: NSIndexPath, delegate: FullImageViewControllerDelegate) {
        self.init(stereogram: stereogram, atIndexPath: indexPath, forApproval: false, delegate: delegate)
    }

    /// Open in approval mode.
    ///
    /// :param: stereogram  -  The stereogram to view
    /// :param: delegate    -  The delegate to send approval and dismissal messages.

    convenience init(stereogramForApproval: Stereogram, delegate: FullImageViewControllerDelegate) {
        self.init(stereogram: stereogramForApproval, atIndexPath: nil, forApproval: true, delegate: delegate)
    }
    
    // We create this manually instead of storing it in a NIB file.
    // If we decide to allow this, I'll need to do the equivalent to init(image:, forApproval:) outside the class.
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set the image now we know the view is loaded, and use that to set the bounds of the scrollview it's contained in.
        switch _stereogram.stereogramImage() {
        case .Success(let result):
            imageView.image = result.value
            imageView.sizeToFit()
        case .Error(let error):
            NSLog("Failed to load an image for stereogram \(_stereogram)")
        }
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
    
    /// The delegate to update according to the user's choices.
    unowned var delegate: FullImageViewControllerDelegate
    
    // MARK: Callbacks for the buttons.

    /// Tell the delegate to keep this photo and then dismisss the view controller.
    func keepPhoto() {
        delegate.fullImageViewController?(self, approvingStereogram: self._stereogram, result: .Accepted)
        delegate.dismissedFullImageViewController(self)
    }
    
    /// Tell the delegate to remove the photo and then dismiss the view controller.
    func discardPhoto() {
        delegate.fullImageViewController?(self, approvingStereogram: self._stereogram, result: .Discarded)
        delegate.dismissedFullImageViewController(self)
    }
    
    /// Toggle from cross-eye to wall-eye and back for the selected items.
    ///
    /// Create the new images on a separate thread, then call back to the main thread to replace them in the photo collection.
    @IBAction func changeViewingMethod(sender: AnyObject?) {
        showActivityIndicator = true
        var sgm = _stereogram, path = _indexPath
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            
            switch(self._stereogram.viewingMethod) {
            case .Crosseyed: sgm.viewingMethod = .Walleyed
            case .Walleyed : sgm.viewingMethod = .Crosseyed
            default:
                NSException(name:"Not implemented"
                    ,     reason:"Stereogram \(sgm) viewing method is not implemented."
                    ,   userInfo: nil).raise()
            }
            
            // Reload the image while we are in the background thread.
            let refreshResult = sgm.refresh()
            dispatch_async(dispatch_get_main_queue()) {
                
                switch refreshResult {
                case .Success():
                    // Clear the activity indicator and update the image in this view.
                    self.showActivityIndicator = false
                    switch sgm.stereogramImage() {
                    case .Success(let result):
                        self.imageView.image = result.value
                        self.imageView.sizeToFit()
                        // Notify the system that the image has been changed in the view.
                        self.delegate.fullImageViewController?(self, amendedStereogram: sgm, atIndexPath: path)
                    case .Error(let error):
                        self.showActivityIndicator = false
                        error.showAlertWithTitle("Error changing viewing method", parentViewController:self)
                    }
                case .Error(let error):
                    self.showActivityIndicator = false
                    error.showAlertWithTitle("Error changing viewing method", parentViewController: self)
                }
            }
        }
    }

    // MARK: Interface Builder

    /// The link to the image view displaying the stereogram image.
    @IBOutlet var imageView: UIImageView!
    
    /// The scrollview containing imageView.
    @IBOutlet var scrollView: UIScrollView!
    
    // MARK: - Scrollview Delegate
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    // MARK: - Private Data
    
    /// The stereogram we are displaying.
    
    private let _stereogram: Stereogram
    
    /// Optional index path if we are viewing an existing stereogram.
    
    private let _indexPath: NSIndexPath?
    
    /// An activity indicator we can show during lengthy operations.
    
    private let _activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    
    /// Indicate if the activity indicator should be shown or hidden.
    
    private var showActivityIndicator: Bool {
        get { return !_activityIndicator.hidden }
        set {
            _activityIndicator.hidden = !newValue
            if newValue {
                _activityIndicator.startAnimating()
            } else {
                _activityIndicator.stopAnimating()
            }
        }
    }

    /// Add the activity indicator and fit it into the frame.
    
    private func setupActivityIndicator() {
        // Add the activity indicator to the view if it is not there already. It starts off hidden.
        if !_activityIndicator.isDescendantOfView(view) {
            view.addSubview(_activityIndicator)
        }

        // Ensure the activity indicator fits in the frame.
        let activitySize = _activityIndicator.bounds.size
        let parentSize = view.bounds.size
        let frame = CGRectMake((parentSize.width / 2) - (activitySize.width / 2), (parentSize.height / 2) - (activitySize.height / 2), activitySize.width, activitySize.height)
        _activityIndicator.frame = frame
    }

    /// Calculate the appropriate size and zoom factor of the scrollview.
    ///
    /// :param: animated -  If True, the scrollview will animate to show the new changes.

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
