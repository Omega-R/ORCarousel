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
    
    func selectedIndex(in carousel: ORCarousel) -> Int
    
@objc optional
    func userDidSelectCell(_ cell: UICollectionViewCell, atIndexPath indexPath: IndexPath, in carousel: ORCarousel)
@objc optional
    func userDidDeselectCell(_ cell: UICollectionViewCell, atIndexPath indexPath: IndexPath, in carousel: ORCarousel)
}

public class ORCarousel: UIView, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Config Properties
    
    public var scrollDirection: UICollectionView.ScrollDirection = .horizontal {
        didSet {
            if let flowLayout = containerView.collectionViewLayout as? UICollectionViewFlowLayout {
                flowLayout.scrollDirection = scrollDirection
            }
        }
    }
    
    
    // MARK: - Variables
    
    @IBOutlet public weak var collectionView: UICollectionView!
    
    private var containerView: UICollectionView {
        if nil == collectionView {
            let frame = CGRect(origin: CGPoint.zero, size: CGSize(width: 320.0, height: 100.0))
            let layout = UICollectionViewFlowLayout()
            layout.itemSize = CGSize(width: 50.0, height: 50.0)
            layout.sectionInset = UIEdgeInsets.zero
            layout.minimumLineSpacing = 0.0
            layout.minimumInteritemSpacing = 0.0
            layout.scrollDirection = .horizontal
            
            let cv = UICollectionView(frame: frame, collectionViewLayout: layout)
            cv.translatesAutoresizingMaskIntoConstraints = false
            
            addSubview(cv)
            
            cv.autoPinEdgesToSuperviewEdges()
            self.layoutIfNeeded()
            
            collectionView = cv
        }
        
        collectionView.backgroundColor = .clear
        collectionView.allowsMultipleSelection = true 
        collectionView.dataSource = self
        collectionView.delegate = self
        
        return collectionView
    }
    
    public var selectedIndexPath: IndexPath? {
        guard let collectionIndexPath = containerView.indexPathsForSelectedItems?.first else {
            return nil
        }
        
        let indexPathWithOffset = IndexPath(item: collectionIndexPath.item, section: collectionIndexPath.section)
        return itemIndexPath(from: indexPathWithOffset)
    }
    
    var isScrolling: Bool {
        return containerView.isDragging || containerView.isDecelerating
    }
    
    private var itemsCount: Int = 0
    private var countOfCells: Int = 0
    private var itemIndexOffset: Int = 0
    
    public weak var delegate: ORCarouselDelegate? = nil
    
    var prevWidth: CGFloat = 0.0
    
    @IBInspectable var showScrollIndicator: Bool = true {
        didSet {
            if nil != collectionView {
                containerView.showsHorizontalScrollIndicator = showScrollIndicator
                containerView.showsVerticalScrollIndicator = showScrollIndicator
            }
        }
    }
    
    public var containerViewSize: CGSize {
        return containerView.frame.size
    }
    
    var scrollPosition: UICollectionView.ScrollPosition {
        let flowLayout = containerView.collectionViewLayout as! UICollectionViewFlowLayout
        
        return flowLayout.scrollDirection == .horizontal ? .centeredHorizontally : .centeredVertically
    }
    
    var indexPathInCenter: IndexPath? {
        let flowLayout = containerView.collectionViewLayout as! UICollectionViewFlowLayout
        let indexPath: IndexPath?
        
        if flowLayout.scrollDirection == .horizontal {
            let centerX = containerView.contentOffset.x + containerView.frame.size.width * 0.5
            indexPath = containerView.indexPathForItem(at: CGPoint(x: centerX, y: containerView.frame.origin.y * 0.5))
        } else {
            let centerY = containerView.contentOffset.y + containerView.frame.size.height * 0.5
            indexPath = containerView.indexPathForItem(at: CGPoint(x: containerView.frame.origin.x * 0.5, y: centerY))
        }
        
        return indexPath
    }
    
    var shouldSetDefaultValue: Bool = true
    
    
    // MARK: - Lifecycle
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        
        if let flowLayout = containerView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.scrollDirection = self.scrollDirection
        }
        
        reloadData()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            if let selectedIndexPath = strongSelf.containerView.indexPathsForSelectedItems?.first {
                strongSelf.scrollToItem(at: selectedIndexPath, at: strongSelf.scrollPosition, animated: false, completion: { 
                    strongSelf.selectCellInCenter(animated: false)
                })
            }
        }
    }
    
    deinit {
        print("Released!")
    }
    
    
    // MARK: - Public operations
    
    public func register(_ nib: UINib?, forCellWithReuseIdentifier cellID: String) {
        containerView.register(nib, forCellWithReuseIdentifier: cellID)
    }
    
    public func cell(withIdentifier cellID: String, for indexPath: IndexPath) -> UICollectionViewCell? {
        return containerView.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath)
    }
    
    public func reloadData(completion: (() -> Void)? = nil) {
        containerView.dataSource = self
        containerView.delegate = self
        
        self.reloadCollection(completion: { [weak self] (finished) in
            guard let strongSelf = self else {
                return
            }
            
            if nil == completion {
                strongSelf.refreshSelection()
            } else {
                completion!()
            }
        })
    }
    
    let refreshSelectionSemaphore = DispatchSemaphore(value: 1)
    
    public func refreshSelection() {
        
        DispatchQueue.global().async { [weak self] in
            self?.refreshSelectionSemaphore.wait()
            
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                let targetPos = strongSelf.delegate!.selectedIndex(in: strongSelf)
                
                strongSelf.selectItem(at: targetPos, completion: { [weak self] in
                    self?.refreshSelectionSemaphore.signal()
                })
            }
        }
    }
    
    private func selectItem(at pos: Int, animated: Bool = true, completion: @escaping (() -> Void)) {
        let itemsCount = numberOfItems().real
        
        guard itemsCount > 0 else {
            return
        }
        
        containerView.setContentOffset(containerView.contentOffset, animated: false)
        
        guard let centerCellIndexPath = getCenterCellIndexPath(containerView) else {
            return
        }
        
        let normalCenterPos = centerCellIndexPath.item % itemsCount
        let offset = pos >= 0 ? pos - normalCenterPos : normalCenterPos + pos
        
        let targetIndexPath = IndexPath(item: centerCellIndexPath.item + offset, section: 0)
        itemIndexOffset = 0
        
        scrollToItem(at: targetIndexPath, at: scrollPosition, animated: false, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            for selectedIndexPath in strongSelf.containerView.indexPathsForSelectedItems ?? [] {
                strongSelf.containerView.deselectItem(at: selectedIndexPath, animated: false)
            }
            
            strongSelf.selectCellInCenter()
            
            completion()
        })
    }
    
    
    // MARK: - Private operations
    
    let collectionUpdateSemaphore = DispatchSemaphore(value: 1)
    
    private func reloadCollection(completion: ((_: Bool) -> Void)? = nil) {
        
        DispatchQueue.global().async { [weak self] in
            self?.collectionUpdateSemaphore.wait()
            
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                let actualItems = strongSelf.numberOfItems()
                let actualRealItemsCount = actualItems.real
                
                if actualRealItemsCount != strongSelf.itemsCount {
                    let prevFullCycles: Int
                    
                    if let selectedIndex = strongSelf.containerView.indexPathsForSelectedItems?.first?.item {
                        let prevSelectedItemIndex = strongSelf.itemIndexOffset + selectedIndex
                        
                        prevFullCycles = prevSelectedItemIndex / strongSelf.itemsCount
                    } else {
                        prevFullCycles = 0
                    }
                    
                    let correctionOffset = (actualRealItemsCount - strongSelf.itemsCount) * prevFullCycles
                    strongSelf.itemIndexOffset += (correctionOffset % actualItems.real)
                }
                
                strongSelf.containerView.reloadData()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.04, execute: { [weak self] in
                    completion?(true)
                    self?.collectionUpdateSemaphore.signal()
                })
            }
        }
    }
    
    let scrollSem: DispatchSemaphore = DispatchSemaphore(value: 1)
    
    private func scrollToItem(at indexPath: IndexPath, at pos: UICollectionView.ScrollPosition, animated: Bool, completion: (() -> Void)? = nil) {
        DispatchQueue.global().async { [weak self] in
            self?.scrollSem.wait()
            
            DispatchQueue.main.async {
                self?.containerView.scrollToItem(at: indexPath, at: pos, animated: animated)
                
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
        
        refreshSelection()
    }
    
    private func getCenterCellIndexPath(_ containerView: UICollectionView) -> IndexPath? {
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
        let itemsCount = containerView.numberOfItems(inSection: 0)
        
        guard itemsCount > 0 else {
            return
        }
        
        let centralItem = Int(floor(Double(itemsCount) * 0.5))
        let centralIndexPath = IndexPath(item: centralItem, section: 0)
        
        scrollToItem(at: centralIndexPath, at: [], animated: animated)
    }
    
    private func selectCellInCenter(animated: Bool = true) {
        let visibleIndexPath = containerView.indexPathsForVisibleItems.sorted { (indexPath1, indexPath2) -> Bool in
            return indexPath1.item <= indexPath2.item
        }
        
        guard visibleIndexPath.count > 0 else {
            return
        }
        
        let centralIndex = Int(floor(Double(visibleIndexPath.count) * 0.5))
        let centerIndexPath = visibleIndexPath[centralIndex]
        
        guard nil == containerView.indexPathsForSelectedItems ||
            !containerView.indexPathsForSelectedItems!.contains(centerIndexPath) else {
            
            return
        }
        
        containerView.selectItem(at: centerIndexPath, animated: animated, scrollPosition: [])
        
        if let cell = containerView.cellForItem(at: centerIndexPath) {
            let totalItems = delegate!.numberOfItems(in: self)
            
            if totalItems > 0 {
                let selectedIndexPath = itemIndexPath(from: centerIndexPath)
                delegate?.userDidSelectCell?(cell, atIndexPath: selectedIndexPath, in: self)
            }
        }
    }
    
    private func deselectLastSelectedItems() {
        guard let selectedIndexPath = containerView.indexPathsForSelectedItems else {
            return
        }
        
        for indexPath in selectedIndexPath {
            if let cell = containerView.cellForItem(at: indexPath) {
                containerView.deselectItem(at: indexPath, animated: true)
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
    
    public func collectionView(_ containerView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let items = numberOfItems()
        
        itemsCount = items.real
        countOfCells = items.inUse
        
        return items.inUse
    }
    
    public func collectionView(_ containerView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let normalIndexPath = itemIndexPath(from: indexPath)
        return delegate?.cellForItem(atIndexPath: normalIndexPath, in: self) ?? UICollectionViewCell()
    }
    
    public func collectionView(_ containerView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        cell.isSelected = selectedIndexPath != nil && selectedIndexPath! == indexPath
    }
    
    public func collectionView(_ containerView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        if let selectedIndexPath = containerView.indexPathsForSelectedItems, !selectedIndexPath.contains(indexPath) {
//            containerView.deselectItem(at: indexPath, animated: true)
//        }
    }
    
    public func collectionView(_ containerView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if let selectedIndexPath = containerView.indexPathsForSelectedItems, selectedIndexPath.contains(indexPath) {
            return true
        }
        
        return false
    }
    
    public func collectionView(_ containerView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        if let selectedIndexPath = containerView.indexPathsForSelectedItems, selectedIndexPath.contains(indexPath) {
            return false
        }
        
        return true
    }
    
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    public func collectionView(_ containerView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let cellSize = delegate!.sizeForItem(atIndexPath: indexPath, in: self)
        return cellSize
    }
    
    
    // MARK: - ScrollView delegate
    
    func scrollOffsetBounds() -> (min: CGFloat, max: CGFloat, scrollDelta: CGFloat) {
        let deltaOffset: CGFloat
        let maxScrollOffset: CGFloat
        let minScrollOffset: CGFloat
        
        let collectionLayout = containerView.collectionViewLayout as! UICollectionViewFlowLayout
        
        if collectionLayout.scrollDirection == .horizontal {
            deltaOffset = containerView.contentSize.width * 0.25
            maxScrollOffset = containerView.contentSize.width * 0.75
            minScrollOffset = containerView.contentSize.width * 0.25
        } else {
            deltaOffset = containerView.contentSize.height * 0.25
            maxScrollOffset = containerView.contentSize.height * 0.75
            minScrollOffset = containerView.contentSize.height * 0.25
        }
        
        return (min: minScrollOffset, max: maxScrollOffset, scrollDelta: deltaOffset)
    }
    
    func fixScrollOffsetIfNeeded() {
        let offsetBounds = scrollOffsetBounds()
        let itemIndexOffsetDelta = Int(round(Double(containerView.numberOfItems(inSection: 0)) * 0.25))
        
        let flowLayout = containerView.collectionViewLayout as! UICollectionViewFlowLayout
        var indexChangePositive: Bool?
        
        if flowLayout.scrollDirection == .horizontal {
            if containerView.contentOffset.x >= offsetBounds.max {
                containerView.contentOffset.x -= offsetBounds.scrollDelta
                indexChangePositive = true
            } else if containerView.contentOffset.x <= offsetBounds.min {
                containerView.contentOffset.x += offsetBounds.scrollDelta
                indexChangePositive = false
            }
        } else {
            if containerView.contentOffset.y >= offsetBounds.max {
                containerView.contentOffset.y -= offsetBounds.scrollDelta
                indexChangePositive = true
            } else if containerView.contentOffset.y <= offsetBounds.min {
                containerView.contentOffset.y += offsetBounds.scrollDelta
                indexChangePositive = false
            }
        }
        
        if let positive = indexChangePositive {
            itemIndexOffset += positive ? itemIndexOffsetDelta : -itemIndexOffsetDelta
        }
        
        containerView.reloadData()
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
        if !containerView.isPagingEnabled {
            print("End decelerating")
            scrollToNearestCell()
        }
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        print("End scrolling animation")
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) { 
            self.selectCellInCenter()
        }
    }
}
