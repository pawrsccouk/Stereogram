//
//  FullImageViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 16/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.

import UIKit

@objc
enum ApprovalResult: Int {
	case Accepted, Discarded
}

// MARK: Delegate Protocol

/// Protocol for Image controller delegate.
/// Used to notify the caller when the user approves or rejects an image and to dismiss it.

@objc
protocol FullImageViewControllerDelegate {

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



// MARK: -





/// View controller presenting a view which will show a stereogram image at full size
///
/// There are two modes this controller can be in.
///  - View Mode: Show an existing image read-only.
///  - Approval Mode: Show a new image and allow the user to accept or reject it.

class FullImageViewController: UIViewController {

	/// The stereogram we are displaying.
	private let stereogram: Stereogram

	/// Optional index path if we are viewing an existing stereogram.
	private let indexPath: NSIndexPath?

	/// The bar button item that launches the viewing mode menu.
	/// Needed as we need to anchor the menu.
	private weak var viewingModeItem: UIBarButtonItem!

	/// An activity indicator we can show during lengthy operations.
	private let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)

	/// The delegate to update according to the user's choices.
	unowned var delegate: FullImageViewControllerDelegate

	// MARK: Outlets

	/// The link to the image view displaying the stereogram image.
	@IBOutlet var imageView: UIImageView!

	/// The scrollview containing imageView.
	@IBOutlet var scrollView: UIScrollView!

	// MARK: Initialisers

	/// Designated initialiser.
	/// If forApproval is YES, the view gets a 'Keep' button.
	/// If pressed, this button calls the delegate's approvedImage function,
	/// which should copy the image to permanent storage.
	///
	/// :param: stereogram  -  The stereogram to view
	/// :param: indexPath   -  Index path of the stereogram in the photo store.
	/// :param: forApproval -  True if this presents a stereogram just taken for the
	///                        user to accept or reject.
	///                        False if this just displays a stereogram from the photo collection.
	/// :param: delegate    -  The delegate to send approval and dismissal messages.

