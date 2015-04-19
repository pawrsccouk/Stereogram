//
//  CollectionViewThumbnailProvider.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 22/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

// Connector that takes a thumbnail provider and implements a collection view delegate, serving data from the provider.
// TODO: Make this generic

class CollectionViewThumbnailProvider : NSObject, UICollectionViewDataSource, UICollectionViewDelegate {

    private var photoStore: PhotoStore
    private var photoCollection: UICollectionView
    private let ImageThumbnailCellId = "ImageThumbnailCell"
   
    init(photoStore: PhotoStore, photoCollection: UICollectionView) {
        self.photoStore = photoStore
        self.photoCollection = photoCollection
        super.init()
        photoCollection.registerClass(ImageThumbnailCell.self, forCellWithReuseIdentifier: ImageThumbnailCellId)
    }
    
    // MARK: - Collection View Data Source
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assert(section == 0, "data requested for section \(section), which is out of range.")
        return photoStore.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(ImageThumbnailCellId, forIndexPath: indexPath) as! ImageThumbnailCell
        switch photoStore.thumbnailAtIndex(UInt(indexPath.item)) {
        case .Success(let image):
            cell.image = image.value
        case .Error(let error):
            NSLog("Error receiving image at \(indexPath) from the photoStore \(photoStore)")
            NSLog("The error was \(error)")
        }
        return cell
    }
    
}
