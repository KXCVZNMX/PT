//
//  TramStopView.swift
//  PT
//
//  Created by Kevin Chen on 27/10/2026.
//

import SwiftUI
import Foundation

struct TramStopView: View {
    let stop: GTFS.Stop
    let distance: Double
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var arrivals: [BackendResp.Trip] = []
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Finding incoming routes...")
            }
            
            ForEach(arrivals, ) {arrival in
                List {
                    Text(arrival.tripId)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(formatStopName(stop.stopName))
            }
        }
        .task {
            await loadArrivals()
        }
    }
    
    private func loadArrivals() async {
        isLoading = true
        defer { isLoading = false }

        do {
            arrivals = try await fetchStopArrivals(stopID: stop.stopId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func fetchStopArrivals(stopID: String) async throws -> [BackendResp.Trip] {
        var components = URLComponents(
            string: "https://pt.kvznmx.com/api/trams/stop_arrivals"
        )!

        components.queryItems = [
            URLQueryItem(name: "stop_id", value: stopID)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([BackendResp.Trip].self, from: data)
    }
    
    private func formatStopName(_ stopName: String?) -> String {
        let name = stopName ?? "Unknown stop"
        let formatted = name.split(separator: "/", maxSplits: 1)
            .first.map(String.init) ?? name

        if formatted.count > 27 {
            return String(formatted.prefix(25)) + "..."
        }

        return formatted
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
