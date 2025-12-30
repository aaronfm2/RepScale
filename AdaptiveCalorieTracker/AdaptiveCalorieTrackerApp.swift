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
    // Note: 'hasSeenAppTutorial' stays in AppStorage so it resets on re-install if you want,
    // or you can move it to keychain too if you want that to persist.
    @AppStorage("hasSeenAppTutorial") private var hasSeenAppTutorial: Bool = false
    
    var body: some View {
        Group {
            if let profile = userProfiles.first {
                // Scenario 1: Data is loaded. Show App.
                MainTabView(profile: profile)
                    .preferredColorScheme(profile.isDarkMode ? .dark : .light)
                    
            } else if KeychainManager.standard.isOnboardingComplete() {
                // Scenario 2: User HAS been here before, but data is syncing. Show Loading.
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Restoring your profile...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
            } else {
                // Scenario 3: Truly new user. Show Onboarding.
                OnboardingView()
            }
        }
    }
}
