import Foundation
import SwiftData

@Model
final class Workout {
    var id: UUID
    var date: Date
    var category: String
    var muscleGroups: [String]
    var note: String
    
    @Relationship(deleteRule: .cascade) var exercises: [ExerciseEntry] = []
    
    init(date: Date, category: String, muscleGroups: [String], note: String = "") {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.category = category
        self.muscleGroups = muscleGroups
        self.note = note
    }
}

@Model
final class ExerciseEntry {
    var name: String
    var reps: Int
    var weight: Double
    var note: String
    
    init(name: String, reps: Int, weight: Double, note: String = "") {
        self.name = name
        self.reps = reps
        self.weight = weight
        self.note = note
    }
}

// --- NEW: Template Models ---

@Model
final class WorkoutTemplate {
    var name: String // e.g. "Chest Day"
    var category: String
    var muscleGroups: [String]
    
    @Relationship(deleteRule: .cascade) var exercises: [TemplateExerciseEntry] = []
    
    init(name: String, category: String, muscleGroups: [String]) {
        self.name = name
        self.category = category
        self.muscleGroups = muscleGroups
    }
}

@Model
final class TemplateExerciseEntry {
    var name: String
    var reps: Int
    var weight: Double
    var note: String
    
    init(name: String, reps: Int, weight: Double, note: String = "") {
        self.name = name
        self.reps = reps
        self.weight = weight
        self.note = note
    }
}
