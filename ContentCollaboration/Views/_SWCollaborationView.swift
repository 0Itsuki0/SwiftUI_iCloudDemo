//
//  _SWCollaborationView.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/04.
//

import SwiftUI
import SharedWithYou
import CloudKit

struct _SWCollaborationView: UIViewRepresentable {
    var share: CKShare
    var container: CKContainer
    
    @Binding var showSharingController: Bool

    // https://developer.apple.com/documentation/sharedwithyou/swcollaborationview
    func makeUIView(context: Context) -> SWCollaborationView {

        let itemProvider = NSItemProvider()
        // registerCKShare(container:allowedSharingOptions:preparationHandler:) will not show the "Manage Share" button correctly
        itemProvider.registerCKShare(share, container: container, allowedSharingOptions: CloudManager.sharingOption)
        
        let collaborationView = SWCollaborationView(itemProvider: itemProvider)
            
        collaborationView.setShowManageButton(false)
        collaborationView.setDetailViewListContent({
            Button(action: {
                showSharingController = true
            }, label: {
                HStack {
                    Text("Manage Share")
                        .foregroundStyle(.foreground)
                    Spacer()
                    
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(.link)
                }
            })
        })
                
        return collaborationView
    }
    
    func updateUIView(_ uiView: SWCollaborationView, context: Context) {}
}
