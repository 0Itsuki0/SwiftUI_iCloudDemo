//
//  ShareManager.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/01.
//

import SwiftUI
import CloudKit

public final class Constants {
    static let titleKey: String = "title"
    static let contentKey: String = "content"
}

// MARK: static variables
extension CloudManager {
    
    // this option is not the initial option that shows up, but whether if the user can configure the options
    // The share sheet uses the registered CKAllowedSharingOptions object to let the user choose between the allowed options when sharing
    // https://developer.apple.com/documentation/cloudkit/ckallowedsharingoptions
    static let sharingOption: CKAllowedSharingOptions = .init(allowedParticipantPermissionOptions: .any, allowedParticipantAccessOptions: .any)

    private static let zoneName: String = "SharedNoteZone"
    private static let containerIdentifier: String = "iCloud.itsuki.enjoy.iCloudDemo"
    private static let recordType: String = "SharedNote"
    private static let queryLimit: Int = CKQueryOperation.maximumResults
    
    static let privateDatabaseQuerySubscriptionId: String = "privateCloudDatabaseSubscription_\(recordType)"
    static let sharedCloudDatabaseSubscriptionId: String = "sharedCloudDatabaseSubscription_\(recordType)"

}


extension Error {
    var message: String {
        if let _error = self as? CloudManager._Error {
            switch _error {
            case .failedToCreateShare(let error):
                return error == nil ? "Unknown error" : error!.localizedDescription
            case .iCloudAccountUnavailable:
                return "iCloud account unavailable."
            case .noRecordSelectedForShare:
                return "No record selected for sharing."
            case .rootRecordNotFoundForShare:
                return "Root record not found for sharing."
            }
        }
        
        return self.localizedDescription
    }
}


@Observable
@MainActor
class CloudManager {
    static let shared: CloudManager = .init()
    
    init() {
        Task {
            do {
                try await self.checkAccountStatus()
            } catch (let error) {
                print("error: \(error)")
                self.error = error
            }
        }
    }
    
    var error: (any Error)? = nil {
        didSet {
            if error != nil {
                showError = true
            }
        }
    }
    
    var showError: Bool = false {
        didSet {
            if !showError {
                self.error = nil
            }
        }
    }
    
    var accountStatus: CKAccountStatus = .couldNotDetermine
    
    // CKContainer: https://developer.apple.com/documentation/cloudkit/ckcontainer
    let container = CKContainer(identifier: CloudManager.containerIdentifier)
    // CKContainer.default() will use iCloud.<bundleId> as identifier
    
