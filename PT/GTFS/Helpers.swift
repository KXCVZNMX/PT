//
//  Helpers.swift
//  PT
//
//  Created by Kevin Chen on 25/10/2026.
//

import Foundation

// MARK: - Calendar Helpers

nonisolated enum ServiceCalendar {
    /// Service Calendar timezone should uphold the timezone of the agency, which is Australia/Melbourne
    static let timeZone = TimeZone(identifier: "Australia/Melbourne")!
    
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }
    
    /// Converting dates of YYYY-MM-DD to YYYYMMDD, adhereing to how the database stores it
    static func yyyymmdd(_ date: Date) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return c.year! * 10000 + c.month! * 100 + c.day!
    }
    
    /// Returns strings of weekdays' names
    static func weekdayColumn(_ date: Date) -> String {
        let names = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        return names[calendar.component(.weekday, from: date) - 1]  // 1 = Sunday
    }
}

// MARK: - Time Helpers

nonisolated enum GTFSTime {
    /// Seconds since local midnight, for "now".
    static func secondsSinceMidnight(
        _ date: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60 + (c.second ?? 0)
    }
    
    /// 90000 -> "01:00 (+1d)". GTFS times past midnight helongs to the next calendar day but the same service day
    static func format(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let text = String(format: "%02d:%02d", h % 24, m)
        return h >= 24 ? "\(text) (+\(h / 24)d" : text
    }
}
