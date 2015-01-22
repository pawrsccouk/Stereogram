//
//  ViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 11/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit
import MobileCoreServices

class PhotoViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegate {

    @IBOutlet weak var photoCollection: UICollectionView!

    var photoStore: PhotoStore!

    override init(nibName: String?, bundle: NSBundle?) {
        cameraOverlayController = CameraOverlayViewController()
        super.init(nibName: "PhotoView", bundle: bundle)
    }
    
    convenience override init() {
        self.init(nibName: nil, bundle: nil)
    }

    // View controllers are created manually for this project. This should never be called.
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
    // Do any additional setup after loading the view, typically from a nib.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load the properties (images etc.)
        // HACK: This assumes the PhotoViewController is the first thing to access the photoStore.
        // If it isn't, then whatever is will get the wrong values until the data is loaded.
        // the problem is that I want to display errors in this case, and I can't do that until we have a view to display them on.
        if photoStore == nil {
            var error: NSError?
            photoStore = PhotoStore(error: &error)
            if photoStore == nil {
                if let e = error {
                    e.showAlertWithTitle("Error initialising the photo store")
                }
                fatalError("Failed to initialise the photo store with error \(error)")
            }
        }
        
        // Connect up the thumbnail provider as data source to the collection view.
        if collectionViewThumbnailProvider == nil {
            collectionViewThumbnailProvider = CollectionViewThumbnailProvider(photoStore: photoStore, photoCollection: photoCollection)
            photoCollection.dataSource = collectionViewThumbnailProvider
        }
        
        setupNavigationButtons()
        photoCollection.allowsSelection = true
        photoCollection.allowsMultipleSelection = true
        
        // Set the thumbnail size from the store
        assert(photoCollection.collectionViewLayout.isKindOfClass(UICollectionViewFlowLayout.self), "Photo collection view layout is not a flow layout.")
        let flowLayout = photoCollection.collectionViewLayout as UICollectionViewFlowLayout
        flowLayout.itemSize = thumbnailSize
        flowLayout.invalidateLayout()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // Add the activity indicator to the view if it is not there already. It starts off hidden.
        if !activityIndicator.isDescendantOfView(view) {
            view.addSubview(activityIndicator)
        }
        resizeActivityIndicator()
        
