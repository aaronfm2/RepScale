enum MuscleGroup: String, CaseIterable, Codable {
    case chest = "Chest"
    case back = "Back"
    case legs = "Legs"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case abs = "Abs"
    case cardio = "Cardio"
}

enum GoalType: String, CaseIterable, Codable {
    case cutting = "Cutting"
    case bulking = "Bulking"
    case maintenance = "Maintenance"
}