    // shared records are also saved in the privateCloudDatabase, within a custom record zone
    private var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }
    private var privateZone: CKRecordZone?
    
    private var sharedCloudDatabase: CKDatabase {
        container.sharedCloudDatabase
    }
    private var sharedZone: CKRecordZone?
    private var sharedDatabaseChangeToken: CKServerChangeToken?

    
    
    var displayRecord: CKRecord? {
        didSet {
            if let displayRecord = self.displayRecord {
                
                // remove the previous query subscription and add new one.
                if displayRecord.recordID != oldValue?.recordID {
                    Task {
                        do {
                            try await self.removeQuerySubscriptions()
                            try await self.addQuerySubscription()
                        } catch(let error) {
                            print("error adding addQuerySubscription subscription: \(error)")
                            self.error = error
                        }
                    }
                }
                
                if displayRecord.share != oldValue?.share {
                    self.share = nil
                    
                    // share already exist
                    if displayRecord.share != nil {
                        Task {
                            do {
                                let _ = try await self.getCKShare()
                            } catch (let error) {
                                print("error getting share: \(error)")
                                self.error = error
                            }
                        }
                    }
                }
            }
            
            // only update the lists when navigating back to the root view in case any updates
            if self.displayRecord == nil, let previousSelected = oldValue {
                self.share = nil
                
                if previousSelected.isOwner {
                    self.myRecords.removeAll(where: { $0.recordID == previousSelected.recordID })
                    self.myRecords.insert(previousSelected, at: 0)
                } else {
                    self.sharedWithMe.removeAll(where: { $0.recordID == previousSelected.recordID })
                    self.sharedWithMe.insert(previousSelected, at: 0)
                }
                
                Task {
                    do {
                        try await self.removeQuerySubscriptions()
                    } catch (let error) {
                        print("error removeQuerySubscriptions: \(error)")
                        self.error = error
                    }
                }
            }
        }
    }
    
    // share for the displayRecord
    var share: CKShare?
    
    
    var sharedWithMe: [CKRecord] = []
    var sharedWithMeCursor: CKQueryOperation.Cursor?
    var loadingSharedWithMe: Bool = false
    
    var myRecords: [CKRecord] = []
    var myRecordCursor: CKQueryOperation.Cursor?
    var loadingMyRecord: Bool = false
    
    
    var title: String  = "(Untitled)" {
        didSet {
            guard oldValue != self.title, self.title != displayRecord?.title else {
                return
            }
            Task {
                do {
                    try await self.updateCKRecord()
                } catch(let error) {
                    print("error updating CKRecord: \(error)")
                    self.error = error
                }
            }
        }
    }
    
    var content: String = ""  {
        didSet {
            guard oldValue != self.content, self.content != displayRecord?.content  else {
                return
            }
            Task {
                do {
                    try await self.updateCKRecord()
                } catch(let error) {
                    print("error updating CKRecord: \(error)")
                    self.error = error
                }
            }
        }
    }
    
    // trying to update too frequently may cause error
    // only updating if the current update finish
    private var isUpdating: Bool = false {
        didSet {
            if !self.isUpdating, pendingUpdates {
                print("update pending update ")
                Task {
                    do {
                        try await self.updateCKRecord()
                    } catch(let error) {
                        print("error updating CKRecord: \(error)")
                        self.error = error
                    }
                }
            }
        }
    }
    
    private var pendingUpdates: Bool = false
    
    
    
    // called when user refresh using the UI, as well as sceneWillEnterForeground
    func refreshAllRecords() async throws {
        self.myRecords = []
        self.sharedWithMe = []
        self.myRecordCursor = nil
        self.sharedWithMeCursor = nil
        
        try await checkAccountStatus()
        
        Task {
            try await loadMyRecords()
        }
        
        Task {
            // use to fetchChangesForSharedDBSubscription instead of loadSharedWithMeRecords directly to also initialize server change token at the same time
            self.sharedDatabaseChangeToken = nil
            try await fetchChangesForSharedDBSubscription()
        }
        
        Task {
            try await refreshDisplayedRecord()
        }
    }
    
    
    func refreshDisplayedRecord() async throws {
        
        guard let displayRecord else { return }
        
        let database = displayRecord.isOwner ? self.privateDatabase : self.sharedCloudDatabase
        
        let record = try await database.record(for: displayRecord.recordID)
        
        if record.isOwner {
            if let currentIndex = self.myRecords.firstIndex(where: {$0.recordID == record.recordID }) {
                self.myRecords[currentIndex] = record
            } else {
                self.myRecords.insert(record, at: 0)
            }
        } else {
            if let currentIndex = self.sharedWithMe.firstIndex(where: {$0.recordID == record.recordID }) {
                self.sharedWithMe[currentIndex] = record
            } else {
                self.sharedWithMe.insert(record, at: 0)
            }
        }
        
        self.setDisplayRecordAndUpdateTitleContent(record)
    }
    
    
    func loadMyRecords() async throws{
        self.loadingMyRecord = true
        defer {
            self.loadingMyRecord = false
            print("myRecords: \(myRecords.count)")
        }
        
        
        // CKQuery: https://developer.apple.com/documentation/cloudkit/ckquery
        // predicate rules: https://developer.apple.com/documentation/cloudkit/ckquery#Predicate-Rules-for-Query-Objects
        // To retrieve all records of a specific type, use the TRUEPREDICATE expression.
        let predicate = NSPredicate(format: "TRUEPREDICATE")
        
        let privateZone = try await self.getPrivateZone()
        let myRecordResults = if let cursor = self.myRecordCursor {
            try await privateDatabase.records(continuingMatchFrom: cursor, resultsLimit: CloudManager.queryLimit)
        } else {
            try await privateDatabase.records(matching: .init(recordType: CloudManager.recordType, predicate: predicate), inZoneWith: privateZone.zoneID, resultsLimit: CloudManager.queryLimit)
        }
        
        var myRecords: [CKRecord] = []
        for result in myRecordResults.matchResults {
            if case .success(let record) = result.1 {
                // check if it is created by the current user to is shared
                myRecords.append(record)
            }
        }
        
        if self.myRecordCursor == nil {
            self.myRecords = myRecords
        } else {
            self.myRecords.append(contentsOf: myRecords)
        }
        
        self.myRecordCursor = myRecordResults.queryCursor
        
        return
        
    }
    
    
    func loadSharedWithMeRecords() async throws {
        self.loadingSharedWithMe = true
        defer {
            self.loadingSharedWithMe = false
            print("sharedWithMe: \(sharedWithMe.count)")
        }
        
        var sharedWithMe: [CKRecord] = []
        
        guard let sharedZone = try await self.getSharedZone() else {
            self.sharedWithMe = sharedWithMe
            return
        }
        
        let predicate = NSPredicate(format: "TRUEPREDICATE")
        
        // Queries invoked within a `sharedCloudDatabase` must specify a `zoneID`; cross-zone queries are not supported in a `sharedCloudDatabase
        let sharedWithMeResults = if let cursor = self.sharedWithMeCursor {
            try await sharedCloudDatabase.records(continuingMatchFrom: cursor, resultsLimit: CloudManager.queryLimit)
        } else {
            // Queries invoked within a `sharedCloudDatabase` must specify a `zoneID`
            try await sharedCloudDatabase.records(matching: .init(recordType: CloudManager.recordType, predicate: predicate), inZoneWith: sharedZone.zoneID, resultsLimit: CloudManager.queryLimit)
        }
        
        for result in sharedWithMeResults.matchResults {
            if case .success(let record) = result.1 {
                sharedWithMe.append(record)
            }
        }
        
        if self.sharedWithMeCursor == nil {
            self.sharedWithMe = sharedWithMe
        } else {
            self.sharedWithMe.append(contentsOf: sharedWithMe)
        }
        
        self.sharedWithMeCursor = sharedWithMeResults.queryCursor
        
        return
    }
    
    
    func createNewCKRecord() async throws -> CKRecord {
        
        let zone = try await self.getPrivateZone()
        
        // CKRecord: https://developer.apple.com/documentation/cloudkit/ckrecord
        //
        // When creating records, explicitly specify the zone ID if you want the records to reside in a specific zone; otherwise, they save to the default zone.
        // CKRecord(recordType:, zoneID:): Deprecated. Use init(recordType:recordID:) + CKRecord.ID(zoneID:) instead
        //
        // When we run your app, it adds that record type to the schema and saves the record. If the record type already exists in the schema, iCloud uses the existing type. Saving a record works only if the user has signed into their iCloud account on their device.
        // Designing and Creating a CloudKit Database: https://developer.apple.com/documentation/cloudkit/designing-and-creating-a-cloudkit-database#Handle-or-prevent-errors-gracefully
        let record: CKRecord = .init(recordType: CloudManager.recordType, recordID: .init(zoneID: zone.zoneID))
        
        record.setValuesForKeys([
            Constants.titleKey: "(Untitled)",
            Constants.contentKey: ""
        ])
        
        let savedRecord = try await self.privateDatabase.save(record)
        self.myRecords.insert(savedRecord, at: 0)
        self.setDisplayRecordAndUpdateTitleContent(savedRecord)
        
        return savedRecord
    }
    
    // trying to update too frequently may cause error
    // only updating if the current update finish
    private func updateCKRecord() async throws {
        guard let record = self.displayRecord else {return}
        guard !self.isUpdating else {
            pendingUpdates = true
            return
        }
        
        self.isUpdating = true
        
        defer {
            isUpdating = false
            pendingUpdates = false
        }
        
        record.setValuesForKeys([
            Constants.titleKey: self.title,
            Constants.contentKey: self.content
        ])
        
        let database = record.isOwner ? self.privateDatabase : self.sharedCloudDatabase
        do {
            let saved = try await database.save(record)
            self.displayRecord = saved
        } catch (let error) {
            // fetch the newest version and retry the update
            if let error = error as? CKError, error.code == .serverRecordChanged {
                print("serverRecordChanged: retry")
                let record = try await database.record(for: record.recordID)
                self.displayRecord = record
                try await self.updateCKRecord()
            } else {
                throw error
            }
        }
        
        // we will not update the record lists here but only when navigating back
        
    }
    
    
    func deleteCKRecord(_ recordId: CKRecord.ID) async throws {
        try await privateDatabase.deleteRecord(withID: recordId)
        if displayRecord?.recordID == recordId {
            displayRecord = nil
        }
        self.myRecords.removeAll { $0.recordID == recordId }
    }
    
}


