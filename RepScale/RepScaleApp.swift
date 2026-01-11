import SwiftUI
import SwiftData

@main
struct RepScaleApp: App {
    @StateObject private var healthManager = HealthManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DailyLog.self,
            WeightEntry.self,
            Workout.self,
            ExerciseEntry.self,
            WorkoutTemplate.self,
            TemplateExerciseEntry.self,
            ExerciseDefinition.self,
            GoalPeriod.self,
            UserProfile.self,
            ProgressPhoto.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            LaunchScreenView()
                .environmentObject(healthManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
