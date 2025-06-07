//
//  ContentCollaborationApp.swift
//  ContentCollaboration
//
//  Created by Itsuki on 2025/06/01.
//

import SwiftUI

@main
struct ContentCollaborationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
    }
}
