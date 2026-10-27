//
//  Types.swift
//  PT
//
//  Created by Kevin Chen on 28/10/2026.
//

import Foundation

enum BackendResp {
    struct Trip: Decodable, Identifiable {
        let tripInfo: TripInformation
        let tripId: String
        let stopId: String
        let arrival: StopTimeEvent?
        let departure: StopTimeEvent?

        var id: String {
            tripId
        }
    }

    struct TripInformation: Decodable {
        let routeType: String
        let routeId: String
        let timetableType: String
    }

    struct StopTimeEvent: Decodable {
        let delay: Int
        let time: Int64
    }

}
