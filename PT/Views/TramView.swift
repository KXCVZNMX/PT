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
    
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        VStack {
            List {
                ForEach(stops, id: \.stopId) { stop in
                    Text(stop.stopName)
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
        
        stops = try await gtfs.nearbyStops(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
