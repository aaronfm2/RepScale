import SwiftUI
import SwiftData

@main
struct AdaptiveCalorieTrackerApp: App {
    @StateObject private var healthManager = HealthManager()
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DailyLog.self,
            WeightEntry.self,
            Workout.self,
            ExerciseEntry.self,
            WorkoutTemplate.self,
            TemplateExerciseEntry.self,
            ExerciseDefinition.self // <--- Added
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(healthManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
