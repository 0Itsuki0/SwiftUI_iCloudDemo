//
//  SwiftDataSyncApp.swift
//  SwiftDataSync
//
//  Created by Itsuki on 2025/05/30.
//

import SwiftUI
import SwiftData

@main
struct SwiftDataSyncApp: App {
    
    var modelContainer: ModelContainer = {
        let schema = Schema([MemoModel.self])
        let modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.itsuki.enjoy.iCloudDemo"))
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
