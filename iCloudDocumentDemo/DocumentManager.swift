//
//  DocumentManager.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/08.
//

import Combine
import SwiftUI


enum ProcessingType {
    case create
    case update
    case delete
}

// A wrapper around NSMetadataItem for easier interaction
struct MetadataItem: Hashable {
    var fileURL: URL

    var fileName: String
    var displayName: String {
        if let name = fileName.split(separator: ".").first {
            return String(name)
        }
        return fileName
    }

    var lastUpdated: Date?

    var nsMetadataItem: NSMetadataItem

}


extension DocumentManager {
    private static let fileExtension: String = "txt"
}

extension DocumentManager {
    enum _Error: Error {
        case containerRootURLUndetermined
        case failedToGetContentData
        case fileAlreadyExists
        case failedToGetFileContent

        var message: String {
            switch self {
            case .containerRootURLUndetermined:
                return "Container root URL is undetermined."
            case .failedToGetContentData:
                return "Failed to get content data."
            case .fileAlreadyExists:
                return "File already exists."
            case .failedToGetFileContent:
                return "Failed to get file content."
            }
        }
    }
}


@Observable
@MainActor
class DocumentManager {

    // ubiquityIdentityToken: https://developer.apple.com/documentation/foundation/filemanager/ubiquityidentitytoken
    // In iCloud Drive Documents, when iCloud is available, this property contains an opaque object representing the identity of the current user. If iCloud is unavailable or there is no logged-in user, the value of this property is nil.
    // You can use the token in this property, together with the NSUbiquityIdentityDidChange notification, to detect when the user logs in or out of iCloud and to detect changes to the active iCloud account. When the user logs in with a different iCloud account, the identity token changes, and the system posts the notification. If you stored or archived the previous token, compare that token to the newly obtained one using the isEqual(_:) method to determine if the users are the same or different.
    // CloudKit clients should not use this token as a way to identify whether the iCloud account is logged in. Instead, use accountStatus(completionHandler:) or fetchUserRecordID(completionHandler:).
    private(set) var ubiquityIdentityToken:
        (any NSCoding & NSCopying & NSObjectProtocol)?
    private var ubiquityIdentityChangeCancellable: AnyCancellable?

    //  URL pointing to the specified ubiquity container, or nil if the container could not be located or if iCloud storage is unavailable for the current user or device.
    private(set) var containerRootURL: URL?

    // iOS apps use NSMetadataQuery rather than file system APIs to discover documents and watch for changes in an iCloud container.
    // When an app creates an iCloud document on one device, iCloud first synchronizes the document metadata to the other devices to tell them about the existence of the document. Then, depending on the device types, iCloud may or may not continue to synchronize the document data.
    // For iOS devices, iCloud doesn’t synchronize the document data until an app asks (either explicitly or implicitly). When an iOS app receives a notification that a new document exists, the document data may not physically exist on the local file system, so it isn’t discoverable with file system APIs.
    // A query has two phases when gathering the metadata: the initial phase that collects all currently matching results, and a second phase that gathers live updates. It posts an NSMetadataQueryDidFinishGathering notification when it finishes the first phase, and an NSMetadataQueryDidUpdate notification each time an update occurs.
    private let metadataQuery = NSMetadataQuery()
    private var metadataQueryCancellable: AnyCancellable?

    // MARK: view related

    private(set) var metadataItems: [MetadataItem] = []

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

    var selectedItem: MetadataItem?

    // File-related manipulation (Creation, deletion, update) takes time for us to confirm changes from the server using `NSMetadataQuery`
    //
    // only enable the UIs after confirming the update in `handleMetadataUpdate`
    // NOTE: probably want to add a timeout time to check if the update is taking too long.
    //
    // We are not updating the `metadataItems` directly but only within the handleMetadataUpdate
    // because we want to confirm the change on the server, and we want a single source of truth
    //
    // Since when we confirm the update in `handleMetadataUpdate`
    // We are not checking the specific `ProcessingType` because the the same item can also be updated from other devices differently than  the current one,
    // technically speaking, we can have a `URL?` here instead of `ProcessingType?`
    private(set) var processing: (ProcessingType, URL)?

    init() {
        self.ubiquityIdentityToken = FileManager.default.ubiquityIdentityToken
        
        let publisher = NSNotification.Name.NSUbiquityIdentityDidChange.publisher
        
        self.ubiquityIdentityChangeCancellable = publisher.receive(
            on: DispatchQueue.main
        ).sink { notification in
            self.handleUbiquityIdentityDidChange(notification: notification)
        }

        if self.ubiquityIdentityToken == nil {
            return
        }

        self.setContainerRootURL()
        self.setupMetadataQuery()
    }

