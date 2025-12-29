import Foundation
import SwiftData

@Model
final class GoalPeriod {
    var startDate: Date = Date()
    var endDate: Date? // Nil means this is the currently active period
    
    var goalType: String = ""
    var startWeight: Double = 0.0
    var targetWeight: Double = 0.0
    var dailyCalorieGoal: Int = 0
    var maintenanceCalories: Int = 0
    
    init(startDate: Date = Date(), goalType: String, startWeight: Double, targetWeight: Double, dailyCalorieGoal: Int, maintenanceCalories: Int) {
        self.startDate = startDate
        self.goalType = goalType
        self.startWeight = startWeight
        self.targetWeight = targetWeight
        self.dailyCalorieGoal = dailyCalorieGoal
        self.maintenanceCalories = maintenanceCalories
    }
}
