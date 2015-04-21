//
//  StereogramViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 22/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit
import MobileCoreServices

/// Protocol for delegates of the stereogram view controller. 
///
/// Contains notifications sent during the stereogram taking process 
/// and provides the stereogram to the user once it has been taken.

@objc protocol StereogramViewControllerDelegate {
    
    /// Triggered when the controller starts displaying the camera view. 
    ///
    /// :param: controller -  The controller that sent this message.
    /// :param: photoNumber - Will be 1 or 2 depending on which photo is being taken.

    optional func stereogramViewController(controller: StereogramViewController,
                              takingPhoto photoNumber: Int)
    
    /// Called when the stereogram has been taken. 
    ///
    /// The delegate must save the image and dismiss the view controller.
    ///
    /// :param: stereogram -  The stereogram the user has just finished taking.
    /// :param: controller -  The controller that sent this message.

    func stereogramViewController(controller: StereogramViewController
        ,       createdStereogram stereogram: Stereogram)
    
    /// Called if the user cancels the view controller and doesn't want to create a stereogram.  
    /// 
    /// The delegate must dismiss the view controller.
    ///
    /// :param: controller -  The controller that sent this message.
    
    func stereogramViewControllerWasCancelled(controller: StereogramViewController)
}

/// This class manages the stereogram view, creating the camera overlay controller, 
/// presenting them both and acting as delegate for the camera.
///
/// It encapsulates the state needed to take a stereogram and just holds the completed stereogram.

