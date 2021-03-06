//
//  ViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 11/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit
import MessageUI

/// A view controller which manages a view displaying a collection of sterogram images
/// and presents a menu allowing users to modify or delete them.

class PhotoViewController: UIViewController {

	/// Reference to the collection this view controller manages.

	@IBOutlet weak var photoCollection: UICollectionView!

	// MARK: Constructors

	/// Initialize with a photo store.
	///
	/// :param: photoStore - The photo store to display.

	init(photoStore: PhotoStore) {
		self.photoStore = photoStore
		stereogramViewController = StereogramViewController(photoStore: photoStore)
		super.init(nibName: "PhotoView", bundle: nil)
		stereogramViewController.delegate = self
	}

	// View controllers are created manually for this project. This should never be called.
	required init(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: Overrides

	override func viewDidLoad() {
		super.viewDidLoad()
		// Connect up the thumbnail provider as data source to the collection view.
		if thumbnailProvider == nil {
			thumbnailProvider = CollectionViewThumbnailProvider(photoStore: photoStore
				,                                          photoCollection: photoCollection)
		}

		setupNavigationButtons()
		photoCollection.allowsSelection = true
		photoCollection.allowsMultipleSelection = true

		// Set the thumbnail size from the store
		if let flowLayout = photoCollection.collectionViewLayout as? UICollectionViewFlowLayout {
			flowLayout.itemSize = thumbnailSize
			flowLayout.invalidateLayout()
		}
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		setupActivityIndicator()
	}

	override func setEditing(editing: Bool, animated: Bool) {
		super.setEditing(editing, animated: animated)
		// Clear the selected ticks once we stop editing the photo collection.
		if !self.editing,
			let pathArray = photoCollection.indexPathsForSelectedItems() as? [NSIndexPath] {
				for indexPath in pathArray {
					photoCollection.deselectItemAtIndexPath(indexPath, animated: animated)
				}
		}
	}



	// MARK: Callbacks

	/// Trigger the stereogram view controller and start the picture-taking process.

	func takePicture() {
		stereogramViewController.takePicture(self)
	}

	/// Present a menu of possible actions for the selected stereograms.

	func actionMenu() {
		let alertController = UIAlertController(title: "Select an action"
			, message: ""
			, preferredStyle: UIAlertControllerStyle.ActionSheet)

		let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)

		let deleteAction = UIAlertAction(title: "Delete", style: .Destructive) {
			[unowned self] (action) in
			self.deletePhotos(self.photoCollection)
		}
		let copyAction = UIAlertAction(title: "Copy to gallery", style: .Default) {
			[unowned self] (action) in
			if let p = self.photoCollection.indexPathsForSelectedItems() as? [NSIndexPath] {
				self.copyPhotosToCameraRoll(p)
			}
		}
		let emailAction = UIAlertAction(title: "Email", style: .Default) {
			(action) in
			if let p = self.photoCollection.indexPathsForSelectedItems() as? [NSIndexPath] {
				self.sendPhotosViaEmail(p)
			}
		}
		alertController.addActions([cancelAction, deleteAction, copyAction, emailAction])
		alertController.popoverPresentationController!.barButtonItem = exportItem
		self.presentViewController(alertController, animated: true, completion: nil)
	}

	/// Present an image view showing a given stereogram.
	///
	/// :param: indexPath - The index path of the sterogram in the current photo collection.

	func showStereogramAtIndexPath(indexPath: NSIndexPath) {
		let stereogram = photoStore.stereogramAtIndex(indexPath.item)
		let fullImageController = FullImageViewController(stereogram: stereogram
			,                                            atIndexPath: indexPath
			,                                               delegate: self)
		navigationController?.pushViewController(fullImageController
			,                          animated: true)
	}

	/// Called to present a stereogram to the user and give them options to accept or reject it.
	///
	/// :param: stereogram - The stereogram to display.

	func showApprovalWindowForStereogram(stereogram: Stereogram) {
		let fullImageViewController = FullImageViewController(stereogramForApproval: stereogram
			,                                       delegate: self)
		let navigationController = UINavigationController(rootViewController: fullImageViewController)
		navigationController.modalPresentationStyle = .FullScreen
		presentViewController(navigationController, animated: true, completion: nil)
	}

	// MARK: - Private data

	/// The photo store whose stereograms we are displaying.
	private let photoStore: PhotoStore

	/// Toolbar button items we add to the view.
	private var exportItem: UIBarButtonItem?, editItem: UIBarButtonItem?

	/// An activity indicator we can present for long-running operations.
	private let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)

	/// This retrieves thumbnails from the photo store for a given collection view.
	private var thumbnailProvider: CollectionViewThumbnailProvider?

	/// The controller used to present a view for taking the stereogram images.
	private let stereogramViewController: StereogramViewController


	/// HTML text to use as an email body.
	///
	/// Contains two replaceable parameters:
	///
	/// #. Text to use for the main body. Example: "Here are 2 images exported from Stereogram"
	/// #. A date on which they were exported.

	private let emailBodyTemplate = "\n".join([
		"<html>",
		"  <head/>",
		"  <body>",
		"    <H1>Exported Stereograms</H1>",
		"    <p>%@<br/>",
		"       Exported on %@",
		"    </p>",
		"  </body>",
		"</html>",
		])
}

