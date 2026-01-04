import Foundation
import SwiftData

@Model
final class UserProfile {
    var createdAt: Date = Date()
    
    // MARK: - Core Profile
    var unitSystem: String = UnitSystem.metric.rawValue
    var gender: String = Gender.male.rawValue
    var isDarkMode: Bool = true
    
    // MARK: - Biometrics (NEW)
    var height: Double = 175.0 // Stored in cm
    var age: Int = 30
    var activityLevel: String = ActivityLevel.moderatelyActive.rawValue
    
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
    var strengthGraphTimeRange: String = "90 Days"
    var strengthGraphExercise: String = "Barbell Bench Press" // Default
    var strengthGraphReps: Int = 5
    var repGraphExercise: String = ""
    var repGraphWeight: Double = -1.0
    
    // MARK: - Workout Preferences
    var trackedMuscles: String = "Chest,Back,Legs,Shoulders,Abs,Cardio,Biceps,Triceps"
    var customMuscles: String = ""
    var weeklyWorkoutGoal: Int = 3
    
    init() {
        self.createdAt = Date()
    }
}
