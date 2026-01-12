import Foundation
import SwiftData

@Model
final class Workout {
    var id: UUID = UUID()
    var date: Date = Date()
    var category: String = ""
    var muscleGroups: [String] = []
    var note: String = ""
    
    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.workout)
    var exercises: [ExerciseEntry]? = []
    
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
    var uuid: UUID = UUID()
    
    // 1. Add Sort Order Property
    var sortOrder: Int = 0
    
    var name: String = ""
    var reps: Int?
    var weight: Double?
    var note: String = ""
    
    var duration: Double?
    var distance: Double?
    var isCardio: Bool = false
    
    var workout: Workout?
    
    init(name: String, reps: Int? = nil, weight: Double? = nil, duration: Double? = nil, distance: Double? = nil, isCardio: Bool = false, note: String = "") {
        self.name = name
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.distance = distance
        self.isCardio = isCardio
        self.note = note
    }
}

// --- Template Models ---

@Model
final class WorkoutTemplate {
    var name: String = ""
    var category: String = ""
    var muscleGroups: [String] = []
    
    @Relationship(deleteRule: .cascade, inverse: \TemplateExerciseEntry.template)
    var exercises: [TemplateExerciseEntry]? = []
    
    init(name: String, category: String, muscleGroups: [String]) {
        self.name = name
        self.category = category
        self.muscleGroups = muscleGroups
    }
}

@Model
final class TemplateExerciseEntry {
    // 2. Add Sort Order to Template as well
    var sortOrder: Int = 0
    
    var name: String = ""
    var reps: Int?
    var weight: Double?
    var note: String = ""
    
    var duration: Double?
    var distance: Double?
    var isCardio: Bool = false
    
    var template: WorkoutTemplate?
    
    init(name: String, reps: Int? = nil, weight: Double? = nil, duration: Double? = nil, distance: Double? = nil, isCardio: Bool = false, note: String = "") {
        self.name = name
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.distance = distance
        self.isCardio = isCardio
        self.note = note
    }
}
extension Workout {
    /// Returns exercises sorted by the persisted sortOrder
    var sortedExercises: [ExerciseEntry] {
        return (exercises ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
}
