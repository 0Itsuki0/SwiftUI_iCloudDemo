//
//  MemoModal.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/05/30.
//

import SwiftUI
import SwiftData

@Model
class MemoModel {
    
    // @Attribute(.unique) <- Not compatible with CloudKit
    // For other constraints: https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices#Define-a-CloudKit-compatible-schema
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var lastUpdated: Date = Date()
    var isImportant: Bool = false
    
    
    init(title: String, content: String, lastUpdated: Date, isImportant: Bool) {
        self.title = title
        self.content = content
        self.lastUpdated = lastUpdated
        self.isImportant = isImportant
    }
}