// MARK: Error other than the ones throw by CloudKit
extension CloudManager {
    enum _Error: Error {
        case failedToCreateShare(Error?)
        case iCloudAccountUnavailable
        case noRecordSelectedForShare
        case rootRecordNotFoundForShare
    }
}



// MARK: currently displayed record related
extension CloudManager {
    
    // separate from didSet to only set title and content when needed, ie: on initializing title and content
    // reason:
    // there might be pending updates that is not synced with the server yet (due to user typing faster than updates)
    // we don't want to replace the local entry values with the server ones but we will update the pending changes on the server instead
    func setDisplayRecordAndUpdateTitleContent(_ record: CKRecord) {
        self.displayRecord = record
        self.title = record.title
        self.content = record.content
    }

}



// MARK: Subscriptions related
// Subscriptions will only be triggered by changes originated from other devices
extension CloudManager {
    
    // Database subscription for participant
    // Query Subscription for owner:
    // reason: Query Subscription is only allowed for private and public database, but not for shared database
    //
    // we can also use a DB subscriptions here similar to the shared databased one.
    // However, in that case, any change in any record can trigger the notification, as well as creation and deletion in zones,
    // and it will take time to actually determine if our target display record is actually the source of the notification.
    func addQuerySubscription() async throws {
        guard let displayRecord, displayRecord.isOwner else { return }
        print("\(#function)")
        
        let notificationInfo = CKSubscription.NotificationInfo()
        // the notification should be sent with the "content-available" flag to allow for background downloads in the application.
        notificationInfo.shouldSendContentAvailable = true

        let predicate: NSPredicate = .init(format: "recordID == %@", displayRecord.recordID)
       
        let querySubscription = CKQuerySubscription(recordType: displayRecord.recordType, predicate: predicate, subscriptionID: CloudManager.privateDatabaseQuerySubscriptionId, options: [.firesOnRecordDeletion, .firesOnRecordUpdate])
        
        querySubscription.notificationInfo = notificationInfo
        querySubscription.zoneID = displayRecord.recordID.zoneID
        
        let _ = try await self.privateDatabase.save(querySubscription)
    }

    
    func fetchChangesForQuerySubscription(_ notification: CKQueryNotification) async throws {
        print("\(#function)")
        
        // NOTE: notification.recordID will not equal to displayRecord.recordID
        // - recordName (unique) will equal
        // - however, zone Id in notification.recordID will show up as SharedNoteZone:__defaultOwner__.
        // if needed, check zoneID.zoneName instead
        guard let displayRecord, displayRecord.isOwner, notification.recordID?.recordName == displayRecord.recordID.recordName else { return }
        
        print("displayRecord change")
        if notification.queryNotificationReason == .recordDeleted {
            self.displayRecord = nil
            return
        }
     
        // we can either use notification.recordID or displayRecord.recordID here
        // both will give in the same result
        let new = try await self.privateDatabase.record(for: displayRecord.recordID)
        self.setDisplayRecordAndUpdateTitleContent(new)
        
        return
    }
    
    
    func removeQuerySubscriptions() async throws {
        print("\(#function)")
        try await self.privateDatabase.deleteSubscription(withID: CloudManager.privateDatabaseQuerySubscriptionId)
    }

    
    func addSharedDatabaseSubscription() async throws {
        print("\(#function)")
        
        let notificationInfo = CKSubscription.NotificationInfo()
        // the notification should be sent with the "content-available" flag to allow for background downloads in the application.
        notificationInfo.shouldSendContentAvailable = true
                
        let sharedSubscription = CKDatabaseSubscription(subscriptionID: CloudManager.sharedCloudDatabaseSubscriptionId)
        sharedSubscription.notificationInfo = notificationInfo

        // specialize a database subscription by setting its recordType property to a specific record type. This limits the scope of the subscription to only track changes to records of that type and reduces the number of notifications it generates.
        sharedSubscription.recordType = CloudManager.recordType
        
        let _ = try await self.sharedCloudDatabase.save(sharedSubscription)
        
    }
    
    
    func fetchChangesForSharedDBSubscription() async throws {
        print("\(#function)")
        
        var more: Bool = true
        var modifiedZoneIds: [CKRecordZone.ID] = []
        var deletions: [CKDatabase.DatabaseChange.Deletion] = []
        
        // we cannot break out as soon as we get the target zone Id (private zone id is isPrivate, else the shared zone if)
        // reason: The IDs in modifications can also be included in deletions (we delete a changed zone) and may come later
        while more {
            // databaseChanges: https://developer.apple.com/documentation/cloudkit/ckdatabase/databasechanges(since:resultslimit:)
            // This method fetches record zone changes in a database, which includes new record zones, changed zones — including deleted or purged zones — and zones that contain record changes.
            let (modifications, _deletions, changeToken, moreComing) = try await self.sharedCloudDatabase.databaseChanges(since: self.sharedDatabaseChangeToken)
            
            modifiedZoneIds.append(contentsOf: modifications.map(\.zoneID))
            deletions.append(contentsOf: _deletions)
            
            more = moreComing
            
            self.sharedDatabaseChangeToken = changeToken
        }
               
        // The IDs in modifications can also be included in deletions (we delete a changed zone)
        modifiedZoneIds = modifiedZoneIds.filter({!deletions.map(\.zoneID).contains($0)})
        
        let zone = try await self.getSharedZone()
        
        //  we are not interested in other zones here
        if let deletion = deletions.filter({$0.zoneID == zone?.zoneID}).first {
            switch deletion.reason {

            // deleted: zone deleted
            // purge: A  deletion from the user via the iCloud storage UI.
            // This is an indication that the user wanted all data deleted, so local cached data should be wiped and not re-uploaded to the server.
            case .deleted, .purged:
                self.sharedWithMe = []
                if let displayRecord, !displayRecord.isOwner {
                    self.displayRecord = nil
                }
                break

            // The user chose to reset all encrypted data for their account.
            // This is an indication that the user had to reset encrypted data during account recovery, so local cached data should be re-uploaded to the server to minimize data loss
            case .encryptedDataReset:
                let (saved, _) = try await self.sharedCloudDatabase.modifyRecords(saving: self.sharedWithMe, deleting: [])
                var savedRecords: [CKRecord] = []
                for (_, result) in saved {
                    switch result {
                    case .success(let record):
                        savedRecords.append(record)
                    case .failure(let error):
                        print("Failed to save record: \(error)")
                        continue
                    }
                }
                self.sharedWithMe = savedRecords
                break
              
            @unknown default:
                break
            }
            
            return
        }
        
        //  we are not interested in other zones here
        guard let zone, modifiedZoneIds.contains(zone.zoneID) else {
            return
        }
              
        // we don't know exactly which record is changed so we will reload everything
        self.sharedWithMeCursor = nil
        try await self.loadSharedWithMeRecords()

        if let displayRecord = self.displayRecord, let newRecord = self.sharedWithMe.first(where: {$0.recordID == displayRecord.recordID}) {
            self.setDisplayRecordAndUpdateTitleContent(newRecord)
        }
    }
    
}


