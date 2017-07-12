//
//  ViewController.swift
//  ORCarousel
//
//  Created by Nikita Egoshin on 05/19/2017.
//  Copyright (c) 2017 Teleks. All rights reserved.
//

import UIKit
import ORCarousel


extension Date {
    
    init(day: Int, month: Int, year: Int) {
        let dateComps = DateComponents(calendar: Calendar.current, year: year, month: month, day: day)
        self = Calendar.current.date(from: dateComps)!
    }
}


class ViewController: UIViewController, ORCarouselDelegate {
    
    struct SelectedDate {
        var day: Int
        var month: Int
        var year: Int
        
        init(_ date: Date = Date()) {
            let comps = Calendar.current.dateComponents([.day, .month, .year], from: date)
            
            day = comps.day!
            month = comps.month!
            year = comps.year!
        }
        
        init(day: Int, month: Int, year: Int) {
            self.day = day
            self.month = month
            self.year = year
        }
    }
    
    let monthNames: [String] = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    
    let kDemoCellName = "DemoCarouselCell"
    let kDateComponentCellName = "DateComponentCell"
    
    let kDefaultDateIndex: Int = 3
    
    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        
        return df
    }()
    
    @IBOutlet weak var dayCarousel: ORCarousel!
    @IBOutlet weak var monthCarousel: ORCarousel!
    @IBOutlet weak var yearCarousel: ORCarousel!
    
    @IBOutlet weak var bottomCarousel: ORCarousel!
    
//    var dateItems = [Date(day: 5, month: 2, year: 1986), Date(day: 17, month: 10, year: 1972), Date(day: 11, month: 4, year: 1994), Date(day: 21, month: 8, year: 2005), Date(day: 30, month: 10, year: 1990), Date(day: 29, month: 9, year: 2012)]

    var dateItems: [Date] = []
    
    var dayRange: Range<Int> {
        let calendar = Calendar.current
        let monthAndYear = DateComponents(calendar: calendar, year: selectedDate.year, month: selectedDate.month)
        let targetDate = calendar.date(from: monthAndYear)
        
        return calendar.range(of: .day, in: .month, for: targetDate!)!
    }
    
    var monthRange = 1 ... 12
    var yearRange: CountableClosedRange<Int> {
        let today = Date()
        let dateComps = Calendar.current.dateComponents([.year], from: today) 
        
        return 1970 ... dateComps.year!
    } 
    
    
    var selectedDate: SelectedDate = SelectedDate()
    
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        bottomCarousel.scrollDirection = .vertical
        
        dayCarousel.register(UINib(nibName: kDateComponentCellName, bundle: nil), forCellWithReuseIdentifier: kDateComponentCellName)
        monthCarousel.register(UINib(nibName: kDateComponentCellName, bundle: nil), forCellWithReuseIdentifier: kDateComponentCellName)
        yearCarousel.register(UINib(nibName: kDateComponentCellName, bundle: nil), forCellWithReuseIdentifier: kDateComponentCellName)
        
        bottomCarousel.register(UINib(nibName: kDemoCellName, bundle: nil), forCellWithReuseIdentifier: kDemoCellName)
        
        dayCarousel.delegate = self
        monthCarousel.delegate = self
        yearCarousel.delegate = self
        
        bottomCarousel.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let defaultDate = Date()
        selectedDate = SelectedDate(defaultDate)
        
        dayCarousel.reloadData()
        monthCarousel.reloadData()
        yearCarousel.reloadData()
        
        bottomCarousel.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: - ORCarouselDelegate
    
    func selectedIndex(in carousel: ORCarousel) -> Int {
        let defaultIndex: Int
        
        switch carousel {
        case dayCarousel:
            defaultIndex = selectedDate.day - dayRange.lowerBound
        case monthCarousel:
            defaultIndex = selectedDate.month - monthRange.lowerBound
        case yearCarousel:
            defaultIndex = selectedDate.year - yearRange.lowerBound
        default:
            defaultIndex = kDefaultDateIndex
        }
        
        return defaultIndex
    }
    
    func numberOfItems(in carousel: ORCarousel) -> Int {
        return carousel === bottomCarousel ? dateItems.count : dateCompRange(for: carousel).count
    }
    
    func sizeForItem(atIndexPath indexPath: IndexPath, in carousel: ORCarousel) -> CGSize {
        let sideSize = carousel == bottomCarousel ? carousel.frame.size.width : carousel.frame.size.height
        
        return CGSize(width: sideSize, height: sideSize)
    }
    
    func cellForItem(atIndexPath indexPath: IndexPath, in carousel: ORCarousel) -> UICollectionViewCell {
        
        let cell: UICollectionViewCell 
        
        if carousel === bottomCarousel {
            let date = dateItems[indexPath.item]
            let demoCell = carousel.cell(withIdentifier: kDemoCellName, for: indexPath) as! DemoCarouselCell
            demoCell.textLabel.text = dateFormatter.string(from: date)
            
            cell = demoCell
        } else {
            let dateStr = descriptionForDateComponentValue(in: carousel, atIndexPath: indexPath)
            let dateCompCell = carousel.cell(withIdentifier: kDateComponentCellName, for: indexPath) as! DateComponentCell
            dateCompCell.valueLabel.text = dateStr
            
            cell = dateCompCell
        }
        
        return cell
    }
    
    func userDidSelectCell(_ cell: UICollectionViewCell, atIndexPath indexPath: IndexPath, in carousel: ORCarousel) {
        switch carousel {
        case dayCarousel:
            selectedDate.day = dayRange.lowerBound + indexPath.item
        case monthCarousel:
            let month = monthRange.lowerBound + indexPath.item
            
            if month != selectedDate.month {
                selectedDate.month = month
                dayCarousel.reloadData()
                dayCarousel.refreshSelection()
            }
        case yearCarousel:
            let year = yearRange.lowerBound + indexPath.item
            
            if year != selectedDate.year {
                selectedDate.year = year
                dayCarousel.reloadData()
                dayCarousel.refreshSelection()
            }
        case bottomCarousel:
            let date = dateItems[indexPath.item]
            onDateSelected(date)
        default:
            break
        }
    }
    
    
    // MARK: - Helpers
    
    func dateCompRange(for carousel: ORCarousel) -> CountableClosedRange<Int> {
        
        if carousel === dayCarousel { return CountableClosedRange(dayRange) }
        if carousel === monthCarousel { return monthRange }
        
        return yearRange
    }
    
    func descriptionForDateComponentValue(in carousel: ORCarousel, atIndexPath indexPath: IndexPath) -> String {
        
        let valueRange = dateCompRange(for: carousel)
        let valueIndex = valueRange.lowerBound + indexPath.item
        
        switch carousel {
        case monthCarousel:
            return monthNames[valueIndex - 1]
        default:
            break
        }
        
        return "\(valueIndex)"
    }
    
    func onDateSelected(_ date: Date) {
        selectedDate = SelectedDate(date)
        
        dayCarousel.refreshSelection()
        monthCarousel.refreshSelection()
        yearCarousel.refreshSelection()
    }
}

