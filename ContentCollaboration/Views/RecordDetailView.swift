//
//  RecordDetailView.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/04.
//

import SwiftUI
import CloudKit

struct RecordDetailView: View {

    @Environment(CloudManager.self) var shareManager
    
    @State private var showSharingController: Bool = false

    var body: some View {
        @Bindable var shareManager = shareManager

        VStack(spacing: 24) {
            if let displayRecord = shareManager.displayRecord,
                let share = shareManager.share,
                let lastModified = displayRecord.lastModifiedDateString {
                Group {
                    if let userName = displayRecord.lastModifiedUserName(share)  {
                        Text("Last modified:\n\(lastModified) by \(userName)")
                    } else {
                        Text("Last modified:\n\(lastModified)")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.trailing)
                .padding(.leading, 48)
                .frame(maxWidth: .infinity, alignment: .trailing)

            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .fontWeight(.semibold)
                    .font(.title3)
                
                TextField("", text: $shareManager.title)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(.gray))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Content")
                    .fontWeight(.semibold)
                    .font(.title3)
                
                TextField("", text: $shareManager.content, axis: .vertical)
                    .lineLimit(3...)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(.gray))
            }
             
        }
        .navigationTitle("Some Note")
        .navigationBarTitleDisplayMode(.inline)
        .padding(.all, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing, content: {
                if let share = self.shareManager.share {
                    _SWCollaborationView(share: share, container: self.shareManager.container, showSharingController: $showSharingController)
                        .frame(width: 36, height: 36) //setting frame is required to have it actually be clickable, otherwise the frame will be zero when placed on tool bar
                        .sheet(isPresented: $showSharingController, content: {
                            _UICloudSharingController(
                                share: share,
                                container: self.shareManager.container,
                                itemTitle: "Collaboration Time!",
                                onSaveShareFail: { error in
                                    print("save share failed: \(error)")
                                    shareManager.error = error
                                },
                                onSaveShareSuccess: {
                                    Task {
                                        do {
                                            try await shareManager.cloudSharingControllerDidSaveShare()
                                        } catch(let error) {
                                            print("shareManager.cloudSharingControllerDidSaveShare error: \(error)")
                                            shareManager.error = error
                                        }
                                    }
                                },
                                onShareStop:  {
                                    Task {
                                        do {
                                            try await shareManager.cloudSharingControllerDidStopSharing()
                                        } catch(let error) {
                                            print("shareManager.cloudSharingControllerDidStopSharing error: \(error)")
                                            shareManager.error = error
                                        }
                                    }
                                }
                            )
                            .ignoresSafeArea()
                        })
                }
            })
            
            ToolbarItem(placement: .topBarTrailing, content: {
                ShareLink(item: self.shareManager.sharedNoteTransferable, preview: SharePreview(self.shareManager.title, image: Image(systemName: "square.and.pencil")))
            })
                
        })
    }
}
