import Foundation
import SwiftData
import SwiftUI

struct DefaultExercises {
    static let all: [ExerciseDefinition] = [
        // --- CHEST ---
        ExerciseDefinition(name: "Barbell Bench Press", muscleGroups: ["Chest", "Triceps"]),
        ExerciseDefinition(name: "Barbell Incline Bench Press", muscleGroups: ["Chest", "Triceps"]),
        ExerciseDefinition(name: "Dumbbell Incline Bench Press", muscleGroups: ["Chest", "Triceps"]),
        ExerciseDefinition(name: "Dumbbell Bench Press", muscleGroups: ["Chest", "Triceps"]),
        ExerciseDefinition(name: "Dumbbell Fly", muscleGroups: ["Chest", "Triceps"]),
        ExerciseDefinition(name: "Push Up", muscleGroups: ["Chest", "Triceps", "Shoulders"]),
        ExerciseDefinition(name: "Cable Fly", muscleGroups: ["Chest"]),
        ExerciseDefinition(name: "Dips", muscleGroups: ["Chest", "Triceps"]),
        
        // --- BACK ---
        ExerciseDefinition(name: "Pull Up", muscleGroups: ["Back", "Biceps"]),
        ExerciseDefinition(name: "Lat Pulldown", muscleGroups: ["Back", "Biceps"]),
        ExerciseDefinition(name: "Barbell Row", muscleGroups: ["Back", "Biceps"]),
        ExerciseDefinition(name: "Deadlift", muscleGroups: ["Back", "Legs"]),
        ExerciseDefinition(name: "Face Pull", muscleGroups: ["Back", "Shoulders"]),
        
        // --- LEGS ---
        ExerciseDefinition(name: "Barbell Squat", muscleGroups: ["Legs"]),
        ExerciseDefinition(name: "Leg Press", muscleGroups: ["Legs"]),
        ExerciseDefinition(name: "Romanian Deadlift", muscleGroups: ["Legs", "Back"]),
        ExerciseDefinition(name: "Walking Lunge", muscleGroups: ["Legs"]),
        ExerciseDefinition(name: "Leg Extension", muscleGroups: ["Legs"]),
        ExerciseDefinition(name: "Seated Leg Curl", muscleGroups: ["Legs"]),
        ExerciseDefinition(name: "Calf Raise", muscleGroups: ["Legs"]),
        
        // --- SHOULDERS ---
        ExerciseDefinition(name: "Overhead Press", muscleGroups: ["Shoulders", "Triceps"]),
        ExerciseDefinition(name: "Lateral Raise", muscleGroups: ["Shoulders"]),
        ExerciseDefinition(name: "Dumbbell Shoulder Press", muscleGroups: ["Shoulders", "Triceps"]),
        ExerciseDefinition(name: "Front Raise", muscleGroups: ["Shoulders"]),
        
        // --- ARMS ---
        ExerciseDefinition(name: "Barbell Bicep Curl", muscleGroups: ["Biceps"]),
        ExerciseDefinition(name: "Hammer Curl", muscleGroups: ["Biceps"]),
        ExerciseDefinition(name: "Tricep Pushdown", muscleGroups: ["Triceps"]),
        ExerciseDefinition(name: "Skullcrusher", muscleGroups: ["Triceps"]),
        ExerciseDefinition(name: "Preacher Curl", muscleGroups: ["Biceps"]),
        
        // --- ABS ---
        ExerciseDefinition(name: "Plank", muscleGroups: ["Abs"]),
        ExerciseDefinition(name: "Crunch", muscleGroups: ["Abs"]),
        ExerciseDefinition(name: "Hanging Leg Raise", muscleGroups: ["Abs"]),
        ExerciseDefinition(name: "Russian Twist", muscleGroups: ["Abs"]),
        
        // --- CARDIO ---
        ExerciseDefinition(name: "Running", muscleGroups: ["Cardio"], isCardio: true),
        ExerciseDefinition(name: "Cycling", muscleGroups: ["Cardio"], isCardio: true),
        ExerciseDefinition(name: "Rowing", muscleGroups: ["Cardio", "Back"], isCardio: true),
        ExerciseDefinition(name: "Jump Rope", muscleGroups: ["Cardio"], isCardio: true),
        ExerciseDefinition(name: "Swimming", muscleGroups: ["Cardio"], isCardio: true)
    ]
    
    /// Checks if defaults have been added using Keychain persistence.
    @MainActor
    static func seed(context: ModelContext) {
        // 1. Check Keychain via Manager. This survives app deletion/reinstall.
        // If true, it means we have seeded before, so we do NOTHING and let CloudKit sync.
        if KeychainManager.standard.hasSeededDefaultExercises() {
            print("Keychain says we have seeded before. Skipping to avoid duplicates.")
            return
        }
        
        // 2. Fallback Check: Database
        // If the keychain is empty (weird edge case) but DB has data, mark keychain and skip.
        let descriptor = FetchDescriptor<ExerciseDefinition>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        
        if count > 0 {
            print("Database has exercises. Marking Keychain and skipping.")
            KeychainManager.standard.setSeededDefaultExercises()
            return
        }
        
        // 3. Only seed if BOTH Keychain and DB are empty (New User)
        print("Seeding default exercises...")
        
        for exercise in all {
            context.insert(exercise)
        }
        
        // Save context and update Keychain
        do {
            try context.save()
            KeychainManager.standard.setSeededDefaultExercises()
            // Legacy flag update just in case
            UserDefaults.standard.set(true, forKey: "hasSeededDefaultExercises")
        } catch {
            print("Failed to seed exercises: \(error)")
        }
    }
}
