//
//  ORCarousel.swift
//  Metron
//
//  Created by Nikita Egoshin on 26.03.17.
//  Copyright © 2017 Omega-R. All rights reserved.
//

import UIKit
import PureLayout


@objc
public protocol ORCarouselDelegate {
    
    func numberOfItems(in carousel: ORCarousel) -> Int
    func cellForItem(atIndexPath indexPath: IndexPath, in carousel: ORCarousel) -> UICollectionViewCell
    func sizeForItem(atIndexPath indexPath: IndexPath, in carousel: ORCarousel) -> CGSize
    
    func defaultIndex(for carousel: ORCarousel) -> Int
    
@objc optional
    func userDidSelectCell(_ cell: UICollectionViewCell, atIndexPath indexPath: IndexPath, in carousel: ORCarousel)
@objc optional
    func userDidDeselectCell(_ cell: UICollectionViewCell, atIndexPath indexPath: IndexPath, in carousel: ORCarousel)
}

public class ORCarousel: UIView, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Config Properties
    
    public var scrollDirection: UICollectionViewScrollDirection = .horizontal {
        didSet {
            if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                flowLayout.scrollDirection = scrollDirection
            }
        }
    }
    
    
    // MARK: - Variables
    
    public var collectionView: UICollectionView = {
        let frame = CGRect(origin: CGPoint.zero, size: CGSize(width: 320.0, height: 100.0))
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 50.0, height: 50.0)
        layout.sectionInset = UIEdgeInsets.zero
        layout.minimumLineSpacing = 0.0
        layout.minimumInteritemSpacing = 0.0
        layout.scrollDirection = .horizontal
        
        let cv = UICollectionView(frame: frame, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    var selectedIndexPath: IndexPath? {
        guard let collectionIndexPath = collectionView.indexPathsForSelectedItems?.first else {
            return nil
        }
        
        let indexPathWithOffset = IndexPath(item: collectionIndexPath.item, section: collectionIndexPath.section)
        return itemIndexPath(from: indexPathWithOffset)
    }
    
    var isScrolling: Bool {
        return collectionView.isDragging || collectionView.isDecelerating
    }
    
    private var itemsCount: Int = 0
    private var countOfCells: Int = 0
    private var itemIndexOffset: Int = 0
    
    public weak var delegate: ORCarouselDelegate? = nil
    
    var prevWidth: CGFloat = 0.0
    
    var collectionViewSize: CGSize {
        return collectionView.frame.size
    }
    
    var scrollPosition: UICollectionViewScrollPosition {
        let flowLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        
        return flowLayout.scrollDirection == .horizontal ? .centeredHorizontally : .centeredVertically
    }
    
    var indexPathInCenter: IndexPath? {
        let flowLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let indexPath: IndexPath?
        
        if flowLayout.scrollDirection == .horizontal {
            let centerX = collectionView.contentOffset.x + collectionView.frame.size.width * 0.5
            indexPath = collectionView.indexPathForItem(at: CGPoint(x: centerX, y: collectionView.frame.origin.y * 0.5))
        } else {
            let centerY = collectionView.contentOffset.y + collectionView.frame.size.height * 0.5
            indexPath = collectionView.indexPathForItem(at: CGPoint(x: collectionView.frame.origin.x * 0.5, y: centerY))
        }
        
        return indexPath
    }
    
    var shouldSetDefaultValue: Bool = true
    
    
    // MARK: - Lifecycle
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.scrollDirection = self.scrollDirection
        }
        
        collectionView.backgroundColor = .clear
        collectionView.allowsMultipleSelection = true 
        collectionView.dataSource = self
        collectionView.delegate = self
        addSubview(collectionView)
        //collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.autoPinEdgesToSuperviewEdges()
        self.layoutIfNeeded()
        
        reloadData()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            if let selectedIndexPath = strongSelf.collectionView.indexPathsForSelectedItems?.first {
                strongSelf.scrollToItem(at: selectedIndexPath, at: strongSelf.scrollPosition, animated: false, completion: { 
                    strongSelf.selectCellInCenter(animated: false)
                })
            } else {
                strongSelf.selectCellInCenter(animated: false)
            }
        }
    }
    
    deinit {
        print("Released!")
    }
    
    
    // MARK: - Public operations
    
    public func register(_ nib: UINib?, forCellWithReuseIdentifier cellID: String) {
        collectionView.register(nib, forCellWithReuseIdentifier: cellID)
    }
    
    public func cell(withIdentifier cellID: String, for indexPath: IndexPath) -> UICollectionViewCell? {
        return collectionView.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath)
    }
    
    public func reloadData(completion: (() -> Void)? = nil) {
        collectionView.dataSource = self
        collectionView.delegate = self
        
        self.reloadCollection(completion: { [weak self] (finished) in
            guard let strongSelf = self else {
                return
            }
            
            if nil == completion {
                if strongSelf.shouldSetDefaultValue {
                    strongSelf.shouldSetDefaultValue = false
                    strongSelf.selectDefaultItemIfNeeded()
                } else {
                    strongSelf.scrollToNearestCell(animated: false, completion: {
                        strongSelf.selectCellInCenter(animated: false)
                    })
                }
            } else {
                completion!()
            }
        })
    }
    
    public func selectItem(at pos: Int, animated: Bool = true) {
        guard let centerCellIndexPath = getCenterCellIndexPath(collectionView) else {
            return
        }
        
        let itemsCount = numberOfItems().real
        let normalCenterPos = centerCellIndexPath.item % itemsCount
        let offset = pos >= 0 ? pos - normalCenterPos : normalCenterPos + pos
        
        let targetIndexPath = IndexPath(item: centerCellIndexPath.item + offset, section: 0)
        itemIndexOffset = 0
        
        scrollToItem(at: targetIndexPath, at: scrollPosition, animated: false, completion: {
            for selectedIndexPath in self.collectionView.indexPathsForSelectedItems ?? [] {
                self.collectionView.deselectItem(at: selectedIndexPath, animated: false)
            }
            
            self.selectCellInCenter()
        })
    }
    
    
    // MARK: - Private operations
    
    let collectionUpdateSemaphore = DispatchSemaphore(value: 1)
    
    private func reloadCollection(completion: ((_: Bool) -> Void)? = nil) {
        
        DispatchQueue.global().async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.collectionUpdateSemaphore.wait()
            
            DispatchQueue.main.async {
                let actualItems = strongSelf.numberOfItems()
                let actualRealItemsCount = actualItems.real
                
                if actualRealItemsCount != strongSelf.itemsCount {
                    let prevFullCycles: Int
                    
                    if let selectedIndex = strongSelf.collectionView.indexPathsForSelectedItems?.first?.item {
                        let prevSelectedItemIndex = strongSelf.itemIndexOffset + selectedIndex
                        
                        prevFullCycles = prevSelectedItemIndex / strongSelf.itemsCount
                    } else {
                        prevFullCycles = 0
                    }
                    
                    let correctionOffset = (actualRealItemsCount - strongSelf.itemsCount) * prevFullCycles
                    strongSelf.itemIndexOffset += (correctionOffset % actualItems.real)
                }
                
                strongSelf.collectionView.reloadData()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.04, execute: { 
                    completion?(true)
                    self?.collectionUpdateSemaphore.signal()
                })
            }
        }
    }
    
    let scrollSem: DispatchSemaphore = DispatchSemaphore(value: 1)
    
    private func scrollToItem(at indexPath: IndexPath, at pos: UICollectionViewScrollPosition, animated: Bool, completion: (() -> Void)? = nil) {
        DispatchQueue.global().async { [weak self] in
            self?.scrollSem.wait()
            
            DispatchQueue.main.async {
                self?.collectionView.scrollToItem(at: indexPath, at: pos, animated: animated)
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3, execute: { 
                    self?.scrollSem.signal()
                    completion?()
                })
            }
        }
    }
    
    private func itemIndexPath(from cellIndexPath: IndexPath) -> IndexPath {
        let itemOffset = cellIndexPath.item + itemIndexOffset
        let totalItems = delegate!.numberOfItems(in: self)
        let normalItemIndex = itemOffset % totalItems
        let item = normalItemIndex >= 0 ? normalItemIndex : (totalItems - 1) + normalItemIndex
        
        return IndexPath(item: item, section: cellIndexPath.section)
    }
    
    private func selectDefaultItemIfNeeded() {
        
        guard let defaultIndex = delegate?.defaultIndex(for: self) else {
            return
        }
        
        print("Select default item")
        selectItem(at: defaultIndex, animated: false)
    }
    
    private func getCenterCellIndexPath(_ collectionView: UICollectionView) -> IndexPath? {
        let totalItems = numberOfItems().inUse
        let centerItem = Int(floor(Double(totalItems) * 0.5))
        
        return IndexPath(item: centerItem, section: 0)
    }
    
    private func scrollToNearestCell(animated: Bool = true, completion: (() -> Void)? = nil) {
        
        guard let indexPath = indexPathInCenter else {
            return
        }
        
        scrollToItem(at: indexPath, at: scrollPosition, animated: animated, completion: completion)
    }
    
    private func scrollToCenter(animated: Bool = true) {
        let itemsCount = collectionView.numberOfItems(inSection: 0)
        
        guard itemsCount > 0 else {
            return
        }
        
        let centralItem = Int(floor(Double(itemsCount) * 0.5))
        let centralIndexPath = IndexPath(item: centralItem, section: 0)
        
        scrollToItem(at: centralIndexPath, at: [], animated: animated)
    }
    
    private func selectCellInCenter(animated: Bool = true) {
        let visibleIndexPath = collectionView.indexPathsForVisibleItems.sorted { (indexPath1, indexPath2) -> Bool in
            return indexPath1.item <= indexPath2.item
        }
        
        guard visibleIndexPath.count > 0 else {
            return
        }
        
        let centralIndex = Int(floor(Double(visibleIndexPath.count) * 0.5))
        let centerIndexPath = visibleIndexPath[centralIndex]
        
        guard nil == collectionView.indexPathsForSelectedItems ||
            !collectionView.indexPathsForSelectedItems!.contains(centerIndexPath) else {
            
            return
        }
        
        collectionView.selectItem(at: centerIndexPath, animated: animated, scrollPosition: [])
        
        if let cell = collectionView.cellForItem(at: centerIndexPath) {
            let totalItems = delegate!.numberOfItems(in: self)
            
            if totalItems > 0 {
                let selectedIndexPath = itemIndexPath(from: centerIndexPath)
                delegate?.userDidSelectCell?(cell, atIndexPath: selectedIndexPath, in: self)
            }
        }
    }
    
    private func deselectLastSelectedItems() {
        guard let selectedIndexPath = collectionView.indexPathsForSelectedItems else {
            return
        }
        
        for indexPath in selectedIndexPath {
            if let cell = collectionView.cellForItem(at: indexPath) {
                collectionView.deselectItem(at: indexPath, animated: true)
                delegate?.userDidDeselectCell?(cell, atIndexPath: indexPath, in: self)
            }
        }
    }
    
    private func numberOfItems() -> (real: Int, inUse: Int) {
        guard let cellCount = delegate?.numberOfItems(in: self) else {
            return (real: 0, inUse: 0)
        }
        
        guard cellCount > 0 else {
            return (real: 0, inUse: 0)
        }
        
        let itemsInUse = cellCount > 500 ? cellCount : 500
        
        return (real: cellCount, inUse: itemsInUse)
    }
    
    
    // MARK: - UICollectionViewDataSource/Delegate
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let items = numberOfItems()
        
        itemsCount = items.real
        countOfCells = items.inUse
        
        return items.inUse
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let normalIndexPath = itemIndexPath(from: indexPath)
        return delegate?.cellForItem(atIndexPath: normalIndexPath, in: self) ?? UICollectionViewCell()
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        cell.isSelected = selectedIndexPath != nil && selectedIndexPath! == indexPath
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        if let selectedIndexPath = collectionView.indexPathsForSelectedItems, !selectedIndexPath.contains(indexPath) {
//            collectionView.deselectItem(at: indexPath, animated: true)
//        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if let selectedIndexPath = collectionView.indexPathsForSelectedItems, selectedIndexPath.contains(indexPath) {
            return true
        }
        
        return false
    }
    
    public func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        if let selectedIndexPath = collectionView.indexPathsForSelectedItems, selectedIndexPath.contains(indexPath) {
            return false
        }
        
        return true
    }
    
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let cellSize = delegate!.sizeForItem(atIndexPath: indexPath, in: self)
        return cellSize
    }
    
    
    // MARK: - ScrollView delegate
    
    func scrollOffsetBounds() -> (min: CGFloat, max: CGFloat, scrollDelta: CGFloat) {
        let deltaOffset: CGFloat
        let maxScrollOffset: CGFloat
        let minScrollOffset: CGFloat
        
        let collectionLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        
        if collectionLayout.scrollDirection == .horizontal {
            deltaOffset = collectionView.contentSize.width * 0.25
            maxScrollOffset = collectionView.contentSize.width * 0.75
            minScrollOffset = collectionView.contentSize.width * 0.25
        } else {
            deltaOffset = collectionView.contentSize.height * 0.25
            maxScrollOffset = collectionView.contentSize.height * 0.75
            minScrollOffset = collectionView.contentSize.height * 0.25
        }
        
        return (min: minScrollOffset, max: maxScrollOffset, scrollDelta: deltaOffset)
    }
    
    func fixScrollOffsetIfNeeded() {
        let offsetBounds = scrollOffsetBounds()
        let itemIndexOffsetDelta = Int(round(Double(collectionView.numberOfItems(inSection: 0)) * 0.25))
        
        let flowLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        var indexChangePositive: Bool?
        
        if flowLayout.scrollDirection == .horizontal {
            if collectionView.contentOffset.x >= offsetBounds.max {
                collectionView.contentOffset.x -= offsetBounds.scrollDelta
                indexChangePositive = true
            } else if collectionView.contentOffset.x <= offsetBounds.min {
                collectionView.contentOffset.x += offsetBounds.scrollDelta
                indexChangePositive = false
            }
        } else {
            if collectionView.contentOffset.y >= offsetBounds.max {
                collectionView.contentOffset.y -= offsetBounds.scrollDelta
                indexChangePositive = true
            } else if collectionView.contentOffset.y <= offsetBounds.min {
                collectionView.contentOffset.y += offsetBounds.scrollDelta
                indexChangePositive = false
            }
        }
        
        if let positive = indexChangePositive {
            itemIndexOffset += positive ? itemIndexOffsetDelta : -itemIndexOffsetDelta
        }
        
        collectionView.reloadData()
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        fixScrollOffsetIfNeeded()
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        deselectLastSelectedItems()
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            print("End dragging")
            scrollToNearestCell()
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if !collectionView.isPagingEnabled {
            print("End decelerating")
            scrollToNearestCell()
        }
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        print("End scrolling animation")
        
        self.selectCellInCenter()
    }
}