// MARK: Sharing related
extension CloudManager {
    struct SharedNoteTransferable: Transferable, Sendable {
        var share: CKShare?
        var createCKShare: @Sendable () async throws -> CKShare
        var container: CKContainer
        var sharingOption: CKAllowedSharingOptions
        

        static var transferRepresentation: some TransferRepresentation {
            CKShareTransferRepresentation { note in
                if let share = note.share {
                    return .existing(share, container: note.container, allowedSharingOptions: note.sharingOption)
                } else {
                    return .prepareShare(container: note.container, allowedSharingOptions: note.sharingOption) {
                        return try await note.createCKShare()
                    }
                }
            }
        }
    }

    var sharedNoteTransferable: SharedNoteTransferable {
        return SharedNoteTransferable(
            share: self.share,
            createCKShare: self.getCKShare,
            container: self.container,
            sharingOption: CloudManager.sharingOption
        )
    }
    
    // create root CKRecord & CKShare in the shared zone
    @Sendable
    private func getCKShare() async throws -> CKShare {
        if let share = self.share { return share }
        
        guard let record = self.displayRecord else {
            throw _Error.noRecordSelectedForShare
        }
        
        let database = record.isOwner ? self.privateDatabase : self.sharedCloudDatabase
        
        // already shared record
        if let shareReference = record.share {
            if let record = try? await database.record(for: shareReference.recordID), let share = record as? CKShare {
                print("shared record found")
                self.share = share
                return share
            }
        }

        print("creating CKShare...")

        // CKShare: https://developer.apple.com/documentation/CloudKit/CKShare
        // CKShare is a subclass of CKRecord
        // root record does not have to be saved on the server first
        let share = CKShare(rootRecord: record)
        
        // We can customize the title and image the system displays when initiating a share or accepting an invitation to participate.
        // We can also provide a custom UTI to indicate the content of the shared records.
        share[CKShare.SystemFieldKey.title] = "Let's collaborate on some notes!" as CKRecordValue
        // if let uiImage = UIImage(systemName: "square.and.pencil"), let data = uiImage.pngData() {
        //      share[CKShare.SystemFieldKey.thumbnailImageData] = data
        // }
                
        // to allow editing using the link
        // this can be configured later by the user using the share sheet or UICloudSharingController
        share.publicPermission = .readWrite
       
        // save operation will hang forever if the user has not signed into their iCloud account
        // Also, CKShare has to be save on the server before used in ShareLink or UICloudSharingController
        let (saved, _) = try await database.modifyRecords(saving: [share, record], deleting: [])
        
        var savedShare: CKShare?

        for (id, result) in saved {
            switch result {
            case .success(let record):
                if id == share.recordID {
                    if let share = record as? CKShare {
                        self.share = share
                        savedShare = share
                    }
                }
                
                // triggered multiple time, and is not guaranteed to have share set yet.
                // update later using refreshDisplayedRecord
//                if id == record.recordID {
//                    self.displayRecord = record
//                }
                
            case .failure(let error):
                print("Failed to save record: \(error)")
                throw error
            }
        }
        
        guard let savedShare else {
            throw _Error.failedToCreateShare(nil)
        }
        
        Task {
            try await refreshDisplayedRecord()
        }

        return savedShare
    }
    
