import SwiftUI
import SwiftData

@main
struct AdaptiveCalorieTrackerApp: App {
    @StateObject private var healthManager = HealthManager()
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    // --- NEW: Dark Mode State ---
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DailyLog.self,
            WeightEntry.self,
            Workout.self,
            ExerciseEntry.self,
            WorkoutTemplate.self,
            TemplateExerciseEntry.self,
            ExerciseDefinition.self,
            GoalPeriod.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // We must run this on the MainActor
            Task { @MainActor in
                DefaultExercises.seed(context: container.mainContext)
            }
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView()
                        .environmentObject(healthManager)
                } else {
                    OnboardingView(isCompleted: $hasCompletedOnboarding)
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .modelContainer(sharedModelContainer)
    }
}
