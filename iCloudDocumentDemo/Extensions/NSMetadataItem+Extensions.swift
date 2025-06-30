//
//  NSMetadataItem+Extensions.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/09.
//

import SwiftUI

extension NSMetadataItem {
    var fileURL: URL? {
        return self.value(forAttribute: NSMetadataItemURLKey) as? URL
    }

    var fileName: String? {
        return self.value(forAttribute: NSMetadataItemFSNameKey) as? String
    }

    var lastUpdated: Date? {
        return self.value(forAttribute: NSMetadataItemFSContentChangeDateKey)
            as? Date
    }

    var metadataItem: MetadataItem? {
        guard let fileURL = self.fileURL, let fileName = self.fileName else {
            return nil
        }
        return MetadataItem(
            fileURL: fileURL,
            fileName: fileName,
            lastUpdated: self.lastUpdated,
            nsMetadataItem: self
        )
    }
}
