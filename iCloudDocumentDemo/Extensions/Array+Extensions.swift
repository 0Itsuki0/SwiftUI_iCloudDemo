//
//  Array+Extensions.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/09.
//

import SwiftUI

extension Array where Element == MetadataItem {
    var sortedByLastUpdated: [Element] {
        return self.sorted { (lhs, rhs) -> Bool in
            return lhs.lastUpdated ?? Date() > rhs.lastUpdated ?? Date()
        }
    }
}
