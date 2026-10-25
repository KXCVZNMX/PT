//
//  TramView.swift
//  PT
//
//  Created by Kevin Chen on 16/10/2026.
//

import SwiftUI
import CoreLocation

struct TramView: View {
    let gtfs: GTFSDatabase
    
    @State private var stops: [GTFS.Stop] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var routesByStopId: [
        String: [(routeType: String, routeId: String, direction: String?)]
    ] = [:]
    
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        VStack {
            List {
                ForEach(stops, id: \.stopId) { stop in
                    VStack(alignment: .leading) {
                        Text(formatStopName(stop.stopName))

                        let routes = routesByStopId[stop.stopId] ?? []

                        if routes.count == 2 {
                            Text("Terminus")
                                .font(.subheadline)
                        } else {
                            Text("\(routes[0].routeId) — \(routes[0].direction ?? "Unknown direction")")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle(Text("Tram"))
        .task {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.location) { _, location in
            guard location != nil else { return }

            Task {
                do {
                    try await loadStops()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func loadStops() async throws {
        isLoading = true
        defer { isLoading = false }
        
        guard let location = locationManager.location else { return }
        
        let nearbyStops = try await gtfs.nearbyStops(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        routesByStopId = try await gtfs.routes(
            atStops: nearbyStops.map(\.stopId)
        )

        stops = nearbyStops
    }
    
    private func formatStopName(_ stopName: String) -> String {
        let formatted: String

        if let range = stopName.range(
            of: #"\s+#(\d+)$"#,
            options: .regularExpression
        ) {
            let name = stopName[..<range.lowerBound]
            let number = stopName[range].drop { !$0.isNumber }
            formatted = "\(number): \(name)"
        } else {
            formatted = stopName
        }

        if formatted.count > 28 {
            return String(formatted.prefix(25)) + "..."
        }

        return formatted
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
