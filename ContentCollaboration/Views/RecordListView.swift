//
//  RecordListView.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/04.
//

import SwiftUI
import CloudKit

struct RecordListView: View {
    @Environment(CloudManager.self) var shareManager
    
    var body: some View {
        @Bindable var shareManager = shareManager
        
        List {
            Section("My Notes") {
                
                if shareManager.myRecords.isEmpty {
                    Group {
                        if shareManager.loadingMyRecord {
                            progressView()
                        } else {
                            Text("(No notes yet...)")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                
                // reason for not using id: \.recordID:
                // view update will not be triggered in title/content change
                ForEach(0..<shareManager.myRecords.count, id: \.self) { index in
                    let record = shareManager.myRecords[index]
                    self.cellView(record)
                }
            }
            
            if shareManager.myRecordCursor != nil {
                Section {
                    loadMoreButton(action: shareManager.loadMyRecords)
                }
            }
            
            Section("Shared with me") {
                if shareManager.sharedWithMe.isEmpty {
                    Group {
                        if shareManager.loadingSharedWithMe {
                            progressView()
                        } else {
                            Text("(Nothing shared with me...)")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                // reason for not using id: \.recordID:
                // view update will not be triggered in title/content change
                ForEach(0..<shareManager.sharedWithMe.count, id: \.self) { index in
                    let record = shareManager.sharedWithMe[index]
                    self.cellView(record)
                }
                
            }
            
            
            if shareManager.sharedWithMeCursor != nil {
                Section {
                    loadMoreButton(action: shareManager.loadSharedWithMeRecords)
                }
            }

        }
        .buttonStyle(.plain)
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing, content: {
                Button(action: {
                    Task {
                        let _ = try? await shareManager.createNewCKRecord()
                    }
                }, label: {
                    Image(systemName: "square.and.pencil")
                })
                .disabled(shareManager.loadingMyRecord || shareManager.loadingSharedWithMe)
            })

            
            ToolbarItem(placement: .topBarTrailing, content: {
                Button(action: {
                    Task {
                        let _ = try? await shareManager.refreshAllRecords()
                    }
                }, label: {
                    Image(systemName: "arrow.trianglehead.clockwise")
                })
                .disabled(shareManager.loadingMyRecord || shareManager.loadingSharedWithMe)
            })
        })
        .navigationTitle("All Notes")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $shareManager.displayRecord, destination: { record in
            RecordDetailView()
                .environment(shareManager)
        })
        
//        .onAppear {
//            let record: CKRecord = .init(recordType: "SharedNote")
//
//            record.setValuesForKeys([
//                ShareManager.titleKey: "(Untitled)",
//                ShareManager.contentKey: ""
//            ])
//
//            shareManager.myRecords.append(record)
//            shareManager.share = .init(rootRecord: record)
//            shareManager.displayRecord = record
//        }
    }
    
    private func progressView() -> some View {
        ProgressView("Loading...")
            .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func loadMoreButton(action: @escaping () async throws -> Void) -> some View {
        Button(action: {
            Task {
                try?  await action()
            }
        }, label: {
            Text("Load more...")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
        })
        .buttonStyle(.borderless)
        .font(.headline)
        .opacity(0.9)
    }
    
    
    private func cellView(_ record: CKRecord) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                shareManager.setDisplayRecordAndUpdateTitleContent(record)
            }, label: {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.title)
                        .font(.headline)
                    
                    Group {
                        if record.content.isEmpty {
                            Text("(Nothing added yet!)")
                        } else {
                            Text(record.content)
                        }
                    }
                    .font(.subheadline)
                    .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            })
                   
            Spacer()

            if record.isOwner {
                Button(action: {
                    Task {
                        do {
                            try await shareManager.deleteCKRecord(record.recordID)
                        } catch(let error) {
                            print("error deleting record: \(error)")
                            shareManager.error = error
                        }
                    }
                }, label: {
                    Image(systemName: "trash.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32)
                        .contentShape(Circle())
                })
                .fontWeight(.semibold)
                .foregroundStyle(.red.opacity(0.9))
            }
            
        }
        .contentShape(Rectangle())

    }
}
