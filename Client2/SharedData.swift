//
//  SharedData.swift
//  Client2
//
//  Created by Kevin Zhang on 6/27/16.
//  Copyright © 2016 Kevin Zhang. All rights reserved.
//

import Foundation

extension NSString
{
    var parseJSONString: AnyObject?
    {
        let data = self.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        
        if let jsonData = data
        {
            // Will return an object or nil if JSON decoding fails
            do
            {
                let message = try NSJSONSerialization.JSONObjectWithData(jsonData, options:.MutableContainers)
                if let jsonResult = message as? NSMutableArray
                {
                    print(jsonResult)
                    
                    return jsonResult //Will return the json array output
                }
                else
                {
                    return nil
                }
            }
            catch let error as NSError
            {
                print("An error occurred: \(error)")
                return nil
            }
        }
        else
        {
            // Lossless conversion of the string was not possible
            return nil
        }
    }
}

extension NSDate
{
    convenience init(dateString:String) {
        let dateStringFormatter = NSDateFormatter()
        dateStringFormatter.dateFormat = "yyyy-MM-dd"
        dateStringFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        let d = dateStringFormatter.dateFromString(dateString)!
        self.init(timeInterval:0, sinceDate:d)
    }
    
    func hour() -> Int
    {
        //Get Hour
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(.Hour, fromDate: self)
        let hour = components.hour
        
        //Return Hour
        return hour
    }
    
    func month() -> Int
    {
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(.Month, fromDate: self)
        let minute = components.month
        
        return minute
    }
    
    func day() -> Int
    {
        //Get Minute
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(.Day, fromDate: self)
        let day = components.day
        return day
    }
    
    func formatDateString() -> String
    {
        let dateFormatter:NSDateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        let DateInFormat:String = dateFormatter.stringFromDate(self)
        
        //Return Short Time String
        return DateInFormat
    }
    
    func dayOfWeek() -> Int {
        let gregorianCalendar: NSCalendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)!
        let components = gregorianCalendar.components(.Weekday, fromDate: self)
        var weekDay = components.weekday
        
        //align weekday with database, which starts with Monday == 1
        weekDay -= 1
        if weekDay == 0 {
            weekDay = 7
        }
        
        return weekDay
    }
    
    func tomorrow() -> NSDate {
        
        let daysToAdd:Int = 1
        
        // Set up date components
        let dateComponents: NSDateComponents = NSDateComponents()
        dateComponents.day = daysToAdd
        
        // Create a calendar
        let gregorianCalendar: NSCalendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)!
        let tomorrowDate: NSDate = gregorianCalendar.dateByAddingComponents(dateComponents, toDate: self, options:NSCalendarOptions(rawValue: 0))!
        
        return tomorrowDate
    }
}

extension Double {
    /// Rounds the double to decimal places value
    func roundToPlaces(places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return round(self * divisor) / divisor
    }
}