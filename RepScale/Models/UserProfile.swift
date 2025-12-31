import Foundation
import SwiftData

@Model
final class UserProfile {
    var createdAt: Date = Date()
    
    // MARK: - Core Profile
    var unitSystem: String = UnitSystem.metric.rawValue
    var gender: String = Gender.male.rawValue
    var isDarkMode: Bool = true
    
    // MARK: - Goals & Strategy
    var dailyCalorieGoal: Int = 2000
    var targetWeight: Double = 70.0
    var goalType: String = GoalType.cutting.rawValue
    var maintenanceCalories: Int = 2500
    var maintenanceTolerance: Double = 2.0
    var estimationMethod: Int = 0
    
    // MARK: - Feature Flags
    var isCalorieCountingEnabled: Bool = true
    var enableCaloriesBurned: Bool = true
    var enableHealthKitSync: Bool = true
    
    // MARK: - Dashboard Customization
    var dashboardLayoutJSON: String = ""
    var workoutTimeRange: String = "30 Days"
    var weightHistoryTimeRange: String = "30 Days"
    
    // MARK: - Workout Preferences (NEW)
    var trackedMuscles: String = "Chest,Back,Legs,Shoulders,Abs,Cardio,Biceps,Triceps"
    
    init() {
        self.createdAt = Date()
    }
}
