//
//  Database.swift
//  PT
//
//  Created by Kevin Chen on 25/10/2026.
//

import Foundation
import CoreLocation
import GRDB


// MARK: - Database Operations

nonisolated final class GTFSDatabase {
    let dbQueue: DatabaseQueue
    
    init(path: String) throws {
        var config = Configuration()
        config.readonly = true
        dbQueue = try DatabaseQueue(path: path, configuration: config)
    }
    
    /// Shared reference of the db 
    static let shared: GTFSDatabase = {
        do {
            return try GTFSDatabase(path: GTFSStore.installedDatabasePath())
        } catch {
            fatalError("Could not open gtfs.sqlite: \(error)")
        }
    }()
    
    // MARK: stop_times
    
    /// Departures for a specific stop after `afterSeconds`
    func departures(
        fromStop stopId: String,
        after afterSeconds: Int,
        limit: Int = 10
    ) async throws -> [GTFS.StopTime] {
        try await dbQueue.read { db in
            try GTFS.StopTime
                .filter(Column("stop_id") == stopId)
                .filter(Column("departure_time") >= afterSeconds)
                .order(Column("departure_time"))
                .limit(limit)
                .fetchAll(db)
        }
    }
    
    /// Every stop of one route in order
    func stops(forTrip tripId: String) async throws -> [GTFS.StopTime] {
        try await dbQueue.read { db in
            try GTFS.StopTime
                .filter(Column("trip_id") == tripId)
                .order(Column("stop_sequence"))
                .fetchAll(db)
        }
    }
    
    /// All distinct stop IDs served by a route (e.g. `routeType = 3` (trams), `routeId = 109` (route 109))
    func stopIds(routeType: String, routeId: String) async throws -> [String] {
        try await dbQueue.read { db in
            try String.fetchAll(
                db,
                sql: """
                    SELECT DISTINCT stop_id
                    FROM stop_times
                    WHERE route_type = ? AND route_id = ?
                    """,
                arguments: [routeType, routeId]
            )
        }
    }
    
    /// All routes which feeds into this stop
    func routes(atStop stopId: String) async throws
        -> [(routeType: String, routeId: String, direction: String?)] {
        try await routes(atStops: [stopId])[stopId] ?? []
    }
    
    /// Batch fetch version
    func routes(atStops stopIds: [String]) async throws -> [String: [(routeType: String, routeId: String, direction: String)]] {
        guard !stopIds.isEmpty else { return [:] }

        return try await dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    WITH counts AS (
                        SELECT st.stop_id, st.route_type, st.route_id,
                               t.direction_id, t.trip_headsign, COUNT(*) AS n
                        FROM stop_times st
                        JOIN trips t ON t.trip_id = st.trip_id
                        WHERE st.stop_id IN (\(databaseQuestionMarks(count: stopIds.count)))
                          AND t.trip_headsign IS NOT NULL
                          AND t.trip_headsign <> ''
                        GROUP BY st.stop_id, st.route_type, st.route_id,
                                 t.direction_id, t.trip_headsign
                    ),
                    ranked AS (
                        SELECT *,
                           ROW_NUMBER() OVER (
                               PARTITION BY stop_id, route_type, route_id, direction_id
                               ORDER BY n DESC, trip_headsign
                           ) AS rn
                        FROM counts
                    )
                    SELECT stop_id, route_type, route_id, trip_headsign
                    FROM ranked
                    WHERE rn = 1
                    ORDER BY stop_id, route_type, route_id, direction_id
                    """,
                arguments: StatementArguments(stopIds)
            )

            var result: [String: [(routeType: String, routeId: String, direction: String)]] = [:]
            for row in rows {
                let stopId: String = row["stop_id"]
                result[stopId, default: []].append((
                    routeType: row["route_type"],
                    routeId: row["route_id"],
                    direction: row["trip_headsign"]
                ))
            }
            return result
        }
    }
    
    // MARK: shapes
    
    /// The polyline for a route (shape), in drawing order
    func polyline(forShape shapeId: String) async throws -> [CLLocationCoordinate2D] {
        try await dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT shape_pt_lat, shape_pt_lon
                    FROM shapes
                    WHERE shape_id = ?
                    ORDER BY shape_pt_sequence
                    """,
                arguments: [shapeId]
            ).map {
                CLLocationCoordinate2D(
                    latitude: $0["shape_pt_lat"],
                    longitude: $0["shape_pt_lon"]
                )
            }
        }
    }
    
    /// All shape IDs for a route + direction ("H" or "R").
    /// A route usually has several variants (depot runs, detours, etc.).
    func shapeIds(
        routeType: String,
        routeId: String,
        direction: String
    ) async throws -> [String] {
        try await dbQueue.read { db in
            try String.fetchAll(
                db,
                sql: """
                    SELECT DISTINCT shape_id
                    FROM shapes
                    WHERE route_type = ? AND route_id = ? AND direction = ?
                    ORDER BY variant
                    """,
                arguments: [routeType, routeId, direction]
            )
        }
    }
    
    /// Returns the most shapeID containing the most points. Useful for drawing only one line per route
    func primaryShapeId(
        routeType: String,
        routeId: String,
        direction: String
    ) async throws -> String? {
        try await dbQueue.read { db in
            try String.fetchOne(
                db,
                sql: """
                    SELECT shape_id
                    FROM shapes
                    WHERE route_type = ? AND route_id = ? AND direction = ?
                    GROUP BY shape_id
                    ORDER BY COUNT(*) DESC
                    LIMIT 1
                    """
            )
        }
    }
    
    // MARK: Stops
    
    func stop(id: String) async throws -> GTFS.Stop? {
        try await dbQueue.read { db in try GTFS.Stop.fetchOne(db, key: ["stop_id": id]) }
    }
    
    /// Name search for a search box
    func searchStops(matching text: String, limit: Int = 20) async throws -> [GTFS.Stop] {
        try await dbQueue.read { db in
            try GTFS.Stop.fetchAll(
                db,
                sql: """
                    SELECT * FROM stops
                    WHERE location_type IN (0, 1) AND stop_name LIKE :pattern
                    ORDER BY stop_name
                    LIMIT :limit
                    """,
                arguments: ["pattern": "%\(text)%", "limit": limit]
            )
        }
    }
    
    /// Stops near a coordinate, ordered by distance
    func nearbyStops(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 2000,
        limit: Int = 50
    ) async throws -> [(stop: GTFS.Stop, distance: Double)] {
        var lat = latitude
        var lon = longitude

        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            lat = -37.81
            lon = 145.08
        }
        #endif
        
        let dLat = radiusMeters / 111_320
        let dLon = radiusMeters / (111_320 * max(cos(lat * .pi / 180), 0.01))
        
        return try await dbQueue.read { [lat, lon] db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT *
                    FROM (
                        SELECT *,
                            6371000 * 2 * ASIN(
                                SQRT(
                                    MIN(1.0,
                                        MAX(0.0,
                                            POWER(SIN((stop_lat - :lat) * :rad / 2), 2)
                                            + COS(:lat * :rad)
                                            * COS(stop_lat * :rad)
                                            * POWER(SIN((stop_lon - :lon) * :rad / 2), 2)
                                        )
                                    )
                                )
                            ) AS distance
                        FROM stops
                        WHERE location_type IN (0, 1)
                            AND stop_lat BETWEEN :lat - :dLat AND :lat + :dLat
                            AND stop_lon BETWEEN :lon - :dLon AND :lon + :dLon
                    )
                    WHERE distance <= :radius
                    ORDER BY distance
                    LIMIT :limit
                    """,
                arguments: [
                    "lat": lat,
                    "lon": lon,
                    "dLat": dLat,
                    "dLon": dLon,
                    "rad": Double.pi / 180,
                    "radius": radiusMeters,
                    "limit": limit
                ]
            )
            
            return try rows.map { row in
                let stop = try GTFS.Stop(row: row)
                let distance = row["distance"] as Double
                return (stop: stop, distance: distance)
            }
        }
    }
}
