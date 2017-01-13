//
//  QuiltView.swift
//  QuiltView
//
//  Created by Jeremy Groh on 01/09/17
//  Copyright © 2017 Facet Digital, LLC. All rights reserved.
//
import UIKit

// NOTE: Even though we are not interoperating with Objective-C, we
//       need to mark our protocol with the @objc attribute since we are
//       specifying optional requirements.
@objc public protocol QuiltViewDelegate : UICollectionViewDelegate {
  
  @objc optional func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, blockSizeForItemAtIndexPath indexPath: IndexPath) -> CGSize
  
  @objc optional func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetsForItemAtIndexPath indexPath: IndexPath) -> UIEdgeInsets
}

public class QuiltView : UICollectionViewLayout {
  
  // MARK: Public Properties
  
  public var itemBlockSize = CGSize(width: Constants.ImageCollection.ImageWidth, height: Constants.ImageCollection.ImageHeight) {
    didSet {
      self.invalidateLayout()
    }
  }
  
  public var scrollDirection = UICollectionViewScrollDirection.vertical {
    didSet {
      self.invalidateLayout()
    }
  }
  
  public var cellIndexPaths = [Int:IndexPath]()
  
  // MARK: Private Properties
  
  private weak var delegate: QuiltViewDelegate? {
    get {
      return collectionView?.delegate as? QuiltViewDelegate
    }
  }
  
  private static var didShowMessage = false
  
  // Set the class name for debug purposes only
  private var className = "QuiltView"
  
  private var blockPoint = CGPoint.zero
  private var furthestBlockPoint: CGPoint {
    get {
      return self.blockPoint
    }
    set(newFurthestBlockPoint) {
      self.blockPoint = CGPoint(
        x: max(self.blockPoint.x, newFurthestBlockPoint.x),
        y: max(self.blockPoint.y, newFurthestBlockPoint.y)
      )
    }
  }
  
  // Only use this if we have less than 1000 or so items. This will give
  // the correct size from the start and improve scrolling speed,
  // but cause increased loading times at the beginning
  private var preLayoutEverything = false
  private var firstpublicSpace    = CGPoint.zero
  private var hasPositionsCached  = false
  private var previousLayoutRect  = CGRect.zero
  private var cellLayoutInfo      = [IndexPath:UICollectionViewLayoutAttributes]()
  
  // This will be a 2x2 dictionary storing IndexPaths which
  // indicates the available/filled spaces in our layout
  private var indexPathByPosition = [Int:[Int:IndexPath]]()
  
  // Indexed by "section, row". This will serve as the
  // rapid lookup of block position by indexpath.
  private var positionByIndexPath = [Int:[Int:CGPoint]]()
  
  // Previous layout cache. This is to prevent choppiness when scrolling
  // to the bottom of the screen. UICollectionView will repeatedly call
  // layoutattributesforelementinrect on each scroll event.
  private var previousLayoutAttributes: [AnyObject]? = nil
  
  // Remember the last indexpath placed so that we do not
  // re-layout the same indexpaths while scrolling
  private var lastIndexPathPlaced: IndexPath? = nil
  
  
  // MARK: UICollectionViewLayoutDelegate
  
  override public var collectionViewContentSize : CGSize {
    let contentRect = UIEdgeInsetsInsetRect(self.collectionView!.frame, self.collectionView!.contentInset)
    var size        = CGSize(width: contentRect.width, height: (self.furthestBlockPoint.y + 1) * self.itemBlockSize.height)
    
    if !self.isVertical() {
      size = CGSize(width: (self.furthestBlockPoint.x + 1) * self.itemBlockSize.width, height: contentRect.height)
    }
    
    return size
  }
  
  override public func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    if (self.delegate == nil) {
      return []
    }
    
    if rect.equalTo(self.previousLayoutRect) {
      return self.previousLayoutAttributes as? [UICollectionViewLayoutAttributes]
    }
    
    self.previousLayoutRect = rect
    
    let isVertical                  = self.isVertical()
    let unrestrictedDimensionStart  = Int(isVertical ? rect.origin.y / self.itemBlockSize.height : rect.origin.x / self.itemBlockSize.width)
    let unrestrictedDimensionLength = Int(isVertical ? rect.size.height / self.itemBlockSize.height : rect.size.width / self.itemBlockSize.width) + 1
    let unrestrictedDimensionEnd    = unrestrictedDimensionStart + unrestrictedDimensionLength
    
    self.fillInBlocksToUnrestrictedRow(endRow: self.preLayoutEverything ? Int.max : unrestrictedDimensionEnd)
    
    // find the indexPaths between those rows
    let attributes = NSMutableSet()
    self.traverseTilesBetweenUnrestrictedDimension(begin: unrestrictedDimensionStart, and: unrestrictedDimensionEnd, block: { point in
      let indexPath: IndexPath? = self.indexPathForPosition(point: point)
      if (indexPath != nil) {
        attributes.add(self.layoutAttributesForItem(at: indexPath!))
      }
      return true
    })
    