    // To be used when cloudSharingControllerDidSaveShare on UICloudSharingController called.
    // At this point, the CKShare object and the whole share hierarchy are up to date on the server side,
    // so fetch the changes and update the local cache.
    func cloudSharingControllerDidSaveShare() async throws {
        guard let share, let displayRecord else { return }
        
        let database = displayRecord.isOwner ? self.privateDatabase : self.sharedCloudDatabase
        let results = try await database.records(for: [share.recordID, displayRecord.recordID])
        
        for (_, result) in results {
            switch result {
            case .success(let record):
                if record.recordID == displayRecord.recordID {
                    self.displayRecord = record
                }
                if record.recordID == share.recordID, let updatedRecord = record as? CKShare {
                    self.share = updatedRecord
                }
            case .failure(let error):
                print("Error refreshDisplayRecordAndShare: \(error)")
                throw error
            }
        
        }
        
        // update share separately because
        // share will not be updated in displayRecord:didSet due to the reference staying the same
//        Task {
//            try await refreshDisplayedRecord()
//        }
    }
    
    // To be used when cloudSharingControllerDidStopSharing on UICloudSharingController called.
    // CloudKit removes the CKShare record and updates the root record on the server side before calling this method,
    // so fetch the changes and update the local cache.
    //
    // Stopping sharing can happen in two scenarios: an owner stops a share, or a participant removes itself from a share.
    // In the former case, no visual changes occur on the owner side (privateDB).
    // In the latter case, the share disappears from the sharedDB.
    // If the share is the only item in the current zone, CloudKit removes the zone as well.
    //
    // Fetching immediately here may not get all the changes because the server side needs a while to index.
    func cloudSharingControllerDidStopSharing() async throws {
        guard let displayRecord else { return }
        
        // participant removes itself from a share
        if !displayRecord.isOwner {
            self.displayRecord = nil
            self.sharedWithMe.removeAll(where: { $0.recordID == displayRecord.recordID })
            return
        }
        
        // owner stops the share, record.share will be set to nil on the server
        // not using refreshDisplayedRecord to avoid unnecessary update on title and contents
        let new = try await self.privateDatabase.record(for: displayRecord.recordID)
        self.displayRecord = new
    }
    
    
    func shareAccepted(_ shareMetadata: CKShare.Metadata) async throws {
        print("\(#function)")

        try await self.checkAccountStatus()

        // checking the participantStatus of the provided metadata. If the status is pending, accept participation in the share.
        // trying to accept the share as an owner will throw an error
        if shareMetadata.participantRole != .owner && shareMetadata.participantStatus == .pending {
            let _ = try await self.container.accept(shareMetadata)
        }
                
        // shareMetadata.rootRecord is only present if the share metadata was returned from a CKFetchShareMetadataOperation with shouldFetchRootRecord set to YES
        guard let rootRecordId = shareMetadata.hierarchicalRootRecordID else {
            throw _Error.rootRecordNotFoundForShare
        }
        
        // root record shows up in sharedCloudDatabase for participant and privateDatabase for owner
        let database = shareMetadata.participantRole == .owner ? self.privateDatabase : self.sharedCloudDatabase
        
        let record = try await database.record(for: rootRecordId)

        if record.isOwner {
            if let currentIndex = self.myRecords.firstIndex(where: {$0.recordID == record.recordID }) {
                self.myRecords[currentIndex] = record
            } else {
                self.myRecords.insert(record, at: 0)
            }
        } else {
            if let currentIndex = self.sharedWithMe.firstIndex(where: {$0.recordID == record.recordID }) {
                self.sharedWithMe[currentIndex] = record
            } else {
                self.sharedWithMe.insert(record, at: 0)
            }
        }
        
        self.setDisplayRecordAndUpdateTitleContent(record)
    }

}


