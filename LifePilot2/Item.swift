//
//  Item.swift
//  LifePilot2
//
//  Created by mohamed reda oumahdi on 15/03/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
