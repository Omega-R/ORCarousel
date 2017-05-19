//
//  DemoCarouselCell.swift
//  ORCarousel
//
//  Created by Nikita Egoshin on 5/19/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit

class DemoCarouselCell: UICollectionViewCell {
    
    @IBOutlet weak var textLabel: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        textLabel.layer.borderColor = UIColor.gray.cgColor
        textLabel.layer.borderWidth = 1.0
        textLabel.layer.cornerRadius = 5.0
    }
}
