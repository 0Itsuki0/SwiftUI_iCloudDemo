//
//  File.swift
//  iCloudDemo
//
//  Created by Itsuki on 2025/06/09.
//

import SwiftUI

extension Error {
    var message: String {
        if let error = self as? DocumentManager._Error {
            return error.message
        } else {
            return String(describing: self)
        }
    }
}
