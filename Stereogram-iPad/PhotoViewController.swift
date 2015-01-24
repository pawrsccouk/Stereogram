//
//  ViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 11/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

class PhotoViewController : UIViewController, UICollectionViewDelegate, FullImageViewControllerDelegate, StereogramViewControllerDelegate {

    @IBOutlet weak var photoCollection: UICollectionView!

    var photoStore: PhotoStore!

    override init(nibName: String?, bundle: NSBundle?) {
        super.init(nibName: "PhotoView", bundle: bundle)
        stereogramViewController = StereogramViewController(delegate: self)
    }
    
    convenience override init() {
        self.init(nibName: nil, bundle: nil)
    }

    // View controllers are created manually for this project. This should never be called.
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
        stereogramViewController = StereogramViewController(delegate: self)
    }

    
    // Do any additional setup after loading the view, typically from a nib.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Connect up the thumbnail provider as data source to the collection view.
        if collectionViewThumbnailProvider == nil {
            collectionViewThumbnailProvider = CollectionViewThumbnailProvider(photoStore: photoStore, photoCollection: photoCollection)
            photoCollection.dataSource = collectionViewThumbnailProvider
        }
        
        setupNavigationButtons()
        photoCollection.allowsSelection = true
        photoCollection.allowsMultipleSelection = true
        
        // Set the thumbnail size from the store
        setThumbnailSize(thumbnailSize: thumbnailSize)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        setupActivityIndicator()
    }
    
    override func setEditing(editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        // Clear the selected ticks once we stop editing the photo collection.
        if !editing {
            for indexPath in photoCollection.indexPathsForSelectedItems() as [NSIndexPath] {
                photoCollection.deselectItemAtIndexPath(indexPath, animated: animated)
            }
        }
    }
    


    // MARK: - Callbacks
    
    func takePicture() {
        stereogramViewController.takePicture(self)
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
    
    // Present an image view showing the image at the given index path.
    func showImageAtIndexPath(indexPath: NSIndexPath) {
        switch photoStore.imageAtIndex(UInt(indexPath.item)) {
        case .Success(let image):
            let fullImageViewController = FullImageViewController(image: image.value, atIndexPath: indexPath, delegate: self)
            navigationController!.pushViewController(fullImageViewController, animated: true)
        case .Error(let error):
            error.showAlertWithTitle("Error accessing image at index path \(indexPath)", parentViewController: self)
        }
    }
    
    // Called to present the image to the user, with options to accept or reject it.
    func showApprovalWindowForImage(image: UIImage) {
        let fullImageViewController = FullImageViewController(imageForApproval: image, delegate: self)
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
    
    // MARK: FullImageController delegate
    
    func fullImageViewController(controller: FullImageViewController, amendedImage newImage: UIImage, atIndexPath indexPath: NSIndexPath?) {
        // If indexPath is nil, we are calling it for approval. In which case, don't do anything, as we will handle it in the approvedImage delegate method.
        // If indexPath is valid, we are updating an existing entry. So replace the image at the path with the new image provided.
        if let path = indexPath {
            self.photoStore.replaceImageAtIndex(UInt(path.item), withImage: newImage)
            self.photoCollection.reloadItemsAtIndexPaths([path])
        }
    }
    
    func fullImageViewController(controller: FullImageViewController, approvedImage image: UIImage) {
        let dateTaken = NSDate()
        switch photoStore.addImage(image, dateTaken: dateTaken) {
        case .Success():
            photoCollection.reloadData()
        case .Error(let error):
            error.showAlertWithTitle("Error saving photo", parentViewController: self)
        }
    }
    
    func dismissedFullImageViewController(controller: FullImageViewController) {
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: StereogramViewController delegate
    
    func stereogramViewController(controller: StereogramViewController, createdStereogram stereogram: UIImage) {
        controller.dismissViewControllerAnimated(true) {
            // Once dismissed, trigger the full image view controller to examine the image.
            controller.reset()
            self.showApprovalWindowForImage(stereogram)
        }
    }
    
    func stereogramViewControllerWasCancelled(controller: StereogramViewController) {
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: - Private data

    private var exportItem: UIBarButtonItem!, editItem: UIBarButtonItem!
    private let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    private var collectionViewThumbnailProvider: CollectionViewThumbnailProvider?
    private var stereogramViewController: StereogramViewController!
    

    // Creates the navigation buttons and adds them to the navigation controller. Called from the initializers as part of the setup process.
    private func setupNavigationButtons() {
        let takePhotoItem = UIBarButtonItem(barButtonSystemItem: .Camera, target: self, action: "takePicture")
        self.exportItem = UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: "actionMenu")
        self.editItem = editButtonItem()
        navigationItem.rightBarButtonItems = [takePhotoItem]
        navigationItem.leftBarButtonItems = [exportItem, editItem]
        self.editing = false
    }
    
    // Sets the size of the thumbnails in the collection view.
    private func setThumbnailSize(thumbnailSize size: CGSize) {
        assert(photoCollection.collectionViewLayout.isKindOfClass(UICollectionViewFlowLayout.self), "Photo collection view layout is not a flow layout.")
        let flowLayout = photoCollection.collectionViewLayout as UICollectionViewFlowLayout
        flowLayout.itemSize = size
        flowLayout.invalidateLayout()
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
        
        // Now stop editing, which will deselect all the items.
        setEditing(false, animated: true)
    }
    
    private func setupActivityIndicator() {
        // Add the activity indicator to the view if it is not there already. It starts off hidden.
        if !activityIndicator.isDescendantOfView(view) {
            view.addSubview(activityIndicator)
        }
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
            alertController.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive) { (action) in
                NSLog("Deleting images at index paths: \(indexPaths)")
                self.photoStore.deleteImagesAtIndexPaths(indexPaths).onError() {
                    $0.showAlertWithTitle("Error deleting photos", parentViewController: self)
                }
                self.setEditing(false, animated: true)
                photoCollection.reloadData()
            })
            alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil ))
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    
}

