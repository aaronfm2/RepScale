import SwiftUI

struct MainTabView: View {
    // --- Tutorial State ---
    @AppStorage("hasSeenAppTutorial") private var hasSeenAppTutorial: Bool = false
    @State private var currentTutorialStepIndex = 0
    @State private var selectedTab = 0
    
    // --- UPDATED STEPS ---
    private let tutorialSteps: [TutorialStep] = [
        // 1. Dashboard -> Highlights Tab 0
        TutorialStep(
            id: 0,
            title: "Dashboard Tab",
            description: "This is your main dashboard. It shows your weight trends, calorie balance, and goal projections.",
            tabIndex: 0,
            highlights: [.tab(index: 0)] // Changed from .center
        ),
        // 2. Dashboard -> Highlights Settings
        TutorialStep(
            id: 1,
            title: "Settings",
            description: "Tap the Gear icon to configure your goals, dietary preferences, and calculation methods.",
            tabIndex: 0,
            highlights: [.topLeft]
        ),
        
        // 3. Logs -> Highlights Tab 1
        TutorialStep(
            id: 2,
            title: "Logs Tab",
            description: "Track your daily nutrition here. This data syncs automatically with Apple Health.",
            tabIndex: 1,
            highlights: [.tab(index: 1)] // Changed from .center
        ),
        // 4. Logs -> Highlights Add Button
        TutorialStep(
            id: 3,
            title: "Add Entries",
            description: "Use the + button to manually add calories or macros if you need to correct your data.",
            tabIndex: 1,
            highlights: [.topRight]
        ),

        // 5. Workouts -> Highlights Tab 2
        TutorialStep(
            id: 4,
            title: "Workouts Tab",
            description: "Track your training sessions, view history, and manage your exercise library.",
            tabIndex: 2,
            highlights: [.tab(index: 2)] // Changed from .center
        ),
        // 6. Workouts -> Highlights Top Controls
        TutorialStep(
            id: 5,
            title: "Workout Controls",
            description: "Top Right: Start a new workout.\nTop Left: Manage your Exercise Library.",
            tabIndex: 2,
            highlights: [.topRight, .topLeft]
        ),

        // 7. Weight -> Highlights Tab 3
        TutorialStep(
            id: 6,
            title: "Weight Tab",
            description: "Keep track of your weigh-ins here to visualize your progress over time.",
            tabIndex: 3,
            highlights: [.tab(index: 3)] // Changed from .center
        ),
        // 8. Weight -> Highlights Add Button
        TutorialStep(
            id: 7,
            title: "Log Weight",
            description: "Tap the + button to log today's weight.",
            tabIndex: 3,
            highlights: [.topRight]
        )
    ]
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardView().tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }.tag(0)
                ContentView().tabItem { Label("Logs", systemImage: "list.bullet.clipboard.fill") }.tag(1)
                WorkoutTabView().tabItem { Label("Workouts", systemImage: "figure.strengthtraining.traditional") }.tag(2)
                WeightTrackerView().tabItem { Label("Weight", systemImage: "scalemass.fill") }.tag(3)
            }
            
            // --- Tutorial Overlay ---
            if !hasSeenAppTutorial {
                TutorialOverlayView(
                    step: tutorialSteps[currentTutorialStepIndex],
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
            }
        }
    }
}
