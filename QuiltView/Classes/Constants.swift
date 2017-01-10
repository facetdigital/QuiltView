//
//  Constants.swift
//  QuiltView
//
//  Created by Jeremy Groh on 01/09/17
//  Copyright © 2017 Facet Digital, LLC. All rights reserved.
//

import Foundation
import UIKit

struct Constants {
  struct String {
    static let CollectionViewInsetsForItem    = "collectionView:layout:insetsForItemAtIndexPath:";
    static let CollectionViewBlockSizeForItem = "collectionView:layout:blockSizeForItemAtIndexPath:";
  }
  
  struct ImageCollection {
    // The numbers below represent the minimum image size in the collection view
    static let ImageWidth  = 314
    static let ImageHeight = 314
  }
  
  struct Int {
    static let BaseZIndex = 5000;
  }
}