// MARK: - Collection View Delegate
extension PhotoViewController: UICollectionViewDelegate {

	func collectionView(      collectionView: UICollectionView
		, didSelectItemAtIndexPath indexPath: NSIndexPath) {
			// In editing mode, this doesn't need to do anything as the status flag on the cell
			// has already been updated.
			// In viewing mode, we need to revert this status-flag update,
			// and then pop the full-image view onto the navigation stack.
			if !editing {
				collectionView.deselectItemAtIndexPath(indexPath
					,                        animated: false)
				showStereogramAtIndexPath(indexPath)
			}
	}

	func collectionView(        collectionView: UICollectionView
		, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
			// If we are in viewing mode, then any click on a thumbnail -to select or deselect-
			// we translate into a request to show the full-image view.
			if !editing {
				showStereogramAtIndexPath(indexPath)
			}
	}
}


// MARK: FullImageController delegate
extension PhotoViewController: FullImageViewControllerDelegate {
	func fullImageViewController(controller: FullImageViewController
		,   amendedStereogram newStereogram: Stereogram
		,             atIndexPath indexPath: NSIndexPath?) {
			// If indexPath is nil, we are calling it for approval.
			// In which case, don't do anything, as we will handle it in the approvedImage delegate method.
			// If indexPath is valid, we are updating an existing entry.
			// So replace the image at the path with the new image provided.
			if let path = indexPath {
				self.photoStore.replaceStereogramAtIndex(path.item, withStereogram: newStereogram)
				self.photoCollection.reloadItemsAtIndexPaths([path])
			}
	}

	func fullImageViewController(controller: FullImageViewController
		,    approvingStereogram stereogram: Stereogram
		,                            result: ApprovalResult) {
			if result == .Discarded {
				switch photoStore.deleteStereogram(stereogram) {
				case .Error(let error):
					error.showAlertWithTitle("Error discarding stereogram", parentViewController:self)
				case .Success:
					break
				}
			}
			photoCollection.reloadData()
	}

	func dismissedFullImageViewController(controller: FullImageViewController) {
		controller.dismissViewControllerAnimated(true, completion: nil)
	}
}

extension PhotoViewController: StereogramViewControllerDelegate {
	// MARK: StereogramViewController delegate

	func stereogramViewController(controller: StereogramViewController
		,       createdStereogram stereogram: Stereogram) {
			controller.dismissViewControllerAnimated(true) {
				// Once dismissed, trigger the full image view controller to examine the image.
				controller.reset()
				self.showApprovalWindowForStereogram(stereogram)
			}
	}

	func stereogramViewControllerWasCancelled(controller: StereogramViewController) {
		controller.dismissViewControllerAnimated(true, completion: nil)
	}
}

// MARK: MFMailViewComposer delegate

extension PhotoViewController: MFMailComposeViewControllerDelegate {

	func mailComposeController(controller: MFMailComposeViewController!
		,      didFinishWithResult result: MFMailComposeResult
		,                           error: NSError!) {

			// Dismiss the view controller window, and if there was an error display it
			// after the main view has been removed.
			dismissViewControllerAnimated(true) {
				if result.value == MFMailComposeResultFailed.value {
					var err = error ?? NSError.unknownErrorWithLocation(
						"MFMailComposeViewController callback.")
					err.showAlertWithTitle("Error sending mail", parentViewController: self)
				}
			}
	}
}

// MARK: - Private Methods

extension PhotoViewController {

	/// Creates the navigation buttons and adds them to the navigation controller.
	///
	/// Called from the initializers as part of the setup process.

	private func setupNavigationButtons() {
		let takePhotoItem = UIBarButtonItem(barButtonSystemItem: .Camera
			,                                            target: self
			,                                            action: "takePicture")
		let exportItem = UIBarButtonItem(barButtonSystemItem: .Action
			,                                         target: self
			,                                         action: "actionMenu")
		self.exportItem = exportItem
		let editItem = editButtonItem()
		self.editItem = editItem
		navigationItem.rightBarButtonItems = [takePhotoItem]
		navigationItem.leftBarButtonItems = [exportItem, editItem]
		self.editing = false
	}

	/// Creates a message to show the user when checking if they really want to delete stereograms.
	///
	/// :param: numToDelete -  The number of sterograms the user wants to delete.
	/// :returns: A formatted string to display to the user in the delete-confirmation dialog.

	private func formatDeleteMessage(numToDelete: UInt) -> String {
		let postscript = "This operation cannot be undone."
		if numToDelete == 1 { return "Do you really want to delete this photo?\n\(postscript)" }
		return "Do you really want to delete these \(numToDelete) photos?\n\(postscript)"
	}

