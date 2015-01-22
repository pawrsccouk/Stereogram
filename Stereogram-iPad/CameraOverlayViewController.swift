//
//  CameraOverlayViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 15/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

class CameraOverlayViewController: UIViewController {

    @IBOutlet weak var helpTextItem: UIBarButtonItem!
    @IBOutlet weak var crosshair: UIImageView!
    
    // Help text to display to the user during the image taking process.
    var helpText: String {
        get { return helpTextItem.title ?? "" }
        set { helpTextItem.title = newValue }
    }
    
    // If true, present an hourglass icon as the pad is processing in the background.
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
    
    var imagePickerController: UIImagePickerController!
    
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: "CameraOverlayView", bundle: nibBundleOrNil)
    }

    convenience override init() {
        self.init(nibName: nil, bundle: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        prepareActivityView()
    }
    
    // I am replacing the standard buttons with my own, so I have to forward the messages to the image picker.
    @IBAction func takePhoto(sender: AnyObject) {
        assert(imagePickerController != nil, "Camera controller is nil")
        imagePickerController.takePicture()
    }
    
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
    
    private let activityView: UIActivityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    
    // Return the frame used for the activity view, given the parent bounds and the child's size.
    private func activityFrame(parentBounds: CGRect, activitySize: CGSize) -> CGRect {
        var actFrame = CGRectZero
        actFrame.origin = CGPointMake((parentBounds.size.width / 2) - (activitySize.width / 2), (parentBounds.size.height / 2) - (activitySize.height / 2))
        actFrame.size = activitySize
        return actFrame
    }

    // Set up the activity view once the main view is in place.
    private func prepareActivityView() {
        if !self.activityView.isDescendantOfView(view) {
            view.addSubview(activityView)
        }
        activityView.frame = activityFrame(view.bounds, activitySize: activityView.bounds.size)
    }
}

