//
//  ContentView.swift
//  proditon
//
//  Created by Work on 23/12/2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var resultsManager = ResultsManager.shared
    
    var body: some View {
        TabView {
            TryOnView()
                .tabItem {
                    Label("Try On", systemImage: "tshirt.fill")
                }
            
            ResultsView()
                .tabItem {
                    Label("Results", systemImage: "photo.stack.fill")
                }
            
            WardrobeView()
                .tabItem {
                    Label("Wardrobe", systemImage: "hanger")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environmentObject(resultsManager)
    }
}

#Preview {
    ContentView()
        .previewDevice(PreviewDevice(rawValue: "iPhone 14 Pro"))
        .previewDisplayName("iPhone 14 Pro")
}