	/// Copy the specified photos to the app's camera roll.
	///
	/// :param: selectedIndexes - An array of NSIndexPath objects identifying stereograms
	///                           in the photo store which we want to export.

	private func copyPhotosToCameraRoll(selectedIndexes: [NSIndexPath]) {
		for indexPath in selectedIndexes {
			let result = photoStore.copyStereogramToCameraRoll(indexPath.indexAtPosition(1))
			result.onError() {
				$0.showAlertWithTitle("Error exporting to camera roll"
					, parentViewController: self)
			}
			// Stop on the first error, to avoid swamping the user with alerts.
			if !result.success { return }
		}

		// Now stop editing, which will deselect all the items.
		setEditing(false, animated: true)
	}

	/// Check if the given device can send mail and notify the user via an alert if it can't.
	///
	/// :returns: true if the device can send mail, false if it can't
	private func deviceCanSendMail() -> Bool {
		// Abort if there are no email accounts on this device.
		if !MFMailComposeViewController.canSendMail() {
			let userInfo = [NSLocalizedDescriptionKey : "This device is not set up to send email."]
			let error = NSError(errorCode: .FeatureUnavailable, userInfo: userInfo)
			error.showAlertWithTitle("Export via email", parentViewController: self)
			return false
		}
		return true
	}

	/// Present an email message with the selected stereograms attached.
	///
	/// :param: selectedIndexes - An array of NSIndexPath objects identifying stereograms
	///                           in the photo store which we want to export.

	private func sendPhotosViaEmail(selectedIndexes: [NSIndexPath]) {

		if !deviceCanSendMail() {
			return
		}

		// Find all the stereograms we requested for export.
		var allImages = Array<Stereogram.ExportData>()
		let store = photoStore
		let selectedImages = selectedIndexes.map{ store.stereogramAtIndex($0.indexAtPosition(1)) }

		var error: NSError?
		loop: for stereogram in selectedImages {
			switch stereogram.exportData() {
			case .Error(let err):
				error = err
				break loop  // Stop on the first error, to avoid swamping the user with alerts.
			case .Success(let exportData):
				allImages.append(exportData.value)
			}
		}

		if let err = error {
			err.showAlertWithTitle("Error exporting to email", parentViewController: self)
			return
		}

		presentMailViewWithAttachments(allImages)

		// Now stop editing, which will deselect all the items.
		setEditing(false, animated: true)
	}

	/// Present a mail view to display the provided attachments, according to their mime type.
	///
	/// :param: attachments Array of exported stereograms to display.

	private func presentMailViewWithAttachments(attachments: [Stereogram.ExportData]) {
		// Present a mail compose view with the images as attachments.

		let mailVC = MFMailComposeViewController()
		mailVC.mailComposeDelegate = self
		mailVC.setSubject("Exported Stereograms.")
		let mainText = (attachments.count != 1
			? "Here are \(attachments.count) images exported from Stereogram."
			: "Here is an image exported from Stereogram.")
		let bodyText = String(format: emailBodyTemplate, arguments: [mainText, NSDate().description])
		mailVC.setMessageBody(bodyText, isHTML:true)

		for (index, (stereogramData, mimeType)) in enumerate(attachments) {
			mailVC.addAttachmentData(stereogramData
				,          mimeType: mimeType
				,          fileName: "Image\(index + 1)")
		}
		presentViewController(mailVC,  animated:true, completion:nil)
	}



	/// Create the activity indicator if necessary and size it to fit the frame it is contained in.

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

	/// Set whether to display the activity indicator or to hide it.

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

	/// Presents an alert to the user warning about the pending delete.
	/// If accepted, deletes all the selected stereograms from the photo collection
	///
	/// :param: photoCollection - The collection to check.
	///         All selected images in this collection will be deleted.

	private func deletePhotos(photoCollection: UICollectionView) {
		if let indexPaths = photoCollection.indexPathsForSelectedItems() as? [NSIndexPath] {
			if indexPaths.count > 0 {

				let deleteAction = UIAlertAction(title: "Delete"
					,                            style: .Destructive) {
						(action) in
						self.photoStore.deleteStereogramsAtIndexPaths(indexPaths).onError() {
							//error in
							$0.showAlertWithTitle("Error deleting photos"
								, parentViewController: self)
						}
						self.setEditing(false, animated: true)
						photoCollection.reloadData()
				}


				let cancelAction = UIAlertAction(title: "Cancel"
					,                            style: .Cancel
					,                          handler: nil)


				let message = formatDeleteMessage(UInt(indexPaths.count))
				let alertController = UIAlertController(title: "Confirm deletion"
					, message: message
					, preferredStyle: .Alert)
				alertController.addAction(deleteAction)
				alertController.addAction(cancelAction)
				self.presentViewController(alertController, animated: true, completion: nil)
			}
		}
	}

}

