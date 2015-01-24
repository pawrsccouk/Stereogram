//
//  StereogramViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 22/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

// TODO: Add callback when photo process is complete.
// (Currently I'm having to trigger the check when the parent view becomes visible, which is very inelegant.)

import UIKit
import MobileCoreServices


@objc protocol StereogramViewControllerDelegate {
    
    // Triggered when the controller starts displaying the camera view. photoNumber will be 1 or 2 depending on which photo is being taken.
    optional func stereogramViewController(controller: StereogramViewController, takingPhoto photoNumber: UInt)
    
    // Called when the stereogram has been taken. Here you need to save the image and dismiss the view controller.
    func stereogramViewController(controller: StereogramViewController, createdStereogram stereogram: UIImage)
    
    // Called if the user cancels the view controller and doesn't want to create a stereogram.  The delegate must dismiss the view controller here.
    func stereogramViewControllerWasCancelled(controller: StereogramViewController)
}

// This class manages the stereogram view, creating the camera overlay controller, presenting them both and acting as delegate for the camera.
// It encapsulates the state needed to take a stereogram and just holds the completed stereogram.

class StereogramViewController : NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

   // The stereogram the user has taken, if any.
    var stereogram: UIImage? {
        switch state {
        case .Complete(let stereogram): return stereogram
        default: return nil
        }
    }
    
    unowned var delegate: StereogramViewControllerDelegate
    
    init(delegate: StereogramViewControllerDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    // Reset the controller back to the default state. If we stored a stereogram from a previous run, it will be destroyed here, so take a copy first.
    func reset() {
        state = .Ready
        cameraOverlayController.helpText = "Take the first photo"
    }
    
    // Display the camera above the specified view controller, take the user through the specified steps to produce a stereogram image and put the result in self.stereogram.
    
    func takePicture(parentViewController: UIViewController) {
        if !UIImagePickerController.isSourceTypeAvailable(.Camera) {
            UIAlertView(title: "No camera", message: "This device does not have a camera attached", delegate: nil, cancelButtonTitle: "Close").show()
            return
        }

        switch state {
        case .Ready, .Complete:
            
            self.parentViewController = parentViewController
            
            let picker = UIImagePickerController()
            pickerController = picker
            picker.sourceType = .Camera
            picker.mediaTypes = [kUTTypeImage]  // This is the default.
            picker.delegate   = self
            picker.showsCameraControls = false
            
            // Set up a custom overlay view for the camera. Ensure our custom view frame fits within the camera view's frame.
            cameraOverlayController.view.frame = picker.view.frame
            picker.cameraOverlayView = cameraOverlayController.view
            cameraOverlayController.imagePickerController = pickerController
            cameraOverlayController.helpText = "Take the first photo"

            parentViewController.presentViewController(picker, animated: true, completion: nil)
            
            state = .TakingFirstPhoto
            delegate.stereogramViewController?(self, takingPhoto: 1)
            
        case .TakingFirstPhoto, .TakingSecondPhoto:
            fatalError("State \(state) was invalid. Another photo operation already in progress.")
        }
    }
    
    func dismissViewControllerAnimated(animated: Bool, completion: (() -> Void)?) {
        if let picker = pickerController {
            picker.dismissViewControllerAnimated(animated, completion: completion)
        }
        pickerController = nil
    }

    // MARK: - Image Picker Delegate
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        switch state {
        case .TakingFirstPhoto:
            
            let firstPhoto = imageFromPickerInfoDict(info)
            state = .TakingSecondPhoto(firstPhoto: firstPhoto)
            cameraOverlayController.helpText = "Take the second photo"
            delegate.stereogramViewController?(self, takingPhoto: 2)
            
        case .TakingSecondPhoto(let firstPhoto):
            
            func makeStereogram(firstPhoto: UIImage, secondPhoto: UIImage) -> ResultOf<UIImage>  {
                return ImageManager.makeStereogramWithLeftPhoto(firstPhoto, rightPhoto: secondPhoto).map { (stereogram) -> ResultOf<UIImage> in
                    let resizedStereogram = stereogram.resizedImage(CGSizeMake(stereogram.size.width / 2, stereogram.size.height / 2), interpolationQuality: kCGInterpolationHigh)
                    return ResultOf(resizedStereogram)
                }
            }
            let secondPhoto = imageFromPickerInfoDict(info)
            cameraOverlayController.showWaitIcon = true
            
            // Make the stereogram on a separate thread to avoid blocking the UI thread.  The UI shows the wait indicator.
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
                switch makeStereogram(firstPhoto, secondPhoto) {
                case .Success(let image):
                    // Once the stereogram is made, update the UI code back on the main thread.
                    dispatch_async(dispatch_get_main_queue()) {
                        self.state = .Complete(stereogram: image.value)
                        //picker.dismissViewControllerAnimated(false, completion: nil)
                        self.cameraOverlayController.showWaitIcon = false
                        self.delegate.stereogramViewController(self, createdStereogram: image.value)
                    }
                case .Error(let error):
                    if let parent = self.parentViewController {
                        error.showAlertWithTitle("Error creating the stereogram image", parentViewController: parent)
                    } else {
                        NSLog("Error \(error) returned from makeStereogram(), no parent controller to display it on.")
                    }
                    self.state = .Ready
                }
            }
        default:
            fatalError("Inconsistent state of \(state), should be TakingFirstPhoto or TakingSecondPhoto")
        }
    }
    
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        //picker.dismissViewControllerAnimated(true, completion: nil)
        state = .Ready
        delegate.stereogramViewControllerWasCancelled(self)
    }
    
    // MARK: - Private data
    
    // This controller can be in multiple states. Capture these here.
    private enum State {
        // The photo process has not started yet.
        case Ready
        // We are currently taking the first photo
        case TakingFirstPhoto
        // We are currently taking the second photo. firstPhoto contains the first photo we took
        case TakingSecondPhoto(firstPhoto: UIImage)
        // We have taken both photos and composited them into a stereogram.
        case Complete(stereogram: UIImage)
        
        init() {
            self = .Ready
        }
        
        var description: String {
            switch self {
            case .Ready: return "Ready"
            case .TakingFirstPhoto: return "TakingFirstPhoto"
            case .TakingSecondPhoto: return "TakingSecondPhoto"
            case .Complete: return "Complete"
            }
        }
    }
    
    private var state = State.Ready
    
    private weak var parentViewController: UIViewController!
    private let cameraOverlayController = CameraOverlayViewController()
    private var pickerController: UIImagePickerController?

    // Get the edited photo from the info dictionary if the user has edited it. If there is no edited photo, get the original photo. If there is no original photo, terminate with an error.
    private func imageFromPickerInfoDict(infoDict: [NSObject : AnyObject]) -> UIImage {
        if let photo = infoDict[UIImagePickerControllerEditedImage] as? UIImage {
            return photo
        }
        return infoDict[UIImagePickerControllerOriginalImage] as UIImage
    }
    
}

