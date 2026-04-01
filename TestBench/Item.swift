//
//  Item.swift
//  TestBench
//
//  Created by Errol Brandt on 2/4/2026.
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