        // If stereogram is set, we have just reappeared from under the camera controller, and we need to pop up an approval window for the user to accept the new stereogram.
        if let img = stereogram  {
            showApprovalWindowForImage(img)
            stereogram = nil
        }
    }
    

    // MARK: - Callbacks
    
    func takePicture() {
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
        
        presentViewController(pickerController, animated: true, completion: nil)
    }
    
    func actionMenu() {
        let alertController = UIAlertController(title: "Select an action", message: "", preferredStyle: UIAlertControllerStyle.ActionSheet)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "Delete", style: .Destructive, handler: { (action) in self.deletePhotos(self.photoCollection) } ))
        alertController.addAction(UIAlertAction(title: "Change viewing method", style: .Default, handler: { (action) in self.changeViewingMethod() } ))
        alertController.addAction(UIAlertAction(title: "Copy to gallery", style: .Default, handler: { (action) in self.copyPhotosToCameraRoll(self.photoCollection) }))
        alertController.popoverPresentationController!.barButtonItem = exportItem
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    override func setEditing(editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        // Clear the selected ticks once we stop editing the photo collection.
        if !editing {
            for indexPath in photoCollection.indexPathsForSelectedItems() as [NSIndexPath] {
                photoCollection.deselectItemAtIndexPath(indexPath, animated: false)
            }
        }
    }
    
    // Present an image view showing the image at the given index path.
    func showImageAtIndexPath(indexPath: NSIndexPath) {
        switch photoStore.imageAtIndex(UInt(indexPath.item)) {
        case .Success(let image):
            let fullImageViewController = FullImageViewController(image: image.value, forApproval: false)
            navigationController?.pushViewController(fullImageViewController, animated: true)
        case .Error(let error):
            error.showAlertWithTitle("Error accessing image at index path \(indexPath)")
        }
    }
    
    // Called to present the image to the user, with options to accept or reject it.
    // If the user accepts, the photo is added to the photo store.
    func showApprovalWindowForImage(image: UIImage) {
        let dateTaken = NSDate()
        let fullImageViewController = FullImageViewController(image: image, forApproval: true)
        fullImageViewController.approvalBlock = {
            switch self.photoStore.addImage(image, dateTaken: dateTaken) {
            case .Success():
                self.photoCollection.reloadData()
           case .Error(let error):
                error.showAlertWithTitle("Error saving photo")
            }
        }
        let navigationController = UINavigationController(rootViewController: fullImageViewController)
        navigationController.modalPresentationStyle = .FullScreen
        presentViewController(navigationController, animated: true, completion: nil)
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
    
    // MARK: - Collection View Delegate
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
            // In editing mode, this doesn't need to do anything as the status flag on the cell has already been updated.
            // In viewing mode, we need to revert this status-flag update, and then pop the full-image view onto the navigation stack.
        if !editing {
            collectionView.deselectItemAtIndexPath(indexPath, animated: false)
            showImageAtIndexPath(indexPath)
        }
    }
    
    func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        // If we are in viewing mode, then any click on a thumbnail -to select or deselect- we translate into a request to show the full-image view.
        if !editing {
            showImageAtIndexPath(indexPath)
        }
    }
    
    // MARK: - Private data

    private let cameraOverlayController: CameraOverlayViewController
    private var stereogram: UIImage?
    private var exportItem: UIBarButtonItem!, editItem: UIBarButtonItem!
    private let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    // This is the first of the two images we store when taking the stereogram.
    // State-based -only relevant when in the process of taking a photo. TODO: Move to a state-machine instead of a boolean flag.
    private var firstPhoto: UIImage?
    private var collectionViewThumbnailProvider: CollectionViewThumbnailProvider?
    

    // Creates the navigation buttons and adds them to the navigation controller. Called from the initializers as part of the setup process.
    private func setupNavigationButtons() {
        let takePhotoItem = UIBarButtonItem(barButtonSystemItem: .Camera, target: self, action: "takePicture")
        self.exportItem = UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: "actionMenu")
        self.editItem = editButtonItem()
        navigationItem.rightBarButtonItems = [takePhotoItem]
        navigationItem.leftBarButtonItems = [exportItem, editItem]
        self.editing = false
    }
    
    // Get the edited photo from the info dictionary if the user has edited it. If there is no edited photo, get the original photo.
    private func imageFromPickerInfoDict(infoDict: [NSObject : AnyObject]) -> UIImage? {
        if let photo = infoDict[UIImagePickerControllerEditedImage] as UIImage? {
            return photo
        }
        return infoDict[UIImagePickerControllerOriginalImage] as UIImage?
    }
    
    private func formatDeleteMessage(numToDelete: UInt) -> String {
        let postscript = "This operation cannot be undone."
        if numToDelete == 1 { return "Do you really want to delete this photo?\n\(postscript)" }
        return "Do you really want to delete these \(numToDelete) photos?\n\(postscript)"
    }

    // A shared method that does something to one of the photos. Takes a block holding the action to perform.
    // The block takes an integer, which is an index into the collection of image thumbnails in the order they appear
    // in the collection view.  The action must not invalidate the collection view indexes as it may be called more than once.
    typealias ActionBlock = (UInt) -> Result
    private func performNondestructiveAction(photoCollection: UICollectionView, action: ActionBlock, errorTitle: String) {
        for indexPath in photoCollection.indexPathsForSelectedItems() as [NSIndexPath] {
            let result = action(UInt(indexPath.indexAtPosition(1)))

            result.onError() { error in error.showAlertWithTitle(errorTitle) }
            if !result.success { return }   // Stop on the first error, to avoid swamping the user with alerts.
        }
        
        // Now deselect all the items once we have finished iterating over the list.
        for indexPath in photoCollection.indexPathsForSelectedItems() as [NSIndexPath] {
            photoCollection.deselectItemAtIndexPath(indexPath, animated: false)
        }
    }
    
    private func copyPhotosToCameraRoll(photoCollection: UICollectionView) {
        performNondestructiveAction(photoCollection, action: { (index) -> Result in
            return self.photoStore.copyImageToCameraRoll(index)
        }, errorTitle: "Error exporting to camera roll")
    }
    
    private func resizeActivityIndicator() {
        // Ensure the activity indicator fits in the frame.
        let activitySize = activityIndicator.bounds.size
        let parentSize = view.bounds.size
        let frame = CGRectMake((parentSize.width / 2) - (activitySize.width / 2), (parentSize.height / 2) - (activitySize.height / 2), activitySize.width, activitySize.height)
        activityIndicator.frame = frame
    }
    
    private var showActivityIndicator: Bool {
        get { return !activityIndicator.hidden }
        set {
            // TODO: Check the activity indicator still works.
            activityIndicator.hidden = !newValue
            if newValue {
                // view.addSubview(activityIndicator)
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
                // activityIndicator.removeFromSuperview()
            }
        }
    }
    
    // Toggle from cross-eye to wall-eye and back for the selected items.
    // Create the new images on a separate thread, then call back to the main thread to replace them in the photo collection.
    private func changeViewingMethod() {
        self.showActivityIndicator = true
        let selectedItems = photoCollection.indexPathsForSelectedItems() as [NSIndexPath]
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () in
            for indexPath in selectedItems {
                // Index path has 0 = section (always 0), 1 = item.
                assert(indexPath.indexAtPosition(0) == 0, "Index path section is \(indexPath.indexAtPosition(0)), should be 0")
                let result = self.photoStore.changeViewingMethod(UInt(indexPath.indexAtPosition(1)))
                result.onError() { error in
                    dispatch_async(dispatch_get_main_queue()) {
                        error.showAlertWithTitle("Error changing viewing method.")
                        self.showActivityIndicator = false
                    }
                }
                if !result.success { return } // avoid showing the user multiple error alerts.
            }
            
            // Back on the main thread, deselect all the thumbnails and stop the activity timer.
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                for indexPath in selectedItems {
                    self.photoCollection.deselectItemAtIndexPath(indexPath, animated: true)
                }
                self.showActivityIndicator = false
                self.photoCollection.reloadItemsAtIndexPaths(selectedItems)
            }
        }
    }
    
    private func deletePhotos(photoCollection: UICollectionView) {
        let indexPaths = photoCollection.indexPathsForSelectedItems() as [NSIndexPath]
        if indexPaths.count > 0 {
            let message = formatDeleteMessage(UInt(indexPaths.count))
            let alertController = UIAlertController(title: "Confirm deletion", message: message, preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive) { (action) in
                NSLog("Deleting images at index paths: \(indexPaths)")
                let result = self.photoStore.deleteImagesAtIndexPaths(indexPaths)
                result.onError() { $0.showAlertWithTitle("Error deleting photos") }
                photoCollection.reloadData()
            })
            alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil ))
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    
}

