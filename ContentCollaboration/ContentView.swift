//
//  ContentView.swift
//  ContentCollaboration
//
//  Created by Itsuki on 2025/06/01.
//

import SwiftUI
import CloudKit

struct ContentView: View {

    @State private var shareManager: CloudManager = .shared
    
    var body: some View {

        NavigationStack {

            Group {
                if shareManager.accountStatus != .available {
                    ContentUnavailableView(label: {
                        Label("iCloud Not Available", systemImage: "questionmark.app")
                    }, description: {
                        Text("Please Sign in to your iCloud account!")
                            .multilineTextAlignment(.center)
                    }, actions: {
                        if let settingURL = URL(string: UIApplication.openSettingsURLString) {
                            Button(action: {
                                UIApplication.shared.open(settingURL)
                            }, label: {
                                Text("Settings")
                            })
                        }
                    })
                } else {
                    RecordListView()
                        .environment(shareManager)
                }
            }
            .alert("Oops!", isPresented: $shareManager.showError, actions: {
                Button(action: {
                    shareManager.showError = false
                }, label: {
                    Text("OK")
                })
            }, message: {
                Text("\(shareManager.error?.message ?? "Unknown Error")")
            })
        }
    }
}


#Preview {
    NavigationStack {
        RecordListView()
            .environment(CloudManager.shared)
    }
}
