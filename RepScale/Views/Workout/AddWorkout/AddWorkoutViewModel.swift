import Foundation
import SwiftData
import SwiftUI

@Observable
class AddWorkoutViewModel {
    // MARK: - Properties
    
    var currentWorkout: Workout?
    
    var date: Date = Date()
    
    var category: String = "Push" {
        didSet {
            if exercises.isEmpty {
                updateMusclesForCategory()
            }
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
    
    struct ExerciseGroup {
        let name: String
        var exercises: [ExerciseEntry]
    }
    
    // MARK: - Performance / Autosave Logic
    
    @ObservationIgnored private var autosaveTask: Task<Void, Error>?

    // MARK: - Initializer
    init(workoutToEdit: Workout? = nil) {
        self.currentWorkout = workoutToEdit
        
        if let workout = workoutToEdit {
            self.date = workout.date
            self.category = workout.category
            self.selectedMuscles = Set(workout.muscleGroups)
            self.note = workout.note
            
            // 1. Sort existing exercises by sortOrder
            let sortedExercises = (workout.exercises ?? []).sorted { $0.sortOrder < $1.sortOrder }
            
            self.exercises = sortedExercises.map { ex in
                let newEntry = ExerciseEntry(
                    name: ex.name,
                    reps: ex.reps,
                    weight: ex.weight,
                    duration: ex.duration,
                    distance: ex.distance,
                    isCardio: ex.isCardio,
                    note: ex.note
                )
                // Preserve the order index
                newEntry.sortOrder = ex.sortOrder
                return newEntry
            }
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
            // Insert immediately after the group
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
        
        // 2. Sort template exercises
        let templateExercises = (template.exercises ?? []).sorted { $0.sortOrder < $1.sortOrder }
        
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
        
        // 3. Save order into Template entries
        let templateExercises = exercises.enumerated().map { (index, ex) in
            let t = TemplateExerciseEntry(
                name: ex.name,
                reps: ex.reps,
                weight: ex.weight,
                duration: ex.duration,
                distance: ex.distance,
                isCardio: ex.isCardio,
                note: ex.note
            )
            t.sortOrder = index
            return t
        }
        template.exercises = templateExercises
        context.insert(template)
        newTemplateName = ""
        showSaveTemplateAlert = false
    }
    
    // MARK: - Autosave Scheduling
    
    func scheduleAutosave(context: ModelContext) {
        autosaveTask?.cancel()
        autosaveTask = Task {
            try await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            try Task.checkCancellation()
            await MainActor.run {
                _ = self.saveWorkout(context: context)
                print("Autosave triggered via Debounce")
            }
        }
    }
    
    func forceImmediateSave(context: ModelContext) {
        autosaveTask?.cancel()
        _ = saveWorkout(context: context)
    }

    // MARK: - Core Save Function
    
    func saveWorkout(context: ModelContext, onComplete: (() -> Void)? = nil) -> Workout? {
        
        let validExercises = exercises.filter { ex in
            if ex.isCardio {
                return (ex.distance ?? 0) > 0 || (ex.duration ?? 0) > 0
            } else {
                return (ex.reps ?? 0) > 0
            }
        }
        
        guard !validExercises.isEmpty else {
            onComplete?()
            return nil
        }
        
        // 4. Assign Sort Order based on current Array index
        for (index, exercise) in validExercises.enumerated() {
            exercise.sortOrder = index
        }
        
        let workoutToSave: Workout
        
        if let workout = currentWorkout {
            workoutToSave = workout
            workoutToSave.date = Calendar.current.startOfDay(for: date)
            workoutToSave.category = category
            workoutToSave.muscleGroups = Array(selectedMuscles)
            workoutToSave.note = note
            workoutToSave.exercises = validExercises
            
        } else {
            workoutToSave = Workout(date: date, category: category, muscleGroups: Array(selectedMuscles), note: note)
            workoutToSave.exercises = validExercises
            context.insert(workoutToSave)
            self.currentWorkout = workoutToSave
        }
        
        try? context.save()
        onComplete?()
        return workoutToSave
    }
}
