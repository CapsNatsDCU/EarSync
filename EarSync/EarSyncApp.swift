//
//  EarSyncApp.swift
//  EarSync
//
//  Created by Josiah Lenowitz on 3/4/25.
//

import SwiftUI
import SwiftData

@main
struct EarSyncApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
