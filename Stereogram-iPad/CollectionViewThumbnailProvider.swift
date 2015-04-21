//
//  CollectionViewThumbnailProvider.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 22/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

// TODO: Make this generic

/// Connector that takes a thumbnail provider and implements a collection view delegate, serving data from the provider.

class CollectionViewThumbnailProvider : NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
   
    // MARK: Initialzers
    
    /// Designated initializer.
    ///
    /// :param: photoStore - The photo store to search for images.
    /// :param: photoCollection - The collection view to populate with thumbnails from the photo store.

    init(photoStore: PhotoStore, photoCollection: UICollectionView) {
        self._photoStore = photoStore
        self._photoCollection = photoCollection
        super.init()
        photoCollection.registerClass(ImageThumbnailCell.self, forCellWithReuseIdentifier: _imageThumbnailCellId)

        // Tell the photo collection to come to us for data.
        photoCollection.dataSource = self
    }
    
    // MARK: - Collection View Data Source
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assert(section == 0, "data requested for section \(section), which is out of range.")
        return _photoStore.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(_imageThumbnailCellId, forIndexPath: indexPath) as! ImageThumbnailCell
        switch _photoStore.stereogramAtIndex(indexPath.item).thumbnailImage() {
        case .Success(let result):
            cell.image = result.value
        case .Error(let error):
            NSLog("Error \(error) receiving stereogram image at index path \(indexPath) from \(_photoStore)")
        }
        return cell
    }

    // MARK: Private data
    
    /// The photo store we are sourcing images from.
    private let _photoStore: PhotoStore
    
    /// The collection view we are populating with images.
    private var _photoCollection: UICollectionView
    
    /// Cell identifier for the collection view's cells.
    private let _imageThumbnailCellId = "ImageThumbnailCell"
}
