//
//  SceneDelegate.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/01.
//

import SwiftUI
import CloudKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    let manager = CloudManager.shared
    
    // For a scene-based iOS app in a running or suspended state, CloudKit calls the windowScene(_:userDidAcceptCloudKitShareWith:) method on your window scene delegate.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        print("scene userDidAcceptCloudKitShareWith: \(cloudKitShareMetadata)")
        Task {
            do {
                try await manager.shareAccepted(cloudKitShareMetadata)
            } catch(let error) {
                print("error accepting share: \(error)")
                manager.error = error
            }
        }
    }
    
    
    // For a scene-based iOS app that’s not running, the system launches your app in response to the tap or click, and calls the scene(_:willConnectTo:options:) method on your scene delegate. The connectionOptions parameter contains the metadata. Use its cloudKitShareMetadata property to access it.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shareMetadata = connectionOptions.cloudKitShareMetadata {
            print("scene willConnectTo: \(shareMetadata)")
            Task {
                do {
                    try await manager.shareAccepted(shareMetadata)
                } catch(let error) {
                    print("error accepting share: \(error)")
                    manager.error = error
                }
            }
        }
    }
    
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("\(#function)")
        Task {
            do {
                try await manager.refreshAllRecords()
            } catch(let error) {
                print("error initializeAllRecords: \(error)")
                manager.error = error
            }
        }
    }

}
