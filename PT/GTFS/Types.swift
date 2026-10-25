//
//  Types.swift
//  PT
//
//  Created by Kevin Chen on 23/10/2026.
//

import Foundation
import CoreLocation
import GRDB

// MARK: - Database Types

/// An enum purely for namespace decluttering
nonisolated enum GTFS {
    nonisolated struct Agency: Decodable, FetchableRecord, TableRecord, Sendable {
        static let databaseTableName = "agency"
        static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
        
        var agencyId: String
        var agencyName: String
        var agencyUrl: String
        var agencyTimezone: String
        var agencyLang: String
        var agencyFareUrl: String
    }
    
    nonisolated struct Calendar: Decodable, FetchableRecord, TableRecord, Sendable {
        static let databaseTableName = "calendar"
        static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
        
        var serviceId: String
        var monday: Int
        var tuesday: Int
        var wednesday: Int
        var thursday: Int
        var friday: Int
        var saturday: Int
        var sunday: Int
        var startDate: String
        var endData: String
    }
    
    nonisolated struct CalendarDate: Decodable, FetchableRecord, TableRecord, Sendable {
        static let databaseTableName = "calendar_dates"
        static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
        
        var serviceId: String
        var date: String
        var exceptionType: Int
    }
    
    nonisolated struct Level: Decodable, FetchableRecord, TableRecord, Sendable {
        static let databaseTableName = "levels"
        static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
        
        var levelId: String
        var levelIndex: Double
        var levelName: String?
    }
    
    nonisolated struct Pathway: Decodable, FetchableRecord, TableRecord, Sendable {
        static let databaseTableName = "pathways"
        static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
        
        var pathwayId: String
        var fromStopId: String
        var toStopId: String
        var pathwayMode: Int
        var isBidirectional: Int
        var traversalTime: Int
    }
    
    nonisolated struct Route: Decodable, FetchableRecord, TableRecord, Sendable {
        static let databaseTableName = "routes"
        static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
        
        var routeId: String
        var country: String
        var state: String
        var routeType: String
        var routeNumber: String
        var agencyId: String?
        var routeShortName: String
        var routeLongName: String
        var gtfsRouteType: String   // Not sure what this represents. Might be invalid parsing. Fix later if necessary
        var routeColor: String
        var routeTextColor: String
    }
    
    nonisolated struct Shape: Decodable, FetchableRecord, TableRecord, Sendable {
        static let databaseTableName = "shapes"
        static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
        
        var shapeId: String
        var routeType: String
        var routeId: String
        var source: String
        var variant: String
        var direction: String
        var shapePtLat: Double
        var shapePtLon: Double
        var shapePtSequence: Int
        var shapeDistTraveled: Double
        
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: shapePtLat, longitude: shapePtLon)
        }
    }
    
    nonisolated struct StopTime: Decodable, FetchableRecord, TableRecord, Sendable {
        static let databaseTableName = "stop_times"
        static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
        
        var tripId: String
        var routeType: String
        var routeId: String
        var timetableType: String
        var arrivalTime: Int?      // seconds since midnight (can exceed 86_400 for timetable services scheduled for past midnight)
        var departureTime: Int?    // seconds since midnight (can exceed 86_400 for timetable services scheduled for past midnight)
        var stopId: String
        var stopSequence: Int
        var stopHeadsign: String?
        var pickupType: Int
        var dropOffType: Int
        var shapeDistTraveled: Double?
    }
    
    nonisolated struct Stop: Decodable, FetchableRecord, TableRecord, Sendable {
        static let databaseTableName = "stops"
        static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
        
        var stopId: String
        var stopName: String
        var stopLat: Double
        var stopLon: Double
        var stopUrl: String
        var locationType: Int
        var parentStation: String?
        var wheelchairBoarding: Int
        var levelId: String?
        
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: stopLat, longitude: stopLon)
        }
    }
    
    nonisolated struct Transfer: Decodable, FetchableRecord, TableRecord, Sendable {
        static let databaseTableName = "transfers"
        static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
        
        var fromStopId: String
        var toStopId: String
        var fromRouteId: String
        var toRouteId: String
        var fromTripId: String
        var toTripId: String
        var transferType: Int
        var minTransferTime: Int
    }
    
    nonisolated struct Trip: Decodable, FetchableRecord, TableRecord, Sendable {
        static let databaseTableName = "trips"
        static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
        
        var tripId: String
        var routeId: String
        var routeType: String
        var routeNumber: String
        var serviceId: String
        var timetableType: String
        var shapeId: String
        var tripHeadsign: String
        var directionId: Int
        var blockId: String?
        var wheelchairAccessible: Int
    }
}

// MARK: - Helper Types 

nonisolated struct Departure{
    nonisolated struct Row: Decodable, FetchableRecord, Sendable {
        static let databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy = .convertFromSnakeCase
        
        var tripId: String
        var stopId: String
        var departureTime: Int          // seconds since the service day began; can be >= 86_400
        var tripHeadsign: String
        var directionId: Int
        var wheelchairAccessible: Int
        var routeId: String
        var routeShortName: String
        var routeLongName: String
        var routeColor: String
        var routeTextColor: String
    }
    
    let row: Row
    let serviceDay: Date
    
    var scheduled: Date {
        ServiceCalendar.calendar.date(byAdding: .second, value: row.departureTime, to: serviceDay)!
    }
}

nonisolated struct TripStop: Decodable, FetchableRecord, Sendable {
    static let databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy = .convertFromSnakeCase
    var stopId: String
    var stopName: String
    var stopSequence: Int
    var arrivalTime: Int
    var departureTime: Int
}
