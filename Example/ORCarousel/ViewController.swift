//
//  ViewController.swift
//  ORCarousel
//
//  Created by Teleks on 05/19/2017.
//  Copyright (c) 2017 Teleks. All rights reserved.
//

import UIKit
import ORCarousel

class ViewController: UIViewController, ORCarouselDelegate {
    
    let kDemoCellName = "DemoCarouselCell"
    
    @IBOutlet weak var topCarousel: ORCarousel!
    @IBOutlet weak var bottomCarousel: ORCarousel!
    
    var itemsRange = 1 ..< 12
    
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        bottomCarousel.scrollDirection = .vertical
        
        topCarousel.register(UINib(nibName: kDemoCellName, bundle: nil), forCellWithReuseIdentifier: kDemoCellName)
        bottomCarousel.register(UINib(nibName: kDemoCellName, bundle: nil), forCellWithReuseIdentifier: kDemoCellName)
        
        topCarousel.delegate = self
        bottomCarousel.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        topCarousel.reloadData()
        bottomCarousel.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: - ORCarouselDelegate
    
    func defaultIndex(for carousel: ORCarousel) -> Int {
        return 7
    }
    
    func numberOfItems(in carousel: ORCarousel) -> Int {
        return itemsRange.count
    }
    
    func sizeForItem(atIndexPath indexPath: IndexPath, in carousel: ORCarousel) -> CGSize {
        let sideSize = carousel == topCarousel ? carousel.frame.size.height : carousel.frame.size.width
        
        return CGSize(width: sideSize, height: sideSize)
    }
    
    func cellForItem(atIndexPath indexPath: IndexPath, in carousel: ORCarousel) -> UICollectionViewCell {
        let text = String(describing: indexPath.item + itemsRange.lowerBound)
        let cell = carousel.cell(withIdentifier: kDemoCellName, for: indexPath) as! DemoCarouselCell
        cell.textLabel.text = text
        
        return cell
    }
}