	private init(    stereogram: Stereogram
		, atIndexPath indexPath: NSIndexPath?
		,           forApproval: Bool
		,              delegate: FullImageViewControllerDelegate) {
			self.stereogram = stereogram
			self.indexPath = indexPath
			self.delegate = delegate
			super.init(nibName: "FullImageView", bundle: nil)
			let toggleViewMethodButtonItem = UIBarButtonItem(title: "Change View Method"
				,                                            style: .Plain
				,                                           target: self
				,                                           action: "selectViewingMethod:")
			viewingModeItem = toggleViewMethodButtonItem

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

	convenience init(stereogram: Stereogram
		, atIndexPath indexPath: NSIndexPath
		,              delegate: FullImageViewControllerDelegate) {
			self.init(stereogram: stereogram
				,    atIndexPath: indexPath
				,    forApproval: false
				,       delegate: delegate)
	}

	/// Open in approval mode.
	///
	/// :param: stereogram  -  The stereogram to view
	/// :param: delegate    -  The delegate to send approval and dismissal messages.

	convenience init(stereogramForApproval: Stereogram
		, delegate: FullImageViewControllerDelegate) {
			self.init(stereogram: stereogramForApproval
				,    atIndexPath: nil
				,    forApproval: true
				,       delegate: delegate)
	}

	// We create this manually instead of storing it in a NIB file.
	// If we decide to allow this, I'll need to do the equivalent to init(image:, forApproval:)
	// outside the class.
	required init(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

// MARK: Overrides

extension FullImageViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
		// Set the image now we know the view is loaded,
		// and use that to set the bounds of the scrollview it's contained in.
		switch stereogram.stereogramImage() {
		case .Success(let result):
			imageView.image = result.value
			imageView.sizeToFit()
		case .Error(let error):
			NSLog("Failed to load an image for stereogram \(stereogram)")
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
}

// MARK: - Callbacks
extension FullImageViewController {

	/// Tell the delegate to keep this photo and then dismisss the view controller.
	func keepPhoto() {
		delegate.fullImageViewController?(self
			, approvingStereogram: self.stereogram
			, result: .Accepted)
		delegate.dismissedFullImageViewController(self)
	}

	/// Tell the delegate to remove the photo and then dismiss the view controller.
	func discardPhoto() {
		delegate.fullImageViewController?(self
			, approvingStereogram: self.stereogram
			, result: .Discarded)
		delegate.dismissedFullImageViewController(self)
	}

	/// Prompt the user with a menu of possible viewing methods they can select.

	func selectViewingMethod(sender: AnyObject?) {

		let alertController = UIAlertController(title: "Select viewing style"
			,                                 message: "Choose one of the styles below"
			,                          preferredStyle: .ActionSheet)

		let animationAction = UIAlertAction(title: "Animation", style: .Default) { action in
			self.changeViewingMethod(.AnimatedGIF)
		}
		alertController.addAction(animationAction)

		let crossEyedAction = UIAlertAction(title: "Cross-eyed", style: .Default) { action in
			self.changeViewingMethod(.Crosseyed)
		}
		alertController.addAction(crossEyedAction)

		let wallEyedAction = UIAlertAction(title: "Wall-eyed", style: .Default) { action in
			self.changeViewingMethod(.Walleyed)
		}
		alertController.addAction(wallEyedAction)

		alertController.popoverPresentationController!.barButtonItem = viewingModeItem
		self.presentViewController(alertController, animated: true, completion: nil)
	}

	/// Change the viewing method of the stereogram we are viewing.
	///
	/// Create the new images on a separate thread,
	/// then call back to the main thread to replace them in the photo collection.
	///
	/// :param: viewMode The new viewing method.

	func changeViewingMethod(viewMode: ViewMode) {

		showActivityIndicator = true
		var sgm = stereogram, path = indexPath
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {

			sgm.viewingMethod = viewMode

			// Reload the image while we are in the background thread.
			let refreshResult = sgm.refresh()

			// Update the GUI on the main thread.
			dispatch_async(dispatch_get_main_queue()) {

				self.showActivityIndicator = false
				switch refreshResult {
				case .Success():
					// Clear the activity indicator and update the image in this view.
					switch sgm.stereogramImage() {
					case .Success(let result):
						self.imageView.image = result.value
						//self.imageView.sizeToFit()
						self.setupScrollviewAnimated(true)
						// Notify the system that the image has been changed in the view.
						self.delegate.fullImageViewController?(self
							,               amendedStereogram: sgm
							,                     atIndexPath: path)
					case .Error(let error):
						error.showAlertWithTitle("Error changing viewing method"
							, parentViewController:self)
					}
				case .Error(let error):
					error.showAlertWithTitle("Error changing viewing method"
						, parentViewController: self)
				}
			}
		}
	}


}

// MARK: - Activity Indicator

extension FullImageViewController {

	/// Indicate if the activity indicator should be shown or hidden.
	private var showActivityIndicator: Bool {
		get { return !activityIndicator.hidden }
		set {
			activityIndicator.hidden = !newValue
			if newValue {
				activityIndicator.startAnimating()
			} else {
				activityIndicator.stopAnimating()
			}
		}
	}

	/// Add the activity indicator and fit it into the frame.

	private func setupActivityIndicator() {
		// Add the activity indicator to the view if it is not there already. It starts off hidden.
		if !activityIndicator.isDescendantOfView(view) {
			view.addSubview(activityIndicator)
		}

		// Ensure the activity indicator fits in the frame.
		let activitySize = activityIndicator.bounds.size
		let parentSize = view.bounds.size
		let frame = CGRectMake((parentSize.width  / 2) - (activitySize.width  / 2)
			,                  (parentSize.height / 2) - (activitySize.height / 2)
			,                  activitySize.width
			,                  activitySize.height)
		activityIndicator.frame = frame
	}
}

// MARK: - Private Data

extension FullImageViewController {

	/// Calculate the appropriate size and zoom factor of the scrollview.
	///
	/// :param: animated -  If True, the scrollview will animate to show the new changes.

	private func setupScrollviewAnimated(animated: Bool) {
		assert(imageView.image != nil
			, "Controller \(self) imageView \(imageView) has no associated image")
		if let viewedImage = imageView.image {
			scrollView.contentSize = imageView.bounds.size

			// set the zoom info so the image fits in the window by default but can be zoomed in.
			// Respects the aspect ratio.
			let imageSize = viewedImage.size, viewSize = scrollView.bounds.size
			scrollView.maximumZoomScale = 1.0   // Cannot zoom in past original/full-size.
			scrollView.minimumZoomScale = min(viewSize.width  / imageSize.width
				,                             viewSize.height / imageSize.height)
			// Default to showing the whole image.
			scrollView.setZoomScale(scrollView.minimumZoomScale, animated: animated)
		}
	}
}

// MARK: - Scrollview Delegate
extension FullImageViewController: UIScrollViewDelegate {
	func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
		return imageView
	}
}



