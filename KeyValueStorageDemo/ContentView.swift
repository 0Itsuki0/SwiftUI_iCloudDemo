//
//  ContentView.swift
//  KeyValueStorageDemo
//
//  Created by Itsuki on 2025/06/30.
//

import SwiftUI

struct ContentView: View {
    @State private var manager = UserPreferenceManager()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("Itsuki's Favorite Integer")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("\(manager.intPreference)")
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(width: 240, height: 120)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.green.opacity(0.3)))
                
                Button(action: {
                    manager.setIntPreference(Int64.random(in: 0..<100))
                }, label: {
                    Text("New Integer")
                        .font(.title3)
                })

            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(.yellow.opacity(0.1))
            .navigationTitle("iCloud Demo")
            .navigationSubtitle("Key-Value Storage")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    ContentView()
}

