//
//  StereogramViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 22/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

// TODO: Make state explicit
// TODO: Add callback when photo process is complete.
// (Currently I'm having to trigger the check when the parent view becomes visible, which is very inelegant.)

import UIKit
import MobileCoreServices

// This class manages the stereogram view, creating the camera overlay controller, presenting them both and acting as delegate for the camera.
// It encapsulates the state needed to take a stereogram and just holds the completed stereogram in stereogram.

class StereogramViewController : NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // The stereogram the user has taken, if any.
    var stereogram: UIImage?

    override init() {
        cameraOverlayController = CameraOverlayViewController()
        super.init()
    }
    
    // Display the camera above the specified view controller, take the user through the specified steps to produce a stereogram image and put the result in self.stereogram.
    
    func takePicture(parentViewController: UIViewController) {
        stereogram = nil
        firstPhoto = nil
        
        if !UIImagePickerController.isSourceTypeAvailable(.Camera) {
            UIAlertView(title: "No camera", message: "This device does not have a camera attached", delegate: nil, cancelButtonTitle: "Close").show()
            return
        }
        
        let pickerController = UIImagePickerController()
        pickerController.sourceType = .Camera
        pickerController.mediaTypes = [kUTTypeImage]  // This is the default.
        pickerController.delegate   = self
        pickerController.showsCameraControls = false
        
        // Set up a custom overlay view for the camera. Ensure our custom view frame fits within the camera view's frame.
        cameraOverlayController.view.frame = pickerController.view.frame
        pickerController.cameraOverlayView = cameraOverlayController.view
        cameraOverlayController.imagePickerController = pickerController
        
        parentViewController.presentViewController(pickerController, animated: true, completion: nil)
    }

    // MARK: - Image Picker Delegate
    
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        assert(stereogram == nil, "Stereogram \(stereogram) must be nil.")
        // We need to get 2 photos, so the first time we enter here, we store the image and prompt the user to take the second photo.
        // Next time we enter here, we compose the 2 photos into the final montage and this is what we store. We also dismiss the photo chooser at that point.
        if firstPhoto == nil {
            firstPhoto = imageFromPickerInfoDict(info)
            cameraOverlayController.helpText = "Take the second photo"
        } else {
            let makeStereogram = { (firstPhoto: UIImage, secondPhoto: UIImage) -> ResultOf<UIImage> in
                return ImageManager.makeStereogramWithLeftPhoto(firstPhoto, rightPhoto: secondPhoto).map { (stereogram) -> ResultOf<UIImage> in
                    let resizedStereogram = stereogram.resizedImage(CGSizeMake(stereogram.size.width / 2, stereogram.size.height / 2), interpolationQuality: kCGInterpolationHigh)
                    return ResultOf(resizedStereogram)
                }
            }
            let secondPhoto = imageFromPickerInfoDict(info)
            if let first = firstPhoto {
                if let second = secondPhoto {
                    cameraOverlayController.showWaitIcon = true
                    
                    // Make the stereogram on a separate thread to avoid blocking the UI thread.  The UI shows the wait indicator.
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
                        switch makeStereogram(first, second) {
                        case .Success(let image):
                            // Once the stereogram is made, update the UI code back on the main thread.
                            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                                self.stereogram = image.value
                                self.firstPhoto = nil
                                picker.dismissViewControllerAnimated(false, completion: nil)
                                self.cameraOverlayController.showWaitIcon = false
                            }
                        case .Error(let error):
                            error.showAlertWithTitle("Error creating the stereogram image")
                        }
                    }
                }
                else {  // Something went wrong. No second photo.
                    picker.dismissViewControllerAnimated(false, completion: nil)
                    fatalError("The media info \(info) had no picture information when taking a photo.")
                }
            }
        }
    }
    
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        picker.dismissViewControllerAnimated(true, completion: nil)
        firstPhoto = nil
    }
    
    // MARK: - Private data
    
    private let cameraOverlayController: CameraOverlayViewController
    // This is the first of the two images we store when taking the stereogram.
    // State-based -only relevant when in the process of taking a photo. TODO: Move to a state-machine instead of a boolean flag.
    private var firstPhoto: UIImage?
    
    // Get the edited photo from the info dictionary if the user has edited it. If there is no edited photo, get the original photo.
    private func imageFromPickerInfoDict(infoDict: [NSObject : AnyObject]) -> UIImage? {
        if let photo = infoDict[UIImagePickerControllerEditedImage] as UIImage? {
            return photo
        }
        return infoDict[UIImagePickerControllerOriginalImage] as UIImage?
    }
    
}

