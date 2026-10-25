//
//  Departure.swift
//  PT
//
//  Created by Kevin Chen on 25/10/2026.
//

import Foundation
import GRDB

nonisolated extension GTFSDatabase {
    /// Full-day timetable for a given date (e.g. a "Saturday timetable" view).
    func timetable(
        atStop stopId: String,
        on day: Date,
        limit: Int = 1_000
    ) async throws -> [Departure] {
        let serviceDay = ServiceCalendar.calendar.startOfDay(for: day)
        return try await dbQueue.read { db in
            try Self.fetchDepartures(db, stopId: stopId, serviceDay: serviceDay, minSeconds: 0, limit: limit)
        }
    }
    
    private static func fetchDepartures(
        _ db: Database,
        stopId: String,
        serviceDay: Date,
        minSeconds: Int,
        limit: Int
    ) throws -> [Departure] {
        let weekday = ServiceCalendar.weekdayColumn(serviceDay)  // fixed set of 7 names
 
        let rows = try Departure.Row.fetchAll(
            db,
            sql: """
                SELECT st.trip_id, st.stop_id, st.departure_time,
                       t.trip_headsign, t.direction_id, t.wheelchair_accessible,
                       t.route_id, r.route_short_name, r.route_long_name,
                       r.route_color, r.route_text_color
                FROM stop_times st
                JOIN trips  t ON t.trip_id  = st.trip_id
                JOIN routes r ON r.route_id = t.route_id
                -- the stop itself, or (for a station) all of its platforms
                WHERE st.stop_id IN (SELECT stop_id FROM stops
                WHERE stop_id = :stop OR parent_station = :stop)
                    AND st.departure_time >= :min
                    AND st.pickup_type != 1              -- "no pickup": drop-off only
                    -- skip the trip's final stop: new trip_id issued for return trip
                    AND EXISTS (SELECT 1 FROM stop_times nx
                WHERE nx.trip_id = st.trip_id
                    AND nx.stop_sequence > st.stop_sequence)
                -- does this trip's service run on :date?
                AND (
                    ( EXISTS (SELECT 1 FROM calendar c
                          WHERE c.service_id = t.service_id
                            AND c.\(weekday) = 1
                            AND :date BETWEEN c.start_date AND c.end_date)
                            AND NOT EXISTS (SELECT 1 FROM calendar_dates d
                          WHERE d.service_id = t.service_id
                            AND d.date = :date AND d.exception_type = 2) )
                      OR EXISTS (SELECT 1 FROM calendar_dates d
                          WHERE d.service_id = t.service_id
                            AND d.date = :date AND d.exception_type = 1)
                  )
                ORDER BY st.departure_time
                LIMIT :limit
                """,
            arguments: [
                "stop": stopId,
                "date": ServiceCalendar.yyyymmdd(serviceDay),
                "min": minSeconds,
                "limit": limit,
            ]
        )
 
        return rows.map { Departure(row: $0, serviceDay: serviceDay) }
    }
}
