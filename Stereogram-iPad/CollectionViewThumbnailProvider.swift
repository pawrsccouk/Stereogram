//
//  CollectionViewThumbnailProvider.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 22/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

// Make this generic

/// Connector that takes a thumbnail provider and implements a collection view delegate
/// serving data from the provider.

class CollectionViewThumbnailProvider: NSObject, UICollectionViewDelegate {

	// MARK: Private data

	/// The photo store we are sourcing images from.
	private let photoStore: PhotoStore

	/// The collection view we are populating with images.
	private var photoCollection: UICollectionView

	/// Cell identifier for the collection view's cells.
	private let imageThumbnailCellId = "ImageThumbnailCell"


	// MARK: Initialzers

    /// Designated initializer.
    ///
    /// :param: photoStore       The photo store to search for images.
    /// :param: photoCollection  The collection to populate with thumbnails from the photo store.

    init(photoStore: PhotoStore, photoCollection: UICollectionView) {
        self.photoStore = photoStore
        self.photoCollection = photoCollection
        super.init()
        photoCollection.registerClass(    ImageThumbnailCell.self
			, forCellWithReuseIdentifier: imageThumbnailCellId)

        // Tell the photo collection to come to us for data.
        photoCollection.dataSource = self
    }
}

private func dequeueCellId(collectionView cv: UICollectionView
	,                              cellId id: String
	,                         indexPath path: NSIndexPath) -> ImageThumbnailCell {
		if let c = cv.dequeueReusableCellWithReuseIdentifier(id
			,                                  forIndexPath: path) as? ImageThumbnailCell {
				return c
		} else {
			assert(false, "Collection view \(cv) cannot get a ThumbnailImageCell for ID \(id)")
			return ImageThumbnailCell()
		}
}

// MARK: - Collection View Data Source
extension CollectionViewThumbnailProvider: UICollectionViewDataSource {

    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(  collectionView: UICollectionView
		, numberOfItemsInSection section: Int) -> Int {
        assert(section == 0, "data requested for section \(section), which is out of range.")
        return photoStore.count
    }

	func collectionView(    collectionView: UICollectionView
		, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
			let thumbCell = dequeueCellId(collectionView: collectionView
				,                                 cellId: imageThumbnailCellId
				,                              indexPath: indexPath)
			switch photoStore.stereogramAtIndex(indexPath.item).thumbnailImage() {
			case .Success(let result):
				thumbCell.image = result.value
			case .Error(let error):
				NSLog("Error \(error) receiving stereogram image "
					+ "at index path \(indexPath) from \(photoStore)")
			}
			return thumbCell
	}

}