class StereogramViewController : NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    /// The stereogram the user has taken, if any.
    
    var stereogram: Stereogram? {
        switch _state {
        case .Complete(let stereogram): return stereogram
        default: return nil
        }
    }
    
    /// The delegate to notify when the view completes or is cancelled.
    
    var delegate: StereogramViewControllerDelegate = NullDelegate()

    /// Initialize with a photo store.
    ///
    /// :param: photoStore - The photo store to work with.
    
    init(photoStore: PhotoStore) {
        _photoStore = photoStore
        super.init()
    }
    
    /// Reset the controller back to the default state. 
    /// If we stored a stereogram from a previous run it will be released, so you must have a reference to it already.
    
    func reset() {
        _state = .Ready
        _cameraOverlayController.helpText = "Take the first photo"
    }
    
    /// Display the camera, take the user through the specified steps to produce a stereogram image 
    /// and put the result in self.stereogram.
    ///
    /// :param: parentViewController - The view controller handling the currently visible view. This controller will put its view on top of that view.
    
    func takePicture(parentViewController: UIViewController) {
        if !UIImagePickerController.isSourceTypeAvailable(.Camera) {
            UIAlertView(title: "No camera", message: "This device does not have a camera attached", delegate: nil, cancelButtonTitle: "Close").show()
            return
        }

        switch _state {
        case .Ready, .Complete:
            
            _parentViewController = parentViewController
            
            let picker = UIImagePickerController()
            picker.sourceType = .Camera
            picker.mediaTypes = [kUTTypeImage]  // Only accept still images, not movies.
            picker.delegate   = self
            picker.showsCameraControls = false
            _pickerController = picker
            
            // Set up a custom overlay view for the camera. Ensure our custom view frame fits within the camera view's frame.
            _cameraOverlayController.view.frame = picker.view.frame
            picker.cameraOverlayView = _cameraOverlayController.view
            _cameraOverlayController.imagePickerController = _pickerController
            _cameraOverlayController.helpText = "Take the first photo"

            _parentViewController.presentViewController(picker, animated: true, completion: nil)
            
            _state = .TakingFirstPhoto
            delegate.stereogramViewController?(self, takingPhoto: 1)
            
        case .TakingFirstPhoto, .TakingSecondPhoto:
            fatalError("State \(_state) was invalid. Another photo operation already in progress.")
        }
    }
    
    /// Dismisses the view controller that was presented modally by the receiver.
    ///
    /// :param: animated - Pass YES to animate the transition.
    /// :param: completion - The block to execute after the view controller is dismissed.

    func dismissViewControllerAnimated(animated: Bool, completion: (() -> Void)?) {
        if let picker = _pickerController {
            picker.dismissViewControllerAnimated(animated, completion: completion)
        }
        _pickerController = nil
    }

    // MARK: - Image Picker Delegate
    
    func imagePickerController(       picker: UIImagePickerController
        , didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
            
        switch _state {
        case .TakingFirstPhoto:
            
            let firstPhoto = imageFromPickerInfoDict(info)
            _state = .TakingSecondPhoto(firstPhoto: firstPhoto)
            _cameraOverlayController.helpText = "Take the second photo"
            delegate.stereogramViewController?(self, takingPhoto: 2)
            
        case .TakingSecondPhoto(let firstPhoto):
            
            let secondPhoto = imageFromPickerInfoDict(info)
            _cameraOverlayController.showWaitIcon = true
            
            // Make the stereogram on a separate thread to avoid blocking the UI thread.  The UI shows the wait indicator.
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
                
                let result = self._photoStore.createStereogramFromLeftImage(firstPhoto, rightImage: secondPhoto)
                
                // Once the stereogram is made, update the UI code back on the main thread.
                dispatch_async(dispatch_get_main_queue()) {
                    
                    switch result {
                    case .Success(let image):
                        self._state = .Complete(stereogram: image.value)
                        self._cameraOverlayController.showWaitIcon = false
                        self.delegate.stereogramViewController(self, createdStereogram: image.value)
                        
                    case .Error(let error):
                        if let parent = self._parentViewController {
                            error.showAlertWithTitle("Error creating the stereogram image", parentViewController: parent)
                        } else {
                            NSLog("Error \(error) returned from makeStereogram(), no parent controller to display it on.")
                        }
                    }
                    self._state = .Ready
                }
            }
            
        default:
            fatalError("Inconsistent state of \(_state), should be TakingFirstPhoto or TakingSecondPhoto")
        }
    }
    
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        _state = .Ready
        delegate.stereogramViewControllerWasCancelled(self)
    }
    
    // MARK: - Private data
    
    /// This controller can be in multiple states. Capture these here.
    ///
    /// - Ready:             The process has not started yet.
    /// - TakingFirstPhoto:  We are currently taking the first photo.
    /// - TakingSecondPhoto: We are currently taking the second photo.
    /// - Complete:          We have taken both photos and composited them into a stereogram.
    
    private enum State {
        
        /// The photo process has not started yet.
        case Ready
        
        /// We are currently taking the first photo
        case TakingFirstPhoto
        
        /// We are currently taking the second photo. 
        ///
        /// :param: firstPhoto - Contains the first photo we took
        case TakingSecondPhoto(firstPhoto: UIImage)
        
        /// We have taken both photos and composited them into a stereogram.
        ///
        /// :param: sterogram - The stereogram we've just created.
        case Complete(stereogram: Stereogram)
        
        /// Standard initializer. Defaults this object to the Ready state.
        
        init() {
            self = .Ready
        }
        
        /// Description of the enumeration in human-readable text.
        var description: String {
            switch self {
            case .Ready: return "Ready"
            case .TakingFirstPhoto: return "TakingFirstPhoto"
            case .TakingSecondPhoto: return "TakingSecondPhoto"
            case .Complete: return "Complete"
            }
        }
    }
    
    /// The state we are in, i.e. where we are in the stereogram process.
    private var _state = State.Ready
    
    /// The controller that presented this one.
    private weak var _parentViewController: UIViewController!

    /// The camera overlay with help text and crosshairs.
    private let _cameraOverlayController = CameraOverlayViewController()

    /// The camera view controller.
    private var _pickerController: UIImagePickerController?

    /// The photo store where we will save the stereogram.
    private let _photoStore: PhotoStore

    /// Get the edited photo from the info dictionary if the user has edited it. 
    /// If there is no edited photo, get the original photo. 
    ///
    /// :param: infoDict - The userInfo dictionary returned from the image picker controller with the selected image in it.
    /// :returns: The UIImage taken from the dictionary.
    ///
    /// If there is no original photo, terminate with an error.
    
    private func imageFromPickerInfoDict(infoDict: [NSObject : AnyObject]) -> UIImage {
        if let photo = infoDict[UIImagePickerControllerEditedImage] as? UIImage {
            return photo
        }
        return infoDict[UIImagePickerControllerOriginalImage] as! UIImage
    }
    
}

/// A Do-nothing delegate object which by default just dismisses the view controller without caring about the stereogram.

private class NullDelegate : NSObject, StereogramViewControllerDelegate {
    
    @objc private func stereogramViewController(controller: StereogramViewController
        ,                     createdStereogram stereogram: Stereogram) {
        controller.dismissViewControllerAnimated(false, completion: nil)
    }
    
    @objc private func stereogramViewControllerWasCancelled(controller: StereogramViewController) {
        controller.dismissViewControllerAnimated(false, completion: nil)
    }
}
