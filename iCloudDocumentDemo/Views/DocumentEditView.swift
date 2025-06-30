//
//  DocumentEditView.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/09.
//

import SwiftUI

struct DocumentEditView: View {
    @Environment(DocumentManager.self) private var documentManager
    
    @State private var content: String = ""

    var body: some View {
        if let selectedItem = documentManager.selectedItem {
            VStack {
                TextEditor(text: $content)
                    .lineSpacing(8)
                    .frame(minHeight: 180)
                    .fixedSize(horizontal: false, vertical: true)
                    .textEditorStyle(.plain)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.1), radius: 3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(.yellow.opacity(0.1))
            .onAppear {
                do {
                    self.content = try documentManager.getDocumentContent(selectedItem)
                } catch (let error) {
                    self.documentManager.error = error
                }
            }
            .navigationTitle(selectedItem.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .topBarTrailing, content: {
                    Button(action: {
                        do {
                            try documentManager.updateDocumentContent(selectedItem, content: self.content)
                        } catch (let error) {
                            self.documentManager.error = error
                        }
                    }, label: {
                        Text("Save")
                    })
                })
            })

        }
    }
}

