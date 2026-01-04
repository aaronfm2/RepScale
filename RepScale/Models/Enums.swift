import Foundation

// MARK: - Unit System
enum UnitSystem: String, CaseIterable, Codable {
    case metric = "Metric"
    case imperial = "Imperial"
}

// MARK: - Gender
enum Gender: String, CaseIterable, Codable {
    case male = "Male"
    case female = "Female"
}

// MARK: - Activity Level (NEW)
enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary = "Sedentary"
    case lightlyActive = "Lightly Active"
    case moderatelyActive = "Moderately Active"
    case veryActive = "Very Active"
    case extraActive = "Extra Active"
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extraActive: return 1.9
        }
    }
    
    var description: String {
        switch self {
        case .sedentary: return "Little to no exercise"
        case .lightlyActive: return "Light exercise 1-3 days/week"
        case .moderatelyActive: return "Moderate exercise 3-5 days/week"
        case .veryActive: return "Hard exercise 6-7 days/week"
        case .extraActive: return "Physical job or training 2x/day"
        }
    }
}

// MARK: - Estimation/Projection Methods
enum EstimationMethod: Int, CaseIterable, Codable, Identifiable {
    case weightTrend30Day = 0
    case weightTrend7Day = 3
    case currentEatingHabits = 1
    case perfectGoalAdherence = 2
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .weightTrend30Day: return "30-Day Weight Trend"
        case .weightTrend7Day: return "7-Day Weight Trend"
        case .currentEatingHabits: return "Current Average Calorie Consumption"
        case .perfectGoalAdherence: return "Perfect Calorie Target Adherence"
        }
    }
}

// MARK: - Extensions for Conversion
extension Double {
    func toUserWeight(system: String) -> Double {
        return system == UnitSystem.imperial.rawValue ? self * 2.20462 : self
    }
    
    func toStoredWeight(system: String) -> Double {
        return system == UnitSystem.imperial.rawValue ? self / 2.20462 : self
    }
    
    func toUserDistance(system: String) -> Double {
        return system == UnitSystem.imperial.rawValue ? self * 0.621371 : self
    }
    
    func toStoredDistance(system: String) -> Double {
        return system == UnitSystem.imperial.rawValue ? self / 0.621371 : self
    }
    
    // NEW: Height Helpers
    func toUserHeight(system: String) -> Double {
        return system == UnitSystem.imperial.rawValue ? self / 30.48 : self // cm to ft
    }
    
    func toStoredHeight(system: String) -> Double {
        return system == UnitSystem.imperial.rawValue ? self * 30.48 : self // ft to cm
    }
}

// MARK: - Workout Categories
enum WorkoutCategories: String, CaseIterable, Codable {
    case push = "Push"
    case pull = "Pull"
    case upper = "Upper"
    case lower = "Lower"
    case fullBody = "Full Body"
    case arms = "Arms"
    case legs = "Legs"
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case abs = "Abs"
    case cardio = "Cardio"
}

// MARK: - Muscle Groups
enum MuscleGroup: String, CaseIterable, Codable {
    case chest = "Chest"
    case back = "Back"
    case legs = "Legs"
    case shoulders = "Shoulders"
    case abs = "Abs"
    case cardio = "Cardio"
    case biceps = "Biceps"
    case triceps = "Triceps"
}

// MARK: - Goals
enum GoalType: String, CaseIterable, Codable {
    case cutting = "Cutting"
    case bulking = "Bulking"
    case maintenance = "Maintenance"
}

// MARK: - Dashboard Card Types
enum DashboardCardType: String, CaseIterable, Codable, Identifiable {
    case projection = "Projections"
    case weightChange = "Weight Change"
    case weightTrend = "Weight History"
    case workoutDistribution = "Workout Focus"
    case weeklyWorkoutGoal = "Weekly Goal"
    case strengthTracker = "Strength Tracker"
    case repTracker = "Rep Tracker"
    case volumeTracker = "Volume Tracker"
    case nutrition = "Nutrition"
    case macroDistribution = "Macro Distribution"
    
    var id: String { rawValue }
}

// MARK: - Time Range Enum
enum TimeRange: String, CaseIterable, Identifiable {
    case sevenDays = "7 Days"
    case thirtyDays = "30 Days"
    case ninetyDays = "90 Days"
    case oneHundredEightyDays = "180 Days"
    case oneYear = "1 Year"
    case allTime = "All Time"
    
    var id: String { rawValue }
    
    func startDate(from now: Date) -> Date? {
        switch self {
        case .sevenDays: return Calendar.current.date(byAdding: .day, value: -7, to: now)
        case .thirtyDays: return Calendar.current.date(byAdding: .day, value: -30, to: now)
        case .ninetyDays: return Calendar.current.date(byAdding: .day, value: -90, to: now)
        case .oneHundredEightyDays: return Calendar.current.date(byAdding: .day, value: -180, to: now)
        case .oneYear: return Calendar.current.date(byAdding: .year, value: -1, to: now)
        case .allTime: return nil
        }
    }
}

// MARK: - Extensions
extension WorkoutCategories {
    var muscleGroups: [MuscleGroup] {
        switch self {
        case .push:
            return [.chest, .shoulders, .triceps]
        case .pull:
            return [.back, .biceps]
        case .legs, .lower:
            return [.legs]
        case .upper:
            return [.chest, .back, .shoulders, .biceps, .triceps]
        case .fullBody:
            return MuscleGroup.allCases
        case .arms:
            return [.biceps, .triceps]
        case .chest:
            return [.chest]
        case .back:
            return [.back]
        case .shoulders:
            return [.shoulders]
        case .abs:
            return [.abs]
        case .cardio:
            return [.cardio]
        }
    }
}

extension MuscleGroup {
    var workoutCategories: [WorkoutCategories] {
        WorkoutCategories.allCases.filter {
            $0.muscleGroups.contains(self)
        }
    }
}
