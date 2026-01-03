import Foundation
import SwiftData
import SwiftUI

@Observable
class AddWorkoutViewModel {
    // MARK: - Properties
    
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
    
    /// Tracks the pending autosave task to allow for debouncing (cancelling previous rapid inputs).
    /// Ignored by Observation so changes to this don't trigger View updates.
    @ObservationIgnored private var autosaveTask: Task<Void, Error>?

    // MARK: - Initializer
    init(workoutToEdit: Workout? = nil) {
        if let workout = workoutToEdit {
            self.date = workout.date
            self.category = workout.category
            self.selectedMuscles = Set(workout.muscleGroups)
            self.note = workout.note
            
            // Map exercises to create new unmanaged objects (detached from context for editing)
            self.exercises = (workout.exercises ?? []).map { ex in
                ExerciseEntry(
                    name: ex.name,
                    reps: ex.reps,
                    weight: ex.weight,
                    duration: ex.duration,
                    distance: ex.distance,
                    isCardio: ex.isCardio,
                    note: ex.note
                )
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
                // --- FIX STARTS HERE ---
                // We append a NEW group to the 'groups' array.
                // We do NOT use 'index' here because it is out of scope.
                groups.append(ExerciseGroup(name: exercise.name, exercises: [exercise]))
                // --- FIX ENDS HERE ---
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
    
    // MARK: - Autosave Scheduling
    
    /// Schedules a save to happen after 3 seconds. If called again within that window,
    /// the previous timer is cancelled. This prevents the UI from stuttering on every keystroke.
    func scheduleAutosave(context: ModelContext, originalWorkout: Workout?) {
        // 1. Cancel existing task
        autosaveTask?.cancel()
        
        // 2. Start new task
        autosaveTask = Task {
            // Wait 2 seconds
            try await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            
            // Ensure task wasn't cancelled during the wait
            try Task.checkCancellation()
            
            // Perform save on Main Actor
            await MainActor.run {
                _ = self.saveWorkout(context: context, originalWorkout: originalWorkout)
                print("Autosave triggered via Debounce")
            }
        }
    }
    
    /// Bypasses the debounce timer and saves immediately.
    /// Used when the user taps "Done" or the app goes to the background.
    func forceImmediateSave(context: ModelContext, originalWorkout: Workout?) {
        autosaveTask?.cancel()
        _ = saveWorkout(context: context, originalWorkout: originalWorkout)
    }

    // MARK: - Core Save Function
    
    func saveWorkout(context: ModelContext, originalWorkout: Workout?, onComplete: (() -> Void)? = nil) -> Workout? {
        
        // Filter out empty exercises to prevent saving workouts with no actual data.
        // Strength: Requires > 0 reps. Cardio: Requires > 0 distance or duration.
        let validExercises = exercises.filter { ex in
            if ex.isCardio {
                return (ex.distance ?? 0) > 0 || (ex.duration ?? 0) > 0
            } else {
                return (ex.reps ?? 0) > 0
            }
        }
        
        // If there are no valid exercises, do not save or create the workout.
        guard !validExercises.isEmpty else {
            // If the user tapped "Done" (onComplete provided), we still dismiss the view,
            // but we don't persist the empty workout.
            onComplete?()
            return nil
        }
        
        let workoutToSave: Workout
        
        if let workout = originalWorkout {
            // Update Existing
            workoutToSave = workout
            workoutToSave.date = Calendar.current.startOfDay(for: date)
            workoutToSave.category = category
            workoutToSave.muscleGroups = Array(selectedMuscles)
            workoutToSave.note = note
            
            // Replace exercises with current state
            workoutToSave.exercises = validExercises
            
        } else {
            // Create New
            workoutToSave = Workout(date: date, category: category, muscleGroups: Array(selectedMuscles), note: note)
            workoutToSave.exercises = validExercises
            context.insert(workoutToSave)
        }
        
        // Save to disk
        try? context.save()
        
        // Call completion if provided (e.g., for the "Done" button)
        onComplete?()
        
        return workoutToSave
    }
}
