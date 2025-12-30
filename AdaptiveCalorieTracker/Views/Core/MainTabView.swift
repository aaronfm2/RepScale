import SwiftUI
import SwiftData

struct MainTabView: View {
    // --- CLOUD SYNC: Profile passed from RootView ---
    @Bindable var profile: UserProfile
    
    // --- LOCAL STATE: Tutorial status remains local ---
    @AppStorage("hasSeenAppTutorial") private var hasSeenAppTutorial: Bool = false
    
    @State private var currentTutorialStepIndex = 0
    @State private var selectedTab = 0
    
    @State private var spotlightRects: [String: CGRect] = [:]
    
    private let tutorialSteps: [TutorialStep] = [
        TutorialStep(
            id: 0,
            title: "Dashboard Tab",
            description: "This is your main dashboard. It shows your weight trends, calorie balance, and goal projections.",
            tabIndex: 0,
            highlights: [.tab(index: 0)]
        ),
        TutorialStep(
            id: 1,
            title: "Settings",
            description: "Tap the Gear icon to configure your goals, dietary preferences, and calculation methods.",
            tabIndex: 0,
            highlights: [.target(.settings)]
        ),
        TutorialStep(
            id: 2,
            title: "Customize Layout",
            description: "Tap the Sliders icon to customise your dashboard.",
            tabIndex: 0,
            highlights: [.target(.dashboardCustomize)]
        ),
        TutorialStep(
            id: 3,
            title: "Apple Health Sync",
            description: "Sync data from Apple Health. If you use other apps which write to Apple Health (like MyFitnessPal) and want to sync that data.",
            tabIndex: 0,
            highlights: []
        ),
        TutorialStep(
            id: 4,
            title: "Logs Tab",
            description: "Track your daily nutrition here. This data syncs automatically with Apple Health.",
            tabIndex: 1,
            highlights: [.tab(index: 1)]
        ),
        TutorialStep(
            id: 5,
            title: "Add Entries",
            description: "Use the + button to manually add calories or macros.",
            tabIndex: 1,
            highlights: [.target(.addLog)]
        ),
        TutorialStep(
            id: 6,
            title: "Workouts Tab",
            description: "Track your training sessions and view history.",
            tabIndex: 2,
            highlights: [.tab(index: 2)]
        ),
        TutorialStep(
            id: 7,
            title: "Workout Controls",
            description: "Top Right: Start a new workout.\nTop Left: Manage your Exercise Library.",
            tabIndex: 2,
            highlights: [.target(.addWorkout), .target(.library)]
        ),
        TutorialStep(
            id: 8,
            title: "Weight Tab",
            description: "Keep track of your weigh-ins.",
            tabIndex: 3,
            highlights: [.tab(index: 3)]
        ),
        TutorialStep(
            id: 9,
            title: "Phase Stats",
            description: "Review your Bulking, Cutting, and Maintenance phases.",
            tabIndex: 3,
            highlights: [.target(.weightStats)]
        ),
        TutorialStep(
            id: 10,
            title: "Log Weight",
            description: "Tap the + button to log today's weight.",
            tabIndex: 3,
            highlights: [.target(.addWeight)]
        )
    ]
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Pass the profile to DashboardView
                DashboardView(profile: profile)
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                    .tag(0)
                
                // Pass profile to LogTabView
                LogTabView(profile: profile)
                    .tabItem { Label("Logs", systemImage: "list.bullet.clipboard.fill") }
                    .tag(1)
                
                // Pass profile to WorkoutTabView
                WorkoutTabView(profile: profile)
                    .tabItem { Label("Workouts", systemImage: "figure.strengthtraining.traditional") }
                    .tag(2)
                
                WeightTrackerView(profile: profile)
                    .tabItem { Label("Weight", systemImage: "scalemass.fill") }
                    .tag(3)
            }
            // Fix: Force Bottom Tabs on iPad
            .environment(\.horizontalSizeClass, .compact)
            
            if !hasSeenAppTutorial {
                TutorialOverlayView(
                    step: tutorialSteps[currentTutorialStepIndex],
                    spotlightRects: spotlightRects,
                    onNext: {
                        withAnimation {
                            if currentTutorialStepIndex < tutorialSteps.count - 1 {
                                currentTutorialStepIndex += 1
                                selectedTab = tutorialSteps[currentTutorialStepIndex].tabIndex
                            }
                        }
                    },
                    onFinish: {
                        withAnimation { hasSeenAppTutorial = true }
                    },
                    isLastStep: currentTutorialStepIndex == tutorialSteps.count - 1
                )
                .zIndex(10)
                .ignoresSafeArea()
            }
        }
        .coordinateSpace(name: "TutorialSpace")
        .onPreferenceChange(SpotlightRectsKey.self) { prefs in
            self.spotlightRects = prefs
        }
    }
}
