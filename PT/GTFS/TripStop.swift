//
//  TripStop.swift
//  PT
//
//  Created by Kevin Chen on 25/10/2026.
//

import GRDB
import Foundation

nonisolated extension GTFSDatabase {
    func tripStops(tripId: String) async throws -> [TripStop] {
        try await dbQueue.read { db in
            try TripStop.fetchAll(
                db,
                sql: """
                    SELECT st.stop_id, s.stop_name, st.stop_sequence,
                           st.arrival_time, st.departure_time
                    FROM stop_times st
                    JOIN stops s ON s.stop_id = st.stop_id
                    WHERE st.trip_id = ?
                    ORDER BY st.stop_sequence
                    """,
                arguments: [tripId]
            )
        }
    }
}
