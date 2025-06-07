//
//  Coordinator.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/04.
//

import SwiftUI
import CloudKit

struct _UICloudSharingController: UIViewControllerRepresentable {
    var share: CKShare
    var container: CKContainer
    
    
    var itemTitle: String?
    var onSaveShareFail: ((Error) -> Void)
    var onSaveShareSuccess: (() -> Void)
    var onShareStop: (() -> Void)


    // https://developer.apple.com/documentation/uikit/uicloudsharingcontroller
    typealias UIViewControllerType = UICloudSharingController
    
    func makeUIViewController(context: Context) -> UIViewControllerType {
        let sharingController = UICloudSharingController(share: share, container: container)
        
        sharingController.delegate = context.coordinator        
        return sharingController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        var parent: _UICloudSharingController
        init(_ parent: _UICloudSharingController) {
            self.parent = parent
        }
                
        // Failing to save a share
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: any Error) {
            print("\(#function): \(error)")
            self.parent.onSaveShareFail(error)
        }
        
        
        // When CloudKit successfully shares a topic, it calls this method.
        // At this point, the CKShare object and the whole share hierarchy are up to date on the server side,
        // so fetch the changes and update the local cache.
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            print("\(#function)")
            self.parent.onSaveShareSuccess()
        }
        
        // CloudKit removes the CKShare record and updates the root record on the server side before calling this method,
        // so fetch the changes and update the local cache.
        //
        // Stopping sharing can happen in two scenarios: an owner stops a share, or a participant removes itself from a share.
        // In the former case, no visual changes occur on the owner side (privateDB).
        // In the latter case, the share disappears from the sharedDB.
        // If the share is the only item in the current zone, CloudKit removes the zone as well.
        //
        // Fetching immediately here may not get all the changes because the server side needs a while to index.
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            print(#function)
            self.parent.onShareStop()
        }
        
        
        // Asks the delegate for the title to display on the invitation screen.
        func itemTitle(for csc: UICloudSharingController) -> String? {
            return self.parent.itemTitle
        }
        
    }
}
