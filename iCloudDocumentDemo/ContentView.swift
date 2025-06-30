//
//  ContentView.swift
//  iCloudDocumentDemo
//
//  Created by Itsuki on 2025/06/08.
//

import SwiftUI

struct ContentView: View {
    @State private var documentManager = DocumentManager()    
    
    var body: some View {
        NavigationStack {
            Group {
                if documentManager.ubiquityIdentityToken == nil {
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
                    DocumentListView()
                        .environment(documentManager)
                }
            }
            .alert("Oops!", isPresented: $documentManager.showError, actions: {
                Button(action: {
                    documentManager.showError = false
                }, label: {
                    Text("OK")
                })
            }, message: {
                Text(documentManager.error?.message ?? "Unknown Error")
            })
            .disabled(documentManager.processing != nil)
            .overlay(content: {
                if documentManager.processing != nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.gray.opacity(0.3))
                }
            })

        }
    }
}
