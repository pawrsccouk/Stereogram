//
//  WelcomeViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 24/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

/// This class manages a welcome view, which is currently an HTML View, which will display friendly information to the new user.
/// It has its own stereogram view controller, which it uses to present the camera for the first photo.
///
/// Once it determines we have at least one image to display, it requests it's parent navigation controller to dismiss itself. This should leave the photo collection view as the only view displayed.

class WelcomeViewController : UIViewController, FullImageViewControllerDelegate, StereogramViewControllerDelegate {
    
    /// Interface Builder outlet - Show a web view with some welcome text on it.
    @IBOutlet weak var webView: UIWebView!
    
    /// The collection of stereograms.
    private let _photoStore: PhotoStore
    
    // MARK: Initialisers
    
    /// Initialise with a photo store.
    /// Designated initializer
    ///
    /// :param: photoStore - The photo store to work with.
    init(photoStore: PhotoStore) {
        self._photoStore = photoStore
        stereogramViewController = StereogramViewController(photoStore: photoStore)
        super.init(nibName: "WelcomeView", bundle: nil)
        stereogramViewController.delegate = self
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add a button for the camera on the right, and hide the back button on the left.
        let takePhotoItem = UIBarButtonItem(barButtonSystemItem: .Camera, target: self, action: "takePicture")
        navigationItem.rightBarButtonItem = takePhotoItem
        navigationItem.hidesBackButton = true
        
        // Give some text to display.
        webView.loadHTMLString(welcomeHTML, baseURL: nil)
    }
    
    // MARK: - Callbacks
    
    /// Trigger the camera view controller to allow the user to start taking photos.
    func takePicture() {
        stereogramViewController.takePicture(self)
    }

    // MARK: FullImageController delegate
    
    
    func fullImageViewController(controller: FullImageViewController
        ,    approvingStereogram stereogram: Stereogram
        ,                            result: ApprovalResult) {
            if result == .Discarded {
                switch _photoStore.deleteStereogram(stereogram) {
                case .Error(let error):
                    error.showAlertWithTitle("Error removing photo", parentViewController: self)
                default:
                    break
                }
            }
    }
    
    func dismissedFullImageViewController(controller: FullImageViewController) {
        // Remove the controller from the stack.
        controller.dismissViewControllerAnimated(false) { [p = self.navigationController!] in
            // Once the FullImageViewController is dismissed, check if we have now got some photos to display. If so, dismiss the welcome controller to reveal the photo controller, which should be the at the root of the controller hierarchy.
            if self._photoStore.count > 0 {
                p.popToRootViewControllerAnimated(true)
            }
        }
    }
    
    // MARK: StereogramViewController delegate
    
    func stereogramViewController(controller: StereogramViewController
        ,       createdStereogram stereogram: Stereogram) {
        controller.reset()
        controller.dismissViewControllerAnimated(false) {
            // Once the stereogram view has disappeared, display the FullImage view to allow the user to keep or reject the requested image.
            self.showApprovalWindowForStereogram(stereogram)
        }
    }
    
    func stereogramViewControllerWasCancelled(controller: StereogramViewController) {
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: - Private Data
    
    private let welcomeHTML = "<HTML><HEAD/><BODY><P>Welcome to Stereogram</P></BODY><HTML>"
    private let stereogramViewController: StereogramViewController
    
    // Called to present the image to the user, with options to accept or reject it.
    // If the user accepts, the photo is added to the photo store.
    private func showApprovalWindowForStereogram(stereogram: Stereogram) {
        let dateTaken = NSDate()
        let fullImageViewController = FullImageViewController(stereogramForApproval: stereogram
            ,                                                              delegate: self)
        
        let navigationController = UINavigationController(rootViewController: fullImageViewController)
        navigationController.modalPresentationStyle = .FullScreen
        presentViewController(navigationController, animated: true, completion: nil)
    }
}
