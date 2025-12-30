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
            ExerciseDefinition.self,
            GoalPeriod.self,
            UserProfile.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
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
            RootView()
                .environmentObject(healthManager)
        }
        .modelContainer(sharedModelContainer)
    }
}

struct RootView: View {
    @Query var userProfiles: [UserProfile]
    // Note: 'hasSeenAppTutorial' stays in AppStorage so it resets on re-install
    @AppStorage("hasSeenAppTutorial") private var hasSeenAppTutorial: Bool = false
    
    var body: some View {
        Group {
            if let profile = userProfiles.first {
                MainTabView(profile: profile)
                    .preferredColorScheme(profile.isDarkMode ? .dark : .light)
            } else {
                OnboardingView()
            }
        }
    }
}
