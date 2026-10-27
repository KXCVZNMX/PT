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
    
    @State private var stops: [(stop: GTFS.Stop, distance: Double)] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var routesByStopId: [
        String: [(routeType: String, routeId: String, direction: String?)]
    ] = [:]
    
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Finding nearby stops...")
            }

            if let errorMessage {
                ContentUnavailableView(
                    "Unable to Load Stops",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            }
            
            List {
                ForEach(stops, id: \.stop.stopId) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(formatStopName(result.stop.stopName))
                                .font(.headline)

                            Spacer()
                            
                            Text("\(Int(result.distance.rounded())) m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        let routes = routesByStopId[result.stop.stopId] ?? []

                        if routes.count == 2 {
                            Text("Terminus")
                                .font(.subheadline)
                        } else if let route = routes.first {
                            Text(
                                "\(route.routeId) — \(route.direction ?? "Unknown direction")"
                            )
                            .font(.subheadline)
                        } else {
                            // Should never happen
                            Text("No routes found")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Tram")
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
    
    @MainActor
    private func loadStops() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard let location = locationManager.location else { return }
        
        let nearbyStops = try await gtfs.nearbyStops(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        routesByStopId = try await gtfs.routes(
            atStops: nearbyStops.map(\.stop.stopId)
        )

        stops = nearbyStops
    }
    
    private func formatStopName(_ stopName: String?) -> String {
        let stopName = stopName ?? "Unknown stop"
        
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

        if formatted.count > 30 {
            return String(formatted.prefix(28)) + "..."
        }

        return formatted
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