// MARK: private helpers
extension CloudManager {
    
    // CKRecordZone: https://developer.apple.com/documentation/cloudkit/ckrecordzone
    private func getPrivateZone() async throws -> CKRecordZone {
        if let zone = self.privateZone {
            return zone
        }

        // We can’t save any records in the zone until you save it to the database.
        // if a zone with the given name exist, that zone will be returned
        let zone = try await privateDatabase.save(CKRecordZone(zoneName: CloudManager.zoneName))
        self.privateZone = zone
        return zone
    }
    
    
    
    private func getSharedZone() async throws -> CKRecordZone? {
        if let zone = self.sharedZone {
            return zone
        }
       
        let allZones = try await sharedCloudDatabase.allRecordZones()
        
        if let first = allZones.first(where: {$0.zoneID.zoneName == CloudManager.zoneName}) {
            self.sharedZone = first
        } else {
            self.sharedZone = allZones.first
        }
        
        // Try to save zone in SharedCloudDatabase will result in an error: `Only shared zones can be accessed in the shared DB`
        // let zone = try await sharedCloudDatabase.save(CKRecordZone(zoneName: ShareManager.zoneName))
        return self.sharedZone

    }
    
    
    private func checkAccountStatus() async throws {
        self.accountStatus = try await container.accountStatus()
        if self.accountStatus != .available {
            throw _Error.iCloudAccountUnavailable
        }
    }
}
