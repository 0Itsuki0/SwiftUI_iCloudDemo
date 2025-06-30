//
//  CKRecord+Extensions.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/04.
//

import SwiftUI
import CloudKit


extension CKRecord {
    var title: String {
        self.value(forKey: Constants.titleKey) as? String ?? "(Untitled)"
    }
    
    var content: String {
        self.value(forKey: Constants.contentKey) as? String ?? "(Untitled)"
    }
    
    var isOwner: Bool {
        self.creatorUserRecordID?.recordName == CKCurrentUserDefaultName
    }
    
    var lastModifiedDateString: String? {
        guard let modificationDate = self.modificationDate else {
            return nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter.string(from: modificationDate)
    }
    
    func lastModifiedUserName(_ share: CKShare) -> String? {

        guard let participant = share.participants.first(where: {$0.userIdentity.userRecordID == self.lastModifiedUserRecordID}) else {
            return nil
        }
        
        if participant.role == .owner {
            return "(Me)"
        }
        
        
        guard let nameComponents = participant.userIdentity.nameComponents else {
            return nil
        }
        
        var name = ""
        
        if let givenName = nameComponents.givenName {
            name += "\(givenName)"
        }
        
        if let familyName = nameComponents.familyName {
            if !name.isEmpty {
                name += " "
            }
            name += "\(familyName)"
        }
                
        return name.isEmpty ? nil : name
    }
}

