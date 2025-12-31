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

// MARK: - Estimation/Projection Methods
enum EstimationMethod: Int, CaseIterable, Codable, Identifiable {
    case weightTrend30Day = 0
    case currentEatingHabits = 1
    case perfectGoalAdherence = 2
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .weightTrend30Day: return "30-Day Weight Trend"
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
    
    var id: String { rawValue }
}

// MARK: - Time Range Enum
enum TimeRange: String, CaseIterable, Identifiable {
    case sevenDays = "7 Days"
    case thirtyDays = "30 Days"
    case ninetyDays = "90 Days"
    case allTime = "All Time"
    
    var id: String { rawValue }
    
    func startDate(from now: Date) -> Date? {
        switch self {
        case .sevenDays: return Calendar.current.date(byAdding: .day, value: -7, to: now)
        case .thirtyDays: return Calendar.current.date(byAdding: .day, value: -30, to: now)
        case .ninetyDays: return Calendar.current.date(byAdding: .day, value: -90, to: now)
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
