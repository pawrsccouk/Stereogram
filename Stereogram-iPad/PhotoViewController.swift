//
//  ViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 11/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

class PhotoViewController : UIViewController, UICollectionViewDelegate {

    @IBOutlet weak var photoCollection: UICollectionView!

    var photoStore: PhotoStore!

    override init(nibName: String?, bundle: NSBundle?) {
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
                    e.showAlertWithTitle("Error initialising the photo store", parentViewController: self)
                }
                fatalError("Failed to initialise the photo store with error \(error)")
            }
        }
        
        // Connect up the thumbnail provider as data source to the collection view.
        if collectionViewThumbnailProvider == nil {
            collectionViewThumbnailProvider = CollectionViewThumbnailProvider(photoStore: photoStore, photoCollection: photoCollection)
            photoCollection.dataSource = collectionViewThumbnailProvider
        }
        
        // Connect up the sterogram view controller.
        if stereogramViewController == nil {
            stereogramViewController = StereogramViewController()
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
        if let svc = stereogramViewController {
            if let img = svc.stereogram  {
                showApprovalWindowForImage(img)
                svc.reset()
            }
        }
    }
    

    // MARK: - Callbacks
    
    func takePicture() {
        if let svc = stereogramViewController {
            svc.takePicture(self)
        }
    }
    
    func actionMenu() {
        let alertController = UIAlertController(title: "Select an action", message: "", preferredStyle: UIAlertControllerStyle.ActionSheet)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "Delete", style: .Destructive) { [unowned self] (action) in
            self.deletePhotos(self.photoCollection)
        })
        alertController.addAction(UIAlertAction(title: "Copy to gallery", style: .Default) { [unowned self] (action) in
            self.copyPhotosToCameraRoll(self.photoCollection.indexPathsForSelectedItems() as [NSIndexPath])
        })
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
            fullImageViewController.imageUpdatedCallback = { newImage in
                self.photoStore.replaceImageAtIndex(UInt(indexPath.item), withImage: newImage)
                self.photoCollection.reloadItemsAtIndexPaths([indexPath])
            }
            navigationController?.pushViewController(fullImageViewController, animated: true)
        case .Error(let error):
            error.showAlertWithTitle("Error accessing image at index path \(indexPath)", parentViewController: self)
        }
    }
    
    // Called to present the image to the user, with options to accept or reject it.
    // If the user accepts, the photo is added to the photo store.
    func showApprovalWindowForImage(image: UIImage) {
        let dateTaken = NSDate()
        let fullImageViewController = FullImageViewController(image: image, forApproval: true)
        fullImageViewController.approvalCallback = { newImage in
            switch self.photoStore.addImage(newImage, dateTaken: dateTaken) {
            case .Success():
                self.photoCollection.reloadData()
            case .Error(let error):
                error.showAlertWithTitle("Error saving photo", parentViewController: self)
            }
        }
        let navigationController = UINavigationController(rootViewController: fullImageViewController)
        navigationController.modalPresentationStyle = .FullScreen
        presentViewController(navigationController, animated: true, completion: nil)
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

    private var exportItem: UIBarButtonItem!, editItem: UIBarButtonItem!
    private let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    private var collectionViewThumbnailProvider: CollectionViewThumbnailProvider?
    private var stereogramViewController: StereogramViewController?
    

    // Creates the navigation buttons and adds them to the navigation controller. Called from the initializers as part of the setup process.
    private func setupNavigationButtons() {
        let takePhotoItem = UIBarButtonItem(barButtonSystemItem: .Camera, target: self, action: "takePicture")
        self.exportItem = UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: "actionMenu")
        self.editItem = editButtonItem()
        navigationItem.rightBarButtonItems = [takePhotoItem]
        navigationItem.leftBarButtonItems = [exportItem, editItem]
        self.editing = false
    }
    
    private func formatDeleteMessage(numToDelete: UInt) -> String {
        let postscript = "This operation cannot be undone."
        if numToDelete == 1 { return "Do you really want to delete this photo?\n\(postscript)" }
        return "Do you really want to delete these \(numToDelete) photos?\n\(postscript)"
    }

    // Copy the photos in the given array of index paths to the app's camera roll.
    private func copyPhotosToCameraRoll(selectedIndexes: [NSIndexPath]) {
        for indexPath in selectedIndexes {
            let result = photoStore.copyImageToCameraRoll(UInt(indexPath.indexAtPosition(1)))
            result.onError() { error in error.showAlertWithTitle("Error exporting to camera roll", parentViewController: self) }
            if !result.success { return }   // Stop on the first error, to avoid swamping the user with alerts.
        }
        
        // Now deselect all the items once we have finished iterating over the list.
        for indexPath in photoCollection.indexPathsForSelectedItems() as [NSIndexPath] {
            photoCollection.deselectItemAtIndexPath(indexPath, animated: false)
        }
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
            activityIndicator.hidden = !newValue
            if newValue {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        }
    }
    
    
    private func deletePhotos(photoCollection: UICollectionView) {
        let indexPaths = photoCollection.indexPathsForSelectedItems() as [NSIndexPath]
        if indexPaths.count > 0 {
            let message = formatDeleteMessage(UInt(indexPaths.count))
            let alertController = UIAlertController(title: "Confirm deletion", message: message, preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive) { [unowned store = self.photoStore!] (action) in
                NSLog("Deleting images at index paths: \(indexPaths)")
                let result = store.deleteImagesAtIndexPaths(indexPaths)
                result.onError() { $0.showAlertWithTitle("Error deleting photos", parentViewController: self) }
                photoCollection.reloadData()
            })
            alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil ))
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    
}