    self.previousLayoutAttributes = attributes.allObjects as? [UICollectionViewLayoutAttributes]
    
    return self.previousLayoutAttributes as? [UICollectionViewLayoutAttributes]
  }

  override public func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes {
    var insets = UIEdgeInsets.zero
    if self.delegate?.responds(to: Selector(Constants.String.CollectionViewInsetsForItem)) != nil {
      insets = self.delegate!.collectionView!(collectionView: self.collectionView!, layout: self, insetsForItemAtIndexPath: indexPath)
    }
    
    let frame        = self.frameForIndexPath(path: indexPath)
    let attributes   = UICollectionViewLayoutAttributes(forCellWith: indexPath)
    attributes.frame = UIEdgeInsetsInsetRect(frame, insets)
    
    if let preCalcAttributes = self.cellLayoutInfo[indexPath] {
      attributes.zIndex      = preCalcAttributes.zIndex
      attributes.transform3D = preCalcAttributes.transform3D
    }
    
    return attributes
  }
  
  override public func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
    return !(newBounds.size.equalTo(self.collectionView!.frame.size))
  }
  
  override public func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
    super.prepare(forCollectionViewUpdates: updateItems)
    
    for item in updateItems {
      if (item.updateAction == UICollectionUpdateAction.insert || item.updateAction == UICollectionUpdateAction.move) {
        self.fillInBlocksToIndexPath(path: item.indexPathAfterUpdate!)
      }
    }
  }
  
  override public func invalidateLayout() {
    super.invalidateLayout()
    
    self.furthestBlockPoint       = CGPoint.zero
    self.firstpublicSpace         = CGPoint.zero
    self.previousLayoutRect       = CGRect.zero
    self.previousLayoutAttributes = nil
    self.lastIndexPathPlaced      = nil
    
    self.clearPositions()
  }
  
  override public func prepare() {
    super.prepare()
    
    if (self.delegate == nil) {
      return
    }
    
    let cv              = self.collectionView!
    let scrollFrame     = CGRect(x: cv.contentOffset.x, y: cv.contentOffset.y, width: cv.frame.size.width, height: cv.frame.size.height)
    var unrestrictedRow = Int(scrollFrame.maxY / self.itemBlockSize.height) + 1
    
    if !self.isVertical() {
      unrestrictedRow = Int(scrollFrame.maxX / self.itemBlockSize.width) + 1
    }
    
    self.fillInBlocksToUnrestrictedRow(endRow: self.preLayoutEverything ? Int.max : unrestrictedRow)
  }
  
  // MARK: Private Methods
  
  private func fillInBlocksToUnrestrictedRow(endRow: Int) {
    let isVertical = self.isVertical()
    // we'll have our data structure as if we're planning
    // a vertical layout, then when we assign positions to
    // the items we'll invert the axis
    let numSections: Int = self.collectionView!.numberOfSections
  
    for section in Int(self.lastIndexPathPlaced?.section ?? 0)..<numSections {
      let numRows: Int = self.collectionView!.numberOfItems(inSection: section)
      
      for row in (self.lastIndexPathPlaced == nil ? 0 : Int(self.lastIndexPathPlaced?.row ?? 0) + 1)..<numRows {
        let indexPath: IndexPath = IndexPath(row: row, section: section)
        
        if self.placeBlockAtIndex(indexPath: indexPath) {
          self.lastIndexPathPlaced = indexPath
        }
        
        // Determine the initial z-index value for each image
        let itemAttributes             = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        let zIndex                     = Constants.Int.BaseZIndex + numRows - row
        itemAttributes.zIndex          = zIndex
        itemAttributes.transform3D     = CATransform3DMakeTranslation(CGFloat(0), CGFloat(0), CGFloat(zIndex))
        self.cellLayoutInfo[indexPath] = itemAttributes
        
        if (Int(isVertical ? self.firstpublicSpace.y : self.firstpublicSpace.x) >= endRow) {
          return
        }
      }
    }
  }
  
  private func fillInBlocksToIndexPath(path: IndexPath) {
    // we'll have our data structure as if we're planning
    // a vertical layout, then when we assign positions to
    // the items we'll invert the axis
    let numSections = self.collectionView!.numberOfSections
    
    for section in Int(self.lastIndexPathPlaced?.section ?? 0)..<numSections {
      let numRows: Int = self.collectionView!.numberOfItems(inSection: section)
      
      for row in (self.lastIndexPathPlaced == nil ? 0 : Int(self.lastIndexPathPlaced?.row ?? 0) + 1)..<numRows {
        if section >= path.section && row > path.row {
          return
        }

        let indexPath: IndexPath = IndexPath(row: row, section: section)
        if self.placeBlockAtIndex(indexPath: indexPath) {
          self.lastIndexPathPlaced = indexPath
        }
      }
    }
  }
  
  private func placeBlockAtIndex(indexPath: IndexPath) -> Bool {
    let blockSize  = self.getBlockSizeForItemAtIndexPath(indexPath: indexPath)
    let isVertical = self.isVertical()
    
    return !self.traversepublicTiles(block: { blockOrigin in
      let didTraverseAllBlocks = self.traverseTilesForPoint(point: blockOrigin, withSize: blockSize, block: { point in
        let indexPath: IndexPath?      = self.indexPathForPosition(point: point)
        let spaceAvailable             = indexPath == nil
        let inBounds                   = Int(isVertical ? point.x : point.y) < self.restrictedDimensionBlockSize()
        let maximumRestrictedBoundSize = Int(isVertical ? blockOrigin.x : blockOrigin.y) == 0
        
        if spaceAvailable && maximumRestrictedBoundSize && !inBounds {
          #if DEBUG
            let text = isVertical ? "wide" : "tall"
            print("\(self.className): layout is not \(text) enough for this piece size: \(NSStringFromCGSize(blockSize))! Adding anyway...")
          #endif
          return true
        }
        
        return (spaceAvailable && inBounds)
      })
      
      if (!didTraverseAllBlocks) {
        return true
      }
      
      // because we have determined that the space is all available, lets fill it in as taken.
      self.setIndexPath(path: indexPath, forPosition: blockOrigin)
      self.traverseTilesForPoint(point: blockOrigin, withSize: blockSize, block: { point in
        self.setPosition(point: point, forIndexPath: indexPath)
        self.furthestBlockPoint = point
        return true
      })
      
      return false
    })
  }
  
  // returning false in the callback will terminate the iterations early
  private func traverseTilesBetweenUnrestrictedDimension(begin: Int, and end: Int, block: ((CGPoint) -> Bool)) -> Bool {
    let isVertical = self.isVertical()
    
    for unrestrictedDimension in begin..<end {
      for restrictedDimension in 0..<self.restrictedDimensionBlockSize() {
        let x     = isVertical ? restrictedDimension : unrestrictedDimension
        let y     = isVertical ? unrestrictedDimension : restrictedDimension
        let point = CGPoint(x: x, y: y)

        if !block(point) {
          return false
        }
      }
    }

    return true
  }
  
  
  // returning false in the callback will terminate the iterations early
  private func traverseTilesForPoint(point: CGPoint, withSize size: CGSize, block: ((CGPoint) -> Bool)) -> Bool {
    
    for col in stride(from: point.x, to: point.x + size.width, by: 1) {
      for row in stride(from: point.y, to: point.y + size.height, by: 1) {
        let point = CGPoint(x: col, y: row)
        
        if !block(point) {
          return false
        }
      }
    }

    return true
  }
  
  // returning false in the callback will terminate the iterations early
  private func traversepublicTiles(block: (CGPoint) -> (Bool)) -> Bool {
    var allTakenBefore        = true
    let isVertical            = self.isVertical()
    var unrestrictedDimension = Int(isVertical ? self.firstpublicSpace.y : self.firstpublicSpace.x)
    
    // the unrestricted dimension should iterate indefinitely. the >= to 0 is intentional
    while unrestrictedDimension >= 0 {
      
      for restrictedDimension in 0..<self.restrictedDimensionBlockSize() {
        let x         = Int(isVertical ? restrictedDimension : unrestrictedDimension)
        let y         = Int(isVertical ? unrestrictedDimension : restrictedDimension)
        let point     = CGPoint(x: x, y: y)
        let indexPath = self.indexPathForPosition(point: point)
        
        if (indexPath != nil) {
          continue
        }
        
        if allTakenBefore {
          self.firstpublicSpace = point
          allTakenBefore        = false
        }
        
        let blockResult = block(point)
        if !blockResult {
          return false
        }
      }
      
      // increment unrestrictedDimension
      unrestrictedDimension += 1
    }
    
    #if DEBUG
      print("Unable to find a place for a block!")
    #endif
    return true
  }
  
  private func clearPositions() {
    self.indexPathByPosition = [Int:[Int:IndexPath]]()
    self.positionByIndexPath = [Int:[Int:CGPoint]]()
  }
  
  private func indexPathForPosition(point: CGPoint) -> IndexPath? {
    let isVertical        = self.isVertical()
    // To avoid creating unbounded NSMutableDictionaries we should
    // have the inner dictionary be the unrestricted dimension
    let unrestrictedPoint = Int(isVertical ? point.y : point.x)
    let restrictedPoint   = Int(isVertical ? point.x : point.y)
    
    return self.indexPathByPosition[restrictedPoint]?[unrestrictedPoint]
  }
  
  private func setPosition(point: CGPoint, forIndexPath indexPath: IndexPath) {
    let isVertical        = self.isVertical()
    // To avoid creating unbounded NSMutableDictionaries we should
    // have the innerdict be the unrestricted dimension
    let unrestrictedPoint = Int(isVertical ? point.y : point.x)
    let restrictedPoint   = Int(isVertical ? point.x : point.y)
    
    let dictionary = self.indexPathByPosition[restrictedPoint]
    if dictionary == nil {
      self.indexPathByPosition[restrictedPoint] = [Int:IndexPath]()
    }
    
    self.indexPathByPosition[restrictedPoint]?[unrestrictedPoint] = indexPath
  }
  
  private func setIndexPath(path: IndexPath, forPosition point: CGPoint) {
    let innerDict = self.positionByIndexPath[path.section]
    if innerDict == nil {
      self.positionByIndexPath[path.section] = [Int:CGPoint]()
    }
    
    self.positionByIndexPath[path.section]?[path.row] = point
    
    // Store the index path so we can use it later on for selecting random cell's to scroll to
    self.cellIndexPaths[self.cellIndexPaths.count] = path
  }
  
 private func positionForIndexPath(path: IndexPath) -> CGPoint {
    // if item does not have a position, make one
    let sectionIndex = self.positionByIndexPath[path.section]?[path.row]
    if sectionIndex == nil {
      self.fillInBlocksToIndexPath(path: path)
    }
    
    return self.positionByIndexPath[path.section]?[path.row] ?? CGPoint.zero
  }
  
  private func frameForIndexPath(path: IndexPath) -> CGRect {
    let position    = self.positionForIndexPath(path: path)
    let elementSize = self.getBlockSizeForItemAtIndexPath(indexPath: path)
    let contentRect = UIEdgeInsetsInsetRect(self.collectionView!.frame, self.collectionView!.contentInset)
    
    if self.isVertical() {
      // Definitions:
      //  self.restrictedDimensionBlockSize() - The number of columns in the collection view
      //  self.itemBlockSize.width            - The width of one column/block including it's margin
      let initialPaddingForConstraintedDimension = (Int(contentRect.width) - self.restrictedDimensionBlockSize() * Int(self.itemBlockSize.width)) / 2
      
      let rect = CGRect(
        x: Int(position.x * self.itemBlockSize.width) + initialPaddingForConstraintedDimension,
        y: Int(position.y * self.itemBlockSize.height),
        width: Int(elementSize.width * self.itemBlockSize.width),
        height: Int(elementSize.height * self.itemBlockSize.height)
      )
      
      return rect
    } else {
      
      let initialPaddingForConstraintedDimension = (Int(contentRect.height) - self.restrictedDimensionBlockSize() * Int(self.itemBlockSize.height)) / 2
      
      let rect = CGRect(
        x: Int(position.x * self.itemBlockSize.width),
        y: Int(position.y * self.itemBlockSize.height) + initialPaddingForConstraintedDimension,
        width: Int(elementSize.width * self.itemBlockSize.width),
        height: Int(elementSize.height * self.itemBlockSize.height)
      )
      
      return rect
    }
  }
  
  // This method is prefixed with get because it may return its value indirectly
  private func getBlockSizeForItemAtIndexPath(indexPath: IndexPath) -> CGSize {
    var blockSize = CGSize(width: 1, height: 1)
    if self.delegate?.responds(to: Selector(Constants.String.CollectionViewBlockSizeForItem)) != nil {
      blockSize = self.delegate!.collectionView!(collectionView: self.collectionView!, layout: self, blockSizeForItemAtIndexPath: indexPath)
    }
    
    return blockSize
  }
  
  // this will return the maximum width or height the layout can
  // take, depending on if we are growing horizontally or vertically
  private func restrictedDimensionBlockSize() -> Int {
    let isVertical  = self.isVertical()
    let contentRect = UIEdgeInsetsInsetRect(self.collectionView!.frame, self.collectionView!.contentInset)
    let size        = Int(isVertical ? contentRect.width / self.itemBlockSize.width : contentRect.height / self.itemBlockSize.height)
    
    if size == 0 {
      struct Temp { static var didShowMessage = false }
      
      if (Temp.didShowMessage == false) {
        #if DEBUG
          print("\(self.className): cannot fit block of size: \(NSStringFromCGSize(self.itemBlockSize)) in content rect \(NSStringFromCGRect(contentRect))!  Defaulting to 1")
        #endif
        
        Temp.didShowMessage = true
      }
      
      return 1
    }
    
    return size
  }
  
  private func isVertical() -> Bool {
    return self.scrollDirection == UICollectionViewScrollDirection.vertical
  }
}
