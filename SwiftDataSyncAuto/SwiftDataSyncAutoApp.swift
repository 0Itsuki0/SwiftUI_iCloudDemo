//
//  SwiftDataSyncAutoApp.swift
//  SwiftDataSync
//
//  Created by Itsuki on 2025/05/30.
//

import SwiftUI
import SwiftData

@main
struct SwiftDataSyncAutoApp: App {
    
    var modelContainer: ModelContainer = {
        let schema = Schema([MemoModel.self])
        let modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: modelConfiguration)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
        .modelContainer(modelContainer)
    }
}
