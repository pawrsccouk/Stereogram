//
//  CameraOverlayViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 15/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

/// View Controller which presents a view to be placed above the camera view.
///
/// The view shows some help text and a crosshair. It also uses it's own 'take photo' and 'cancel' buttons, replacing the ones the camera would normally display.

class CameraOverlayViewController: UIViewController {

    /// Toolbar item showing progress text, e.g. "Taking First Picture"
    @IBOutlet weak var helpTextItem: UIBarButtonItem!

    /// A Crosshair image displayed in the centre of the camera view.
    @IBOutlet weak var crosshair: UIImageView!
    
    /// Help text to display to the user during the image taking process.
    var helpText: String {
        get { return helpTextItem.title ?? "" }
        set { helpTextItem.title = newValue }
    }
    
    /// If true, present an hourglass icon as the stereogram is being processed in the background.
    var showWaitIcon: Bool {
        get { return !activityView.hidden }
        set {
            activityView.hidden = !newValue
            crosshair.hidden = newValue
            if newValue {
                activityView.startAnimating()
            } else {
                activityView.stopAnimating()
            }
        }
    }
    
    /// The camera view controller that we are overshadowing.
    ///
    /// Photo messages (e.g "Take Photo", "Cancel") will be forwarded to this controller.
    
    var imagePickerController: UIImagePickerController!
    
    // MARK: Initilisers
    
    /// Initialize this controller to use the hard-coded camera overlay view XIB file.
    
    init() {
        super.init(nibName: "CameraOverlayView", bundle: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Overrides
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        prepareActivityView()
    }
    
    // MARK: Callback actions.
    
    /// Take a photo. 
    ///
    /// Forwards this message to the imagePickerController.
    
    @IBAction func takePhoto(sender: AnyObject) {
        // I am replacing the standard buttons with my own, so I have to forward the messages to the image picker.
        assert(imagePickerController != nil, "Camera controller is nil")
        imagePickerController.takePicture()
    }
    
    /// Cancel this operation.
    ///
    /// Forwards this message to the imagePickerController
    
    @IBAction func cancel(sender: AnyObject) {
        if let picker = imagePickerController {
            if let delegate = picker.delegate {
                if let method = delegate.imagePickerControllerDidCancel {
                    method(picker)
                    return
                } else {
                   fatalError("Delegate \(delegate) does not respond to the cancel message.")
                }
            }
        }
        fatalError("Camera controller is nil or has a nil delegate.")
    }

    // MARK: - Private members
    
    /// An activity view to display during long operations.
    
    private let activityView: UIActivityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)

    /// Set up the activity view once the main view is in place.
    
    private func prepareActivityView() {
        if !self.activityView.isDescendantOfView(view) {
            view.addSubview(activityView)
        }
        
        // Calculate a frame size so that the activity indicator is centred in it's parent view.
        let parentSize = view.bounds, activitySize = activityView.bounds.size
        let newSize = CGSizeMake(parentSize.width / 2, parentSize.height / 2)
        let origin = CGPointMake(newSize.width - (activitySize.width / 2), newSize.height - (activitySize.height / 2))
        let size = activityView.bounds.size
        activityView.frame = CGRectMake(origin.x, origin.y, size.width, size.height)
    }
}

