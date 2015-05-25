//
//  StereogramViewController.swif
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

class StereogramViewController: NSObject {

    /// The stereogram the user has taken, if any.

    var stereogram: Stereogram? {
        switch state {
        case .Complete(let stereogram): return stereogram
        default: return nil
        }
    }

    /// The delegate to notify when the view completes or is cancelled.

    var delegate: StereogramViewControllerDelegate = NullDelegate()

	/// The state we are in, i.e. where we are in the stereogram process.
	private var state = State.Ready

	/// The controller that presented this one.
	private weak var parentViewController: UIViewController!

	/// The camera overlay with help text and crosshairs.
	private let cameraOverlayController = CameraOverlayViewController()

	/// The camera view controller.
	private var pickerController: UIImagePickerController?

	/// The photo store where we will save the stereogram.
	private let photoStore: PhotoStore

	/// Initialize with a photo store.
    ///
    /// :param: photoStore - The photo store to work with.

    init(photoStore: PhotoStore) {
        self.photoStore = photoStore
        super.init()
    }

    /// Reset the controller back to the default state.
    /// If we stored a stereogram from a previous run it will be released,
	/// so you must have a reference to it already.

    func reset() {
        state = .Ready
        cameraOverlayController.helpText = "Take the first photo"
    }

    /// Display the camera, take the user through the specified steps to produce a stereogram image
    /// and put the result in self.stereogram.
    ///
    /// :param: parentViewController - The view controller handling the currently visible view.
	///         This controller will put its view on top of that view.

    func takePicture(parentViewController: UIViewController) {
        if !UIImagePickerController.isSourceTypeAvailable(.Camera) {
            let alertView = UIAlertView(title: "No camera"
				,                     message: "This device does not have a camera attached"
				,                    delegate: nil
				,           cancelButtonTitle: "Close")
			alertView.show()
            return
        }

        switch state {
        case .Ready, .Complete:

            self.parentViewController = parentViewController

            let picker = UIImagePickerController()
            picker.sourceType = .Camera
            picker.mediaTypes = [kUTTypeImage]  // Only accept still images, not movies.
            picker.delegate   = self
            picker.showsCameraControls = false
            pickerController = picker

            // Set up a custom overlay view for the camera.
			// Ensure our custom view frame fits within the camera view's frame.
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

    /// Dismisses the view controller that was presented modally by the receiver.
    ///
    /// :param: animated - Pass YES to animate the transition.
    /// :param: completion - The block to execute after the view controller is dismissed.

    func dismissViewControllerAnimated(animated: Bool, completion: (() -> Void)?) {
        if let picker = pickerController {
            picker.dismissViewControllerAnimated(animated, completion: completion)
        }
        pickerController = nil
    }
}

// MARK: - Navigation Controller Delegate
// We need to express that we support the delegate protocol even if we don't care about
// any of the options it gives us.
extension StereogramViewController: UINavigationControllerDelegate {
}

// MARK: Image Picker Delegate
extension StereogramViewController: UIImagePickerControllerDelegate {

    func imagePickerController(       picker: UIImagePickerController
        , didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {

        switch state {
        case .TakingFirstPhoto:
            state = .TakingSecondPhoto(firstPhoto: imageFromPickerInfoDict(info))
            cameraOverlayController.helpText = "Take the second photo"
            delegate.stereogramViewController?(self, takingPhoto: 2)

        case .TakingSecondPhoto(let firstPhoto):
            let secondPhoto = imageFromPickerInfoDict(info)
            cameraOverlayController.showWaitIcon = true

            // Make the stereogram on a separate thread to avoid blocking the UI thread.
			// The UI shows the wait indicator.
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                let result = self.photoStore.createStereogramFromLeftImage(firstPhoto
					,                                          rightImage: secondPhoto)

                // Once the stereogram is made, update the UI code back on the main thread.
                dispatch_async(dispatch_get_main_queue()) {
                    switch result {
                    case .Success(let image):
                        self.state = .Complete(stereogram: image.value)
                        self.cameraOverlayController.showWaitIcon = false
                        self.delegate.stereogramViewController(self, createdStereogram: image.value)
                    case .Error(let error):
                        if let parent = self.parentViewController {
                            error.showAlertWithTitle("Error creating the stereogram image"
								, parentViewController: parent)
                        } else {
                            NSLog("Error returned from makeStereogram() "
								+ "and no parent controller to display it on: \(error)")
                        }
                    }
                    self.state = .Ready
                }
            }
        default:
            fatalError("\(state) should be TakingFirstPhoto or TakingSecondPhoto")
        }
    }


    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        state = .Ready
        delegate.stereogramViewControllerWasCancelled(self)
    }
}

// MARK: - Private data
extension StereogramViewController {

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

    /// Get the edited photo from the info dictionary if the user has edited it.
    /// If there is no edited photo, get the original photo.
    ///
    /// :param: infoDict - The userInfo dictionary returned from the image picker controller
	///                    with the selected image in it.
    /// :returns: The UIImage taken from the dictionary.
    ///
    /// If there is no original photo, terminate with an error.

    private func imageFromPickerInfoDict(infoDict: [NSObject : AnyObject]) -> UIImage {
        if let photo = infoDict[UIImagePickerControllerEditedImage] as? UIImage {
            return photo
        }
        if let d = infoDict[UIImagePickerControllerOriginalImage] as? UIImage {
            return d
        } else {
            assert(false, "Image for key \(UIImagePickerControllerOriginalImage) "
				+ "not found in dict \(infoDict)")
            return UIImage()
        }
    }

}

/// A Do-nothing delegate object which by default just dismisses the view controller
/// without caring about the stereogram.

private class NullDelegate: NSObject, StereogramViewControllerDelegate {

    @objc private func stereogramViewController(controller: StereogramViewController
        ,                     createdStereogram stereogram: Stereogram) {
        controller.dismissViewControllerAnimated(false, completion: nil)
    }

    @objc private func stereogramViewControllerWasCancelled(controller: StereogramViewController) {
        controller.dismissViewControllerAnimated(false, completion: nil)
    }
}
