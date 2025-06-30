//
//  File.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/09.
//

import SwiftUI

extension Notification {

    // determine the type of notification and fileURLs that is triggering the NSMetadataQuery subscription
    var processingTypeItemDict: [ProcessingType: [NSMetadataItem]] {
        guard let userInfo = self.userInfo as? [String: [NSMetadataItem]] else {
            return [
                .create: [],
                .update: [],
                .delete: [],
            ]
        }

        var delete: [NSMetadataItem] = []
        var create: [NSMetadataItem] = []
        var update: [NSMetadataItem] = []

        for (key, items) in userInfo {
            if items.isEmpty { continue }
            switch key {
            case NSMetadataQueryUpdateRemovedItemsKey:
                delete.append(contentsOf: items)

            case NSMetadataQueryUpdateChangedItemsKey:
                update.append(contentsOf: items)

            case NSMetadataQueryUpdateAddedItemsKey:
                create.append(contentsOf: items)

            default:
                continue
            }
        }
        return [
            .create: create,
            .update: update,
            .delete: delete,
        ]
    }
}


extension Notification.Name {
    var publisher: NotificationCenter.Publisher {
        return NotificationCenter.default.publisher(for: self)
    }
}
