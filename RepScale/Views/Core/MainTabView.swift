import SwiftUI
import SwiftData

struct MainTabView: View {
    // --- CLOUD SYNC: Profile passed from RootView ---
    @Bindable var profile: UserProfile
    
    // Tracks the step index for the CURRENT tab's tutorial
    @State private var currentStepIndex = 0
    @State private var selectedTab = 0
    
    @State private var spotlightRects: [String: CGRect] = [:]
    
    private let tutorialSteps: [TutorialStep] = [
        // DASHBOARD STEPS (Tab 0)
        TutorialStep(
            id: 0,
            title: "Dashboard Tab",
            description: "This is your main dashboard. It shows your weight trends, nutrition, strength, and goal projections.",
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
            description: "Click the logs tab and allow Apple Health to sync nutrition. If you use other apps which write to Apple Health (like MyFitnessPal) and wish to sync that data.",
            tabIndex: 0,
            highlights: []
        ),
        
        // LOGS STEPS (Tab 1)
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
        
        // WORKOUTS STEPS (Tab 2)
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
        
        // WEIGHT STEPS (Tab 3)
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
    
    // Computed property: Get steps only for the currently selected tab
    var currentTabSteps: [TutorialStep] {
        tutorialSteps.filter { $0.tabIndex == selectedTab }
    }
    
    // Computed property: Should we show the tutorial for this tab?
    var showTutorial: Bool {
        if currentTabSteps.isEmpty { return false }
        
        switch selectedTab {
        case 0: return !profile.hasSeenDashboardTutorial
        case 1: return !profile.hasSeenLogsTutorial
        case 2: return !profile.hasSeenWorkoutsTutorial
        case 3: return !profile.hasSeenWeightTutorial
        default: return false
        }
    }
    
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

                // --- NEW PROFILE TAB ---
                ProfileView(profile: profile)
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                    .tag(4)
            }
            // Fix: Force Bottom Tabs on iPad
            .environment(\.horizontalSizeClass, .compact)
            // Reset the step index whenever the user switches tabs
            .onChange(of: selectedTab) { _, _ in
                currentStepIndex = 0
            }

            // Show tutorial if active for this tab
            if showTutorial {
                // Safety check to ensure index is valid for current tab steps
                if currentStepIndex < currentTabSteps.count {
                    TutorialOverlayView(
                        step: currentTabSteps[currentStepIndex],
                        spotlightRects: spotlightRects,
                        onNext: {
                            withAnimation {
                                if currentStepIndex < currentTabSteps.count - 1 {
                                    currentStepIndex += 1
                                }
                            }
                        },
                        onFinish: {
                            withAnimation {
                                markCurrentTabAsSeen()
                            }
                        },
                        isLastStep: currentStepIndex == currentTabSteps.count - 1
                    )
                    .zIndex(10)
                    .ignoresSafeArea()
                }
            }
        }
        .coordinateSpace(name: "TutorialSpace")
        .onPreferenceChange(SpotlightRectsKey.self) { prefs in
            self.spotlightRects = prefs
        }
    }

    private func markCurrentTabAsSeen() {
        switch selectedTab {
        case 0: profile.hasSeenDashboardTutorial = true
        case 1: profile.hasSeenLogsTutorial = true
        case 2: profile.hasSeenWorkoutsTutorial = true
        case 3: profile.hasSeenWeightTutorial = true
        default: break
        }
    }
}