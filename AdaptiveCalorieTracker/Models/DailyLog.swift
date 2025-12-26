import Foundation
import SwiftData

@Model
final class DailyLog {
    @Attribute(.unique) var date: Date
    var weight: Double?
    var caloriesConsumed: Int
    var caloriesBurned: Int
    
    // Computed property for easy graph use
    var netCalories: Int {
        return caloriesConsumed - caloriesBurned
    }

    init(date: Date, weight: Double? = nil, caloriesConsumed: Int = 0, caloriesBurned: Int = 0) {
        // Normalizing the date ensures all logs on "Dec 25" are treated as the same entry
        self.date = Calendar.current.startOfDay(for: date)
        self.weight = weight
        self.caloriesConsumed = caloriesConsumed
        self.caloriesBurned = caloriesBurned
    }
}
