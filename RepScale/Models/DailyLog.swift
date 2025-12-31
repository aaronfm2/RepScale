import Foundation
import SwiftData

@Model
final class DailyLog {
    // FIX: Removed @Attribute(.unique) as CloudKit does not support unique constraints
    var date: Date = Date()
    
    var weight: Double?
    var note: String = ""
    
    // Total values (HealthKit + Manual)
    var caloriesConsumed: Int = 0
    var caloriesBurned: Int = 0
    
    var goalType: String?
    
    // Total Macros
    var protein: Int? // grams
    var carbs: Int?   // grams
    var fat: Int?     // grams
    
    // --- NEW: Manual Overrides (Persisted separately) ---
    var manualCalories: Int = 0
    var manualProtein: Int = 0
    var manualCarbs: Int = 0
    var manualFat: Int = 0
    // ----------------------------------------------------
    
    var netCalories: Int {
        return caloriesConsumed - caloriesBurned
    }

    init(date: Date, weight: Double? = nil, caloriesConsumed: Int = 0, caloriesBurned: Int = 0, goalType: String? = nil, protein: Int? = nil, carbs: Int? = nil, fat: Int? = nil) {
        self.date = Calendar.current.startOfDay(for: date)
        self.weight = weight
        self.caloriesConsumed = caloriesConsumed
        self.caloriesBurned = caloriesBurned
        self.goalType = goalType
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.note = note
    }
    
    // Helper to detect if any override is active
    var isOverridden: Bool {
        return manualCalories != 0 || manualProtein != 0 || manualCarbs != 0 || manualFat != 0
    }
}
