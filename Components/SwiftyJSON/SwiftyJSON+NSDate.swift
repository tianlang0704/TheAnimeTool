//
//  SwiftyJSON+NSDate.swift
//  FinalProject
//
//  Created by Tieria C.Monk on 8/12/16.
//
//

import Foundation
import SwiftyJSON

extension JSON {
    public var date: NSDate? {
        get {
            if let str = self.string {
                return JSON.jsonDateFormatter.dateFromString(str)
            }
            return nil
        }
    }
    
    private static let jsonDateFormatter: NSDateFormatter = {
        let fmt = NSDateFormatter()
        fmt.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        fmt.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        return fmt
    }()
}