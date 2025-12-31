import Foundation
import SwiftData
import SwiftUI

@Observable
class AddWorkoutViewModel {
    // MARK: - Properties
    
    // Form Data
    var date: Date = Date()
    
    var category: String = "Push" {
        didSet {
            updateMusclesForCategory()
        }
    }
    
    var selectedMuscles: Set<String> = []
    var note: String = ""
    var exercises: [ExerciseEntry] = []
    
    // UI State
    var showAddExerciseSheet: Bool = false
    var showLoadTemplateSheet: Bool = false
    var showSaveTemplateAlert: Bool = false
    var newTemplateName: String = ""
    
    // Constants
    var categories: [WorkoutCategories] {
        WorkoutCategories.allCases
    }
    var muscles: [MuscleGroup] {
        MuscleGroup.allCases
    }
    
    // Helper Struct for UI
    struct ExerciseGroup {
        let name: String
        var exercises: [ExerciseEntry]
    }
    
    // MARK: - Initializer
    init(workoutToEdit: Workout? = nil) {
        if let workout = workoutToEdit {
            self.date = workout.date
            self.category = workout.category
            self.selectedMuscles = Set(workout.muscleGroups)
            self.note = workout.note
            // FIX: Unwrap optional exercises
            self.exercises = workout.exercises ?? []
        } else {
            updateMusclesForCategory()
        }
    }
    
    // MARK: - Computed Properties
    
    var groupedExercises: [ExerciseGroup] {
        var groups: [ExerciseGroup] = []
        for exercise in exercises {
            if let index = groups.firstIndex(where: { $0.name == exercise.name }) {
                groups[index].exercises.append(exercise)
            } else {
                groups.append(ExerciseGroup(name: exercise.name, exercises: [exercise]))
            }
        }
        return groups
    }
    
    // MARK: - Methods
    
    private func updateMusclesForCategory() {
        if let catEnum = WorkoutCategories(rawValue: category) {
            let defaults = catEnum.muscleGroups.map { $0.rawValue }
            self.selectedMuscles = Set(defaults)
        }
    }
    
    func deleteFromGroup(group: ExerciseGroup, at offsets: IndexSet) {
        let exercisesToDelete = offsets.map { group.exercises[$0] }
        exercises.removeAll { ex in
            exercisesToDelete.contains(where: { $0 === ex })
        }
    }
    
    func addSet(to groupName: String) {
        if let lastIndex = exercises.lastIndex(where: { $0.name == groupName }) {
            let ex = exercises[lastIndex]
            let newEx = ExerciseEntry(
                name: ex.name,
                reps: ex.reps,
                weight: ex.weight,
                duration: ex.duration,
                distance: ex.distance,
                isCardio: ex.isCardio,
                note: ""
            )
            if lastIndex + 1 < exercises.count {
                exercises.insert(newEx, at: lastIndex + 1)
            } else {
                exercises.append(newEx)
            }
        }
    }
    
    func duplicateExercise(_ ex: ExerciseEntry) {
        let newEx = ExerciseEntry(
            name: ex.name,
            reps: ex.reps,
            weight: ex.weight,
            duration: ex.duration,
            distance: ex.distance,
            isCardio: ex.isCardio,
            note: ex.note
        )
        if let index = exercises.firstIndex(of: ex) {
            if index + 1 < exercises.count {
                exercises.insert(newEx, at: index + 1)
            } else {
                exercises.append(newEx)
            }
        } else {
            exercises.append(newEx)
        }
    }
    
    // MARK: - Template & Saving Logic
    
    func loadTemplate(_ template: WorkoutTemplate) {
        category = template.category
        selectedMuscles = Set(template.muscleGroups)
        
        // FIX: Unwrap optional template exercises
        let templateExercises = template.exercises ?? []
        
        let newExercises = templateExercises.map { tex in
            ExerciseEntry(
                name: tex.name,
                reps: tex.reps,
                weight: tex.weight,
                duration: tex.duration,
                distance: tex.distance,
                isCardio: tex.isCardio,
                note: tex.note
            )
        }
        exercises.append(contentsOf: newExercises)
        showLoadTemplateSheet = false
    }
    
    func saveAsTemplate(context: ModelContext) {
        guard !newTemplateName.isEmpty else { return }
        
        let template = WorkoutTemplate(name: newTemplateName, category: category, muscleGroups: Array(selectedMuscles))
        let templateExercises = exercises.map { ex in
            TemplateExerciseEntry(
                name: ex.name,
                reps: ex.reps,
                weight: ex.weight,
                duration: ex.duration,
                distance: ex.distance,
                isCardio: ex.isCardio,
                note: ex.note
            )
        }
        template.exercises = templateExercises
        context.insert(template)
        newTemplateName = ""
        showSaveTemplateAlert = false
    }
    
    func saveWorkout(context: ModelContext, originalWorkout: Workout?, onComplete: () -> Void) {
        if let workout = originalWorkout {
            // Update Existing
            workout.date = Calendar.current.startOfDay(for: date)
            workout.category = category
            workout.muscleGroups = Array(selectedMuscles)
            workout.note = note
            workout.exercises = exercises
        } else {
            // Create New
            let workout = Workout(date: date, category: category, muscleGroups: Array(selectedMuscles), note: note)
            workout.exercises = exercises
            context.insert(workout)
        }
        onComplete()
    }
}
