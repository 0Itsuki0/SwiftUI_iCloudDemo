//
//  DocumentListView.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/09.
//

import SwiftUI

struct DocumentListView: View {
    @Environment(DocumentManager.self) private var documentManager
    
    @State private var showNewDocumentDialog: Bool = false
    @State private var newDocumentNameEntry: String = ""

    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter
    }
    
    var body: some View {
        @Bindable var documentManager = documentManager
        
        List {
            if documentManager.metadataItems.isEmpty {
                Group {
                    if documentManager.containerRootURL == nil {
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("(No documents...)")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            ForEach(0..<documentManager.metadataItems.count, id: \.self) {
                index in
                let item: MetadataItem = self.documentManager.metadataItems[index]
                
                cellView(item)
            }
        }
        .buttonStyle(.plain)
        .navigationTitle("All Documents")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing, content: {
                Button(action: {
                    self.showNewDocumentDialog = true
                }, label: {
                    Image(systemName: "square.and.pencil")
                })
            })
            
            ToolbarItem(placement: .topBarTrailing, content: {
                Button(action: {
                    documentManager.reloadAllDocuments()
                }, label: {
                    Image(systemName: "arrow.trianglehead.clockwise")
                })
            })
        })
        .alert("New Document", isPresented: $showNewDocumentDialog) {
            TextField("", text: $newDocumentNameEntry)

            Button(action: {
                self.showNewDocumentDialog = false
            }, label: {
                Text("Cancel")
            })
            
            Button(action: {
                do {
                    try documentManager.createDocument(self.newDocumentNameEntry)
                    self.newDocumentNameEntry = ""
                    self.showNewDocumentDialog = false
                } catch (let error) {
                    documentManager.error = error
                }
            }, label: {
                Text("OK")
            })
            
        } message: {
            Text("Enter a unique name for the new document.")
        }
        .navigationDestination(item: $documentManager.selectedItem, destination: { record in
            DocumentEditView()
                .environment(documentManager)
        })
    
    }
    
    private func cellView(_ item: MetadataItem) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                documentManager.selectedItem = item
            }, label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.displayName)
                        .font(.headline)
                    
                    if let lastUpdated = item.lastUpdated {
                        Text(formattedDate(lastUpdated))
                            .font(.subheadline)
                            .lineLimit(2)

                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            })
            .foregroundStyle(.foreground)
                   
            Spacer()

            Button(action: {
                Task {
                    do {
                        try documentManager.deleteDocument(item)
                    } catch(let error) {
                        print("error deleting document: \(error)")
                        documentManager.error = error
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
        .contentShape(Rectangle())
    }
    
    
    private func formattedDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
}
