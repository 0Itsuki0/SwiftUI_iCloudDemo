//
//  ContentView.swift
//  SwiftDataSync
//
//  Created by Itsuki on 2025/05/30.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoModel.lastUpdated, order: .reverse, animation: .smooth) private var memos: [MemoModel]
    
    @State private var searchQuery: String = ""
    
    var body: some View {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredMemos = query.isEmpty ? memos : memos.filter({
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.content.localizedCaseInsensitiveContains(query)
        })
        

        List {
            ForEach(filteredMemos) { memo in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(memo.title)
                                .font(.headline)
                                .fontWeight(.semibold)

                            if memo.isImportant {
                                Image(systemName: "star.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16)
                                    .foregroundStyle(.yellow.mix(with: .gray, by: 0.05))
                            }
                        }
                        
                        Text(memo.lastUpdated, format: .dateTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(memo.content)
                            .font(.subheadline)
                            .lineLimit(2)
                    }

                    Spacer()
                    
                    Button(action: {
                        modelContext.delete(memo)
                    }, label: {
                        Image(systemName: "trash")
                    })
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                }

            }
        }
        .contentMargins(.top, 16)
        .environment(\.defaultMinListRowHeight, 64)
        .navigationTitle("Memos")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing, content: {
                Button(action: {
                    self.addMemo()
                }, label: {
                    Image(systemName: "square.and.pencil")
                })

            })
        })
        .overlay(content: {
            if filteredMemos.isEmpty && !query.isEmpty {
                ContentUnavailableView("No Results for \"\(query)\"", systemImage: "magnifyingglass")
            } else if self.memos.isEmpty {
                ContentUnavailableView("No Memos", systemImage: "rectangle.fill.on.rectangle.fill")
            }
        })
    }
    
    
    private func addMemo() {
        let memo = MemoModel(title: "Title \(memos.count + 1)", content: "Some content for memo \(memos.count + 1)", lastUpdated: Date(), isImportant: [0, 1].randomElement() ?? 0 == 1 )
        modelContext.insert(memo)
    }
    
    
}

#Preview {
    NavigationStack {
        ContentView()
            .modelContainer(for: [MemoModel.self], inMemory: true)
    }
}
