//
//  UserPreferenceManager.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/30.
//

import SwiftUI
import Combine


extension Notification.Name {
    var publisher: NotificationCenter.Publisher {
        return NotificationCenter.default.publisher(for: self)
    }
}

extension UserPreferenceManager {
    enum _Error: Error {
        case failedToSync
        case quotaExceeded
    }
}


@Observable
@MainActor
class UserPreferenceManager {
    private let intKey = "intPreference"
    
    var error: Error? {
        didSet {
            if let error = self.error {
                print(error)
            }
        }
    }
    
    private(set) var intPreference: Int64 = 0
        
    private var cancellable: AnyCancellable?
    
    private let keyValueStore: NSUbiquitousKeyValueStore = NSUbiquitousKeyValueStore.default

    init() {
        let publisher = NSUbiquitousKeyValueStore.didChangeExternallyNotification.publisher
        
        self.cancellable = publisher.receive(
            on: DispatchQueue.main
        ).sink { notification in
            self.handleNotification(notification)
        }
        
        do {
            try self.synchronize()
        } catch(let error) {
            self.error = error
            return
        }
        
        self.intPreference = self.keyValueStore.longLong(forKey: intKey)
    }
    
    
    private func synchronize() throws {
        let syncResult = self.keyValueStore.synchronize()
        if !syncResult {
            throw UserPreferenceManager._Error.failedToSync
        }
    }
    
    // notification keys: https://developer.apple.com/documentation/foundation/notification-keys
    private func handleNotification(_ notification: Notification) {
        print(#function)
        let userInfo = notification.userInfo ?? [:]
        
        let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber as? Int
        switch reason {
        // NSUbiquitousKeyValueStoreServerChange: https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestoreserverchange
        // A value changed in iCloud. This occurs when another device, running another instance of your app and attached to the same iCloud account, uploads a new value.
        case NSUbiquitousKeyValueStoreServerChange:
            print("Change on the server.")
        
        // NSUbiquitousKeyValueStoreInitialSyncChange: https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestoreinitialsyncchange
        // Your attempt to write to key-value storage was discarded because an initial download from iCloud has not yet happened. That is, before you can first write key-value data, the system must ensure that your app’s local, on-disk cache matches the truth in iCloud.
        // Initial downloads happen the first time a device is connected to an iCloud account, and when a user switches their primary iCloud account.
        case NSUbiquitousKeyValueStoreInitialSyncChange:
            print("Write to key-value storage was discarded. Performing initial download.")
            do {
                try self.synchronize()
            } catch(let error) {
                self.error = error
                return
            }
            
        // NSUbiquitousKeyValueStoreQuotaViolationChange: https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestorequotaviolationchange
        // Your app’s key-value store has exceeded its space quota on the iCloud server
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            print("Quote exceeded.")
            self.error = _Error.quotaExceeded
            
        // NSUbiquitousKeyValueStoreAccountChange: https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestoreaccountchange
        // The user has changed the primary iCloud account. The keys and values in the local key-value store have been replaced with those from the new account, regardless of the relative timestamps.
        case NSUbiquitousKeyValueStoreAccountChange:
            print("Account changed.")
            
        case nil:
            print("reason not specified")
        default:
            print("unknown reason: \(reason ?? -1)")
        }
        
        
        let keysChanged = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
        print("keys changed: \(keysChanged)")
        for key in keysChanged {
            if key == self.intKey {
                self.intPreference = self.keyValueStore.longLong(forKey: intKey)
            }
        }
        
    }
    
    // not use didSet to avoid calling synchronize when it is not user-initiated
    func setIntPreference(_ value: Int64) {
        self.intPreference = value
        self.keyValueStore.set(self.intPreference, forKey: intKey)
        
        // not required to call `synchronize` explicitly unless our app
        // requires fast-as-possible upload to iCloud after you change a value
        do {
            try self.synchronize()
        } catch(let error) {
            self.error = error
        }
    }

}

