import Foundation
import SwiftData

@Model
final class WeightEntry {
    var date: Date = Date()
    var weight: Double = 0.0
    var note: String = ""
    
    // CloudKit requires relationships to be optional
    @Relationship(deleteRule: .cascade, inverse: \ProgressPhoto.weightEntry)
    var photos: [ProgressPhoto]? = []
    
    init(date: Date = Date(), weight: Double, note: String) {
        self.date = date
        self.weight = weight
        self.note = note
    }
}

@Model
final class ProgressPhoto {
    // 1. Set a default value (empty Data) for imageData
    @Attribute(.externalStorage) var imageData: Data = Data()
    
    // 2. Set a default value for timestamp
    var timestamp: Date = Date()
    
    // 3. Set a default value for bodyTag
    var bodyTag: String = "Full Body"
    
    // CloudKit requires the inverse relationship to be optional
    var weightEntry: WeightEntry?
    
    init(imageData: Data, bodyTag: String = "Full Body") {
        self.imageData = imageData
        self.timestamp = Date()
        self.bodyTag = bodyTag
    }
}
