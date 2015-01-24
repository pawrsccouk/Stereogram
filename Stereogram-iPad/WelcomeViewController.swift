//
//  WelcomeViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 24/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

// This class manages a welcome view, which is currently an HTML View, which will display friendly information to the new user.
// It has its own stereogram view controller, which it uses to present the camera for the first photo.
// Once it determines we have at least one image to display, it requests it's parent navigation controller to dismiss itself. This should leave the photo collection view as the only view displayed.

class WelcomeViewController : UIViewController {
    @IBOutlet weak var webView: UIWebView!
    
    var photoStore: PhotoStore!
    
    // MARK: Initialisers
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: "WelcomeView", bundle: nibBundleOrNil)
    }

    convenience override init() {
        self.init(nibName: nil, bundle: nil)
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
    
    override func viewDidAppear(animated: Bool) {
        // If svc has a stereogram, then store it in the photo store.
        if let stereogram = stereogramViewController.stereogram {
            showApprovalWindowForImage(stereogram)
            stereogramViewController.reset()
        }
    }
    
    
    // MARK: Callbacks
    
    func takePicture() {
        stereogramViewController.takePicture(self)
    }

    // MARK: - Private Data
    
    private let welcomeHTML = "<HTML><HEAD/><BODY><P>Welcome to Stereogram</P></BODY><HTML>"
    private var stereogramViewController = StereogramViewController()
    
    // Called to present the image to the user, with options to accept or reject it.
    // If the user accepts, the photo is added to the photo store.
    private func showApprovalWindowForImage(image: UIImage) {
        let dateTaken = NSDate()
        let fullImageViewController = FullImageViewController(image: image, forApproval: true)
        
        // Add the image to the store if the user has approved it.
        fullImageViewController.approvalCallback = { newImage in
            self.photoStore.addImage(newImage, dateTaken: dateTaken).onError( { error in
                error.showAlertWithTitle("Error saving photo", parentViewController: self)
            })
        }
        
        if let parentController = self.navigationController {
            
            fullImageViewController.dismissCallback = {
                // Once the FullImageViewController is dismissed, check if we have now got some photos to display. If so, dismiss the welcome controller to reveal the photo controller, which should be the at the root of the controller hierarchy.
                if self.photoStore.count > 0 {
                    parentController.popToRootViewControllerAnimated(false)
                }
            }

            let navigationController = UINavigationController(rootViewController: fullImageViewController)
            navigationController.modalPresentationStyle = .FullScreen
            presentViewController(navigationController, animated: true, completion: nil)
        }
    }
}
