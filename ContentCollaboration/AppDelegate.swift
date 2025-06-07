//
//  AppDelegate.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/01.
//

import SwiftUI
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    // to initialize the records on launch
    let manager = CloudManager.shared
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        application.registerForRemoteNotifications()
        Task {
            do {
                try await manager.addSharedDatabaseSubscription()
            } catch(let error) {
                print("error adding database subscription: \(error)")
                manager.error = error
            }
        }
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting
        connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil,
            sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
    
    
    // didReceiveRemoteNotification do not trigger correctly on simulators
    @MainActor
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {
        print("\(#function)")
        
        // we are not interested in processing if our app is not active
        if application.applicationState != .active {
            print("not active")
            return .newData
        }
                
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return .noData
        }
        
        print(notification)
        
        if notification.notificationType == .database, notification.subscriptionID == CloudManager.sharedCloudDatabaseSubscriptionId {
            Task {
                do {
                    try await manager.fetchChangesForSharedDBSubscription()
                } catch(let error) {
                    print("error fetching changes for shared database subscription: \(error)")
                    manager.error = error
                }

            }
        }
        
        if notification.notificationType == .query, notification.subscriptionID == CloudManager.privateDatabaseQuerySubscriptionId, let queryNotification = notification as? CKQueryNotification {
           
            Task {
                do {
                    try await manager.fetchChangesForQuerySubscription(queryNotification)
                } catch(let error) {
                    print("error fetching changes for query subscription: \(error)")
                    manager.error = error
                }

            }
        }
                
        return .newData
    }
    
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("\(#function). Device token: \(deviceToken.base64EncodedString())")
    }

    // Report the error if the app fails to register for remote notifications.
    //
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("\(#function). \(error))")
    }


    
    // will not be called even if we don't add/use a SceneDelegate 
//    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
//        print("application: userDidAcceptCloudKitShareWith: \(cloudKitShareMetadata)")
//    }

}
