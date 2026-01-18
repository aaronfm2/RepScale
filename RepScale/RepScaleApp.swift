import SwiftUI
import SwiftData
import RevenueCat

@main
struct RepScaleApp: App {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var subscriptionManager = SubscriptionManager.shared 
    
    init() {
        SubscriptionManager.shared.configure()
    }
    
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
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
                .environmentObject(subscriptionManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
