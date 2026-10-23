//
//  RootView.swift
//  PT
//
//  Created by Kevin Chen on 16/10/2026.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Tram", systemImage: "tram") {
                NavigationStack { TramView() }
            }
        }
    }
}

#Preview {
    RootView()
}
