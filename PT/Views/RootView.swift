//
//  RootView.swift
//  PT
//
//  Created by Kevin Chen on 16/10/2026.
//

import SwiftUI

struct RootView: View {
    private let gtfs = GTFSDatabase.shared
    
    var body: some View {
        TabView {
            Tab("Tram", systemImage: "tram") {
                NavigationStack { TramView(gtfs: gtfs) }
            }
        }
    }
}