    // Stop metadataQuery if it is still running.
    deinit {
        guard metadataQuery.isStarted else { return }
        metadataQuery.stop()
    }

    private func handleUbiquityIdentityDidChange(notification: Notification) {
        print(#function)

        let newToken = FileManager.default.ubiquityIdentityToken

        if self.ubiquityIdentityToken?.isEqual(newToken) == true {
            return
        }

        self.ubiquityIdentityToken = newToken
        if newToken == nil {
            return
        }
        
        self.setContainerRootURL()
    }

    // Set up a metadata query to collects all currently matching results and gather document changes in the iCloud container.
    private func setupMetadataQuery() {
        print(#function)
        // metadata query notifications
        let notificationNames: [NSNotification.Name] = [

            // https://developer.apple.com/documentation/Foundation/NSNotification/Name-swift.struct/NSMetadataQueryDidFinishGathering
            // Posted when the receiver has finished with the initial result-gathering phase of the query.
            .NSMetadataQueryDidFinishGathering,

            // https://developer.apple.com/documentation/Foundation/NSNotification/Name-swift.struct/NSMetadataQueryDidUpdate
            // Posted when the receiver’s results have changed during the live-update phase of the query.
            .NSMetadataQueryDidUpdate,
        ]

        let publishers = notificationNames.map(\.publisher)
        self.metadataQueryCancellable = Publishers.MergeMany(publishers)
            .receive(on: DispatchQueue.main).sink { notification in
                self.handleMetadataUpdate(notification: notification)
            }

        metadataQuery.notificationBatchingInterval = 1
        metadataQuery.searchScopes = [
            NSMetadataQueryUbiquitousDataScope,
            NSMetadataQueryUbiquitousDocumentsScope,
        ]
        metadataQuery.predicate = NSPredicate(
            format: "%K LIKE %@",
            NSMetadataItemFSNameKey,
            "*." + DocumentManager.fileExtension
        )
        metadataQuery.sortDescriptors = [
            NSSortDescriptor(
                key: NSMetadataItemFSContentChangeDateKey,
                ascending: false
            )
        ]
        metadataQuery.start()
    }

    private func handleMetadataUpdate(notification: Notification) {
        print(#function)
        guard
            (notification.object as? NSMetadataQuery)?.isEqual(
                self.metadataQuery
            ) == true
        else { return }

//        dump("notification: \(notification)")

        // the initial phase of NSMetadataQuery: collects all currently matching results
        if notification.name == .NSMetadataQueryDidFinishGathering {
            self.reloadAllDocuments()
            return
        }

        // second phase: gathers live updates
        //
        // NOTE: we can also call `self.reloadAllDocuments()` here
        // However, `NSMetadataQuery.results` loads everything matching the query.
        // Not just the one that triggers the notification.
        // It is generally not recommended due to performance and memory issues.
        let toItems: ([NSMetadataItem]) -> [MetadataItem] = { items in
            return items.map(\.metadataItem).filter({ $0 != nil }).map({ $0! })
        }
        let processingTypeItemDict = notification.processingTypeItemDict
        var newItems = self.metadataItems

        let creates = processingTypeItemDict[.create] ?? []
        newItems.append(contentsOf: toItems(creates))

        let updates = processingTypeItemDict[.update] ?? []
        for update in updates {
            guard let item = update.metadataItem else { continue }
            newItems.removeAll(where: { $0.fileURL == item.fileURL })
            newItems.append(item)

            // not updating the `selectedItem` variable even if it is included in the updates
            // because the user might currently be editing
        }

        let deletes = processingTypeItemDict[.delete] ?? []
        newItems.removeAll(where: { new in
            !deletes.filter({ $0.fileURL == new.fileURL }).isEmpty
        })

        if let selectedItem,
            newItems.filter({ $0.fileURL == selectedItem.fileURL }).isEmpty
        {
            self.selectedItem = nil
        }

        // check if the current processing one is updated
        // not checking the specific type here because it might also be updated differently on other devices
        if let currentProcessing = self.processing {
            if creates.map(\.fileURL).contains(currentProcessing.1)
                || updates.map(\.fileURL).contains(currentProcessing.1)
                || deletes.map(\.fileURL).contains(currentProcessing.1)
            {
                self.processing = nil
            }
        }

        self.metadataItems = newItems.sortedByLastUpdated

    }

    private func setContainerRootURL() {
        print(#function)

        // url(forUbiquityContainerIdentifier:): https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:)
        // Do not call this method from your app’s main thread. Because this method might take a nontrivial amount of time to set up iCloud and return the requested URL, you should always call it from a secondary thread. To determine if iCloud is available, especially at launch time, check the value of the ubiquityIdentityToken property instead.
        //
        // In iOS, you must call this method at least once before trying to search for cloud-based files in the ubiquity container. If your app accesses multiple ubiquity containers, call this method once for each container. In macOS, you do not need to call this method if you use NSDocument-based objects, because the system then calls this method automatically.

        //
        // containerIdentifier: The fully-qualified container identifier for an iCloud container directory. The string you specify must not contain wildcards and must be of the form <TEAMID>.<CONTAINER>, where <TEAMID> is your development team ID and <CONTAINER> is the bundle identifier of the container you want to access.
        // The container identifiers for your app must be declared in the com.apple.developer.ubiquity-container-identifiers array of the .entitlements property list file in your Xcode project.
        // If you specify nil for this parameter, this method returns the first container listed in the com.apple.developer.ubiquity-container-identifiers entitlement array.

        Task {
            if let url = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
                DispatchQueue.main.async {
                    self.containerRootURL = url
                }
                return
            }
        }
    }

}

// MARK: file manipulation
extension DocumentManager {

    func createDocument(_ fileName: String, content: String = "") throws {
        print(#function)
        guard let containerRootURL else {
            throw _Error.containerRootURLUndetermined
        }

        let fileURL =
            containerRootURL
            .appendingPathComponent(
                fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Untitled" : fileName,
                isDirectory: false
            )
            .appendingPathExtension(DocumentManager.fileExtension)

        // FileManager.default.fileExists(atPath: fileURL.absoluteString) will always return false
        if self.metadataItems.contains(where: { $0.fileURL == fileURL }) {
            throw _Error.fileAlreadyExists
        }

        let folderPath = fileURL.deletingLastPathComponent().path
        try FileManager.default.createDirectory(
            atPath: folderPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        self.processing = (.create, fileURL)
        try self.writeContentToFile(content, fileURL: fileURL)
    }

    func deleteDocument(_ item: MetadataItem) throws {
        print(#function)
        self.processing = (.delete, item.fileURL)
        try FileManager.default.removeItem(at: item.fileURL)
    }

    // only get document data upon request
    //
    // When an iOS app receives a notification from NSMetadataQuery,
    // the document data is not included in the NSMetadataItem, and
    // it also may not physically exist on the local file system yet
    //
    // if downloading the item to local system is desired, use startDownloadingUbiquitousItem(at:): https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:)
    //  ie: `try FileManager.default.startDownloadingUbiquitousItem(at: item.fileURL)`
    //
    // This function Starts downloading (if necessary) the specified item to the local system.
    // If a cloud-based file or directory has not been downloaded yet, calling this method starts the download process. If the item exists locally, calling this method synchronizes the local copy with the version in the cloud.
    // For a given URL, you can determine if a file is downloaded by getting the value of the NSMetadataUbiquitousItemDownloadingStatusKey key.
    // You can also use related keys to determine the current progress in downloading the file.
    func getDocumentContent(_ item: MetadataItem) throws -> String {
        print(#function)

        let data = try Data(contentsOf: item.fileURL)
        guard let content = String(data: data, encoding: .utf8) else {
            throw _Error.failedToGetContentData
        }

        return content
    }

    func updateDocumentContent(_ item: MetadataItem, content: String) throws {
        print(#function)
        self.processing = (.update, item.fileURL)
        try self.writeContentToFile(content, fileURL: item.fileURL)
    }

    func reloadAllDocuments() {
        print(#function)
        // To avoid potential conflicts with the system, disable the query update when accessing the results, and enable it after finishing the access
        metadataQuery.disableUpdates()

        // results will give everything matching the query.
        // Not just the one that triggers the notification.
        // It is generally not recommended due to performance and memory issues. To access individual result array elements, use the resultCount and result(at:) methods.
        if let results = metadataQuery.results as? [NSMetadataItem] {
            let items = results.map(\.metadataItem).filter({ $0 != nil }).map({
                $0!
            })
            self.metadataItems = items.sortedByLastUpdated
        }

        metadataQuery.enableUpdates()
    }

    private func writeContentToFile(_ content: String, fileURL: URL) throws {
        guard let data = content.data(using: .utf8) else {
            throw _Error.failedToGetContentData
        }

        try data.write(to: fileURL)
    }
}
