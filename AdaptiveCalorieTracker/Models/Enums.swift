// AdaptiveCalorieTracker/Models/Enums.swift

import Foundation

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
        // Handle specific muscle categories
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
