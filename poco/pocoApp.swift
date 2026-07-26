//
//  pocoApp.swift
//  poco
//
//  Created by 茂木史明 on 2026/07/26.
//

import SwiftUI

@main
struct PocoApp: App {
    @State private var store = PocoStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .tint(PocoTheme.primary)
        }
    }
}
