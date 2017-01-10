//
//  ViewController.swift
//  QuiltView
//
//  Created by jgroh9 on 01/05/2017.
//  Copyright (c) 2017 jgroh9. All rights reserved.
//
import UIKit
import QuiltView

var num = 0

class ViewController: UICollectionViewController {
  // MARK: Properties
  
  fileprivate let reuseIdentifier = "CellIdentifier"
  fileprivate let initialCells    = 20
  fileprivate var numbers         = [Int]()
  fileprivate var numberWidths    = [Int]()
  fileprivate var numberHeights   = [Int]()
  fileprivate var isAnimating     = false
  
  // MARK: Initialization
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.initData()
    
    // Add some spacing between the top of the view and the first row of
    // blocks so that it doesn't look like the blocks are being cutoff
    self.collectionView?.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
    
    // Do any additional setup after loading the view, typically from a nib.
    self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: self.reuseIdentifier)
    
    let layout = self.collectionView?.collectionViewLayout as! QuiltView
    layout.scrollDirection = UICollectionViewScrollDirection.vertical
    layout.itemBlockSize   = CGSize(
      width: 75,
      height: 75
    )

    self.collectionView!.reloadData()
  }
  
  // MARK: Helper Functions
  
  func getRandomColor() -> UIColor {
    let randomRed:CGFloat   = CGFloat(drand48())
    let randomGreen:CGFloat = CGFloat(drand48())
    let randomBlue:CGFloat  = CGFloat(drand48())
    
    return UIColor(red: randomRed, green: randomGreen, blue: randomBlue, alpha: 1.0)
  }
  
  func initData() {
    num = 0
    self.numbers = []
    self.numberWidths = []
    self.numberHeights = []
    
    while num < self.initialCells {
      self.numbers.append(num)
      self.numberWidths.append(self.randomLength())
      self.numberHeights.append(self.randomLength())
      num += 1
    }
  }
  
  func randomLength() -> Int {
    // always returns a random length between 1 and 3, weighted towards lower numbers.
    var result = arc4random() % 6
    // 3/6 chance of it being 1.
    if result <= 2 {
      result = 1
    }
    else if result == 5 {
      result = 3
    }
    else {
      result = 2
    }
    
    return Int(result)
  }
}

// MARK: UICollectionViewDataSource Delegate
extension ViewController {
  
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return self.numbers.count
  }
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return self.numbers.count
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
    cell.backgroundColor = self.getRandomColor()
    
    let label: UILabel = UILabel(frame: CGRect(x: CGFloat(5), y: CGFloat(5), width: CGFloat(30), height: CGFloat(20)))
    label.tag = 5
    label.textColor = UIColor.black
    label.text = "\(self.numbers[indexPath.row])"
    label.backgroundColor = UIColor.clear

    cell.addSubview(label)
    return cell
  }
}

extension ViewController : QuiltViewDelegate {
  func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, blockSizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
    
    // get random width and height values for the cells
    let width  = self.numberWidths[indexPath.row]
    let height = self.numberHeights[indexPath.row]
    
    return CGSize(width: width, height: height)
  }
  
  func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetsForItemAtIndexPath indexPath: IndexPath) -> UIEdgeInsets {
    return UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
  }
}
