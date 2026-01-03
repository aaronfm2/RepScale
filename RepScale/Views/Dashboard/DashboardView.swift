import SwiftUI
import SwiftData
import Charts

struct DashboardCardConfig: Identifiable, Codable, Equatable {
    let type: DashboardCardType
    var isVisible: Bool
    var id: String { type.rawValue }
}

struct DashboardView: View {
    @Bindable var profile: UserProfile
    
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \DailyLog.date, order: .forward) private var logs: [DailyLog]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    @EnvironmentObject var healthManager: HealthManager
    @State private var viewModel = DashboardViewModel()
    
    @State private var layout: [DashboardCardConfig] = []
    
    @State private var showingSettings = false
    @State private var showingCustomization = false
    @State private var showingMaintenanceInfo = false
    @State private var showingReconfigureGoal = false
    @State private var showingGoalEdit = false

    var weightLabel: String { profile.unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var goalColor: Color { .blue }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    targetProgressCard
                    
                    ForEach(layout.indices, id: \.self) { index in
                        let card = layout[index]
                        if card.isVisible {
                            cardView(for: card.type, index: index, totalCount: layout.count)
                        }
                    }
                }
                .padding()
                .animation(.spring(duration: 0.3), value: layout)
            }
            .background(appBackgroundColor)
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingCustomization = true }) {
                        Image(systemName: "slider.horizontal.3").foregroundColor(.blue)
                    }
                    .spotlightTarget(.dashboardCustomize)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill").foregroundColor(.blue)
                    }
                    .spotlightTarget(.settings)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    profile: profile,
                    estimatedMaintenance: viewModel.estimatedMaintenance,
                    currentWeight: weights.first?.weight
                )
            }
            .sheet(isPresented: $showingCustomization) {
                CustomizationSheet(layout: $layout, onSave: saveLayout)
            }
            .sheet(isPresented: $showingReconfigureGoal) {
                GoalConfigurationView(
                    profile: profile,
                    appEstimatedMaintenance: viewModel.estimatedMaintenance,
                    latestWeightKg: weights.first?.weight
                )
            }
            .alert("About Estimated Maintenance", isPresented: $showingMaintenanceInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This is based on your weight change and your calories consumed over the last 30 days. Please note this number should only be used as a guide.")
            }
            .onAppear(perform: setupOnAppear)
            .onChange(of: logs) { _, _ in refreshViewModel() }
            .onChange(of: weights) { _, _ in refreshViewModel() }
            .onChange(of: workouts) { _, _ in refreshViewModel() }
            .onChange(of: profile.dailyCalorieGoal) { _, _ in refreshViewModel() }
            .onChange(of: profile.targetWeight) { _, _ in refreshViewModel() }
            .onChange(of: profile.weeklyWorkoutGoal) { _, _ in refreshViewModel() }
            .onChange(of: profile.estimationMethod) { _, _ in refreshViewModel() }
            .onChange(of: profile.maintenanceCalories) { _, _ in refreshViewModel() }
            .onChange(of: profile.maintenanceTolerance) { _, _ in refreshViewModel() }
            .onChange(of: profile.isCalorieCountingEnabled) { _, _ in refreshViewModel() }
        }
    }

    @ViewBuilder
    private func cardView(for type: DashboardCardType, index: Int, totalCount: Int) -> some View {
        switch type {
        // Weight Cards
        case .projection:
            ProjectionComparisonCard(
                profile: profile, viewModel: viewModel, weights: weights,
                index: index, totalCount: totalCount,
                onMoveUp: { moveCardUp(index) }, onMoveDown: { moveCardDown(index) }
            )
        case .weightChange:
            WeightChangeCard(
                profile: profile, viewModel: viewModel,
                index: index, totalCount: totalCount,
                onMoveUp: { moveCardUp(index) }, onMoveDown: { moveCardDown(index) }
            )
        case .weightTrend:
            WeightTrendCard(
                profile: profile, weights: weights,
                index: index, totalCount: totalCount,
                onMoveUp: { moveCardUp(index) }, onMoveDown: { moveCardDown(index) }
            )
            
        // Workout Cards
        case .workoutDistribution:
            WorkoutDistributionCard(
                profile: profile, workouts: workouts,
                index: index, totalCount: totalCount,
                onMoveUp: { moveCardUp(index) }, onMoveDown: { moveCardDown(index) }
            )
        case .weeklyWorkoutGoal:
            WeeklyGoalCard(
                profile: profile, viewModel: viewModel,
                index: index, totalCount: totalCount,
                onMoveUp: { moveCardUp(index) }, onMoveDown: { moveCardDown(index) }
            )
        case .strengthTracker:
            StrengthTrackerCard(
                profile: profile, workouts: workouts,
                index: index, totalCount: totalCount,
                onMoveUp: { moveCardUp(index) }, onMoveDown: { moveCardDown(index) }
            )
        case .volumeTracker:
                VolumeTrackerCard(
                    profile: profile, workouts: workouts,
                    index: index, totalCount: totalCount,
                    onMoveUp: { moveCardUp(index) }, onMoveDown: { moveCardDown(index) }
                )
        // Nutrition Cards
        case .nutrition:
            NutritionHistoryCard(
                profile: profile,
                index: index, totalCount: totalCount,
                onMoveUp: { moveCardUp(index) }, onMoveDown: { moveCardDown(index) }
            )
        case .macroDistribution:
                MacrosDistributionCard(
                    profile: profile,
                    index: index, totalCount: totalCount,
                    onMoveUp: { moveCardUp(index) }, onMoveDown: { moveCardDown(index) }
                )
        }
    }
    
    private func moveCardUp(_ index: Int) {
        guard index > 0 else { return }
        withAnimation { layout.swapAt(index, index - 1) }
        saveLayout()
    }
    
    private func moveCardDown(_ index: Int) {
        guard index < layout.count - 1 else { return }
        withAnimation { layout.swapAt(index, index + 1) }
        saveLayout()
    }
    
    private func setupOnAppear() {
        healthManager.fetchAllHealthData()
        ensureDailyLogExists()
        loadLayout()
        
        // Default strength exercise initialization
        if profile.strengthGraphExercise.isEmpty {
            // Find most recent exercise, or default to a common one
            if let recent = workouts.first?.exercises?.first?.name {
                profile.strengthGraphExercise = recent
            }
        }
        
        refreshViewModel()
    }
    
    private func loadLayout() {
        if let data = profile.dashboardLayoutJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([DashboardCardConfig].self, from: data),
           !decoded.isEmpty {
            let validConfigs = decoded.filter { DashboardCardType(rawValue: $0.id) != nil }
            let existingTypes = Set(validConfigs.map { $0.type })
            let missing = DashboardCardType.allCases.filter { !existingTypes.contains($0) }
            self.layout = validConfigs + missing.map { DashboardCardConfig(type: $0, isVisible: true) }
        } else {
            self.layout = DashboardCardType.allCases.map { DashboardCardConfig(type: $0, isVisible: true) }
        }
    }
    
    private func saveLayout() {
        if let data = try? JSONEncoder().encode(layout),
           let json = String(data: data, encoding: .utf8) {
            profile.dashboardLayoutJSON = json
        }
    }

    private func ensureDailyLogExists() {
        let today = Calendar.current.startOfDay(for: Date())
        if !logs.contains(where: { $0.date == today }) {
            let newItem = DailyLog(date: today, goalType: profile.goalType)
            modelContext.insert(newItem)
        }
    }
    
    private func refreshViewModel() {
        let settings = DashboardSettings(
            dailyGoal: profile.dailyCalorieGoal,
            targetWeight: profile.targetWeight,
            goalType: profile.goalType,
            maintenanceCalories: profile.maintenanceCalories,
            estimationMethod: profile.estimationMethod,
            enableCaloriesBurned: profile.enableCaloriesBurned,
            isCalorieCountingEnabled: profile.isCalorieCountingEnabled
        )
        viewModel.updateMetrics(
            logs: logs,
            weights: weights,
            settings: settings,
            workouts: workouts,
            weeklyGoal: profile.weeklyWorkoutGoal
        )
    }
    
    private var targetProgressCard: some View {
        let currentWeightKg = weights.first?.weight
        let currentDisplay = currentWeightKg?.toUserWeight(system: profile.unitSystem)
        let targetDisplay = profile.targetWeight.toUserWeight(system: profile.unitSystem)
        let toleranceDisplay = profile.maintenanceTolerance.toUserWeight(system: profile.unitSystem)
        
        return VStack(spacing: 16) {
            if let current = currentDisplay, let rawCurrent = currentWeightKg, rawCurrent > 0 {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Weight").font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(current, specifier: "%.1f")")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(goalColor)
                            Text(weightLabel).font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Button(action: { showingReconfigureGoal = true }) {
                            Image(systemName: "gearshape.fill").font(.caption).foregroundColor(.secondary)
                        }
                        .offset(x: 6, y: -10)
                        
                        Text("Goal (\(profile.goalType))").font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(targetDisplay, specifier: "%.1f")").font(.title3).fontWeight(.semibold).foregroundStyle(goalColor)
                            Text(weightLabel).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                Divider()
                if checkGoalReached(current: rawCurrent) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(goalColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Target Reached").font(.headline).foregroundColor(.primary)
                            if profile.goalType == GoalType.maintenance.rawValue {
                                Text("Within \(toleranceDisplay, specifier: "%.1f") \(weightLabel)").font(.caption).foregroundColor(.secondary)
                            } else {
                                Text("Great work!").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                } else {
                    if let daysLeft = viewModel.daysRemaining {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Estimated Time").font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(daysLeft)").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(goalColor)
                                    Text("days").font(.body).fontWeight(.medium).foregroundColor(.secondary)
                                }
                                Text(viewModel.logicDescription).font(.caption2).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "hourglass").font(.system(size: 36)).foregroundStyle(goalColor.opacity(0.3))
                        }
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Estimate Unavailable").font(.headline).foregroundColor(.primary)
                                Text(viewModel.progressWarningMessage).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                    }
                }
            } else {
                Text("Log your weight to see progress").font(.subheadline).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [goalColor.opacity(0.2), goalColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(goalColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: goalColor.opacity(0.15), radius: 10, x: 0, y: 5)
    }
    
    private func checkGoalReached(current: Double) -> Bool {
        if profile.goalType == GoalType.cutting.rawValue { return current <= profile.targetWeight }
        else if profile.goalType == GoalType.bulking.rawValue { return current >= profile.targetWeight }
        else { return abs(current - profile.targetWeight) <= profile.maintenanceTolerance }
    }
}

// MARK: - Improved Customization Sheet
struct CustomizationSheet: View {
    @Binding var layout: [DashboardCardConfig]
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Weight Section
                Section {
                    toggleFor(.projection)
                    toggleFor(.weightChange)
                    toggleFor(.weightTrend)
                } header: {
                    Label("Weight Cards", systemImage: "scalemass")
                }
                
                // MARK: - Workout Section
                Section {
                    toggleFor(.workoutDistribution)
                    toggleFor(.weeklyWorkoutGoal)
                    toggleFor(.strengthTracker)
                } header: {
                    Label("Workout Cards", systemImage: "figure.run")
                }
                
                // MARK: - Nutrition Section
                Section {
                    toggleFor(.nutrition)
                } header: {
                    Label("Nutrition", systemImage: "leaf")
                }
                
                // MARK: - Other / Unclassified
                let unclassified = layout.filter { !isClassified($0.type) }
                if !unclassified.isEmpty {
                    Section(header: Text("Other")) {
                        ForEach(unclassified) { config in
                            toggleFor(config.type)
                        }
                    }
                }
                
                // MARK: - Footer Info
                Section {
                } footer: {
                    Text("Toggle which cards appear on your dashboard. Use the arrows on the cards themselves to reorder them.")
                        .padding(.top, 8)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Customize Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        withAnimation { resetLayout() }
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func toggleFor(_ type: DashboardCardType) -> some View {
        // Find index of this specific type in the layout array
        if let index = layout.firstIndex(where: { $0.type == type }) {
            return AnyView(
                Toggle(isOn: $layout[index].isVisible) {
                    HStack(spacing: 12) {
                        Image(systemName: iconFor(type))
                            .font(.title3)
                            .frame(width: 28)
                            .foregroundStyle(.primary)
                        
                        Text(type.rawValue)
                            .fontWeight(.medium)
                    }
                }
                .tint(.blue)
            )
        } else {
            return AnyView(EmptyView())
        }
    }
    
    private func resetLayout() {
        let defaultLayout = DashboardCardType.allCases.map {
            DashboardCardConfig(type: $0, isVisible: true)
        }
        self.layout = defaultLayout
    }
    
    private func isClassified(_ type: DashboardCardType) -> Bool {
        switch type {
        case .projection, .weightChange, .weightTrend,
                .workoutDistribution, .weeklyWorkoutGoal, .strengthTracker, .volumeTracker, .nutrition, .macroDistribution:
            return true
        }
    }
    
    private func iconFor(_ type: DashboardCardType) -> String {
        switch type {
        case .projection: return "chart.xyaxis.line"
        case .weightChange: return "arrow.up.arrow.down.square"
        case .weightTrend: return "chart.line.uptrend.xyaxis"
        case .workoutDistribution: return "chart.pie.fill"
        case .weeklyWorkoutGoal: return "target"
        case .strengthTracker: return "dumbbell.fill"
        case .volumeTracker: return "chart.bar.fill"
        case .nutrition: return "fork.knife"
        case .macroDistribution: return "chart.pie.fill"
        }
    }
}

// Helper Reusable View
struct ReorderArrows: View {
    let index: Int
    let totalCount: Int
    let onUp: () -> Void
    let onDown: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            if index > 0 {
                Button(action: onUp) {
                    Image(systemName: "chevron.up")
                        .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
                        .padding(6).background(Color.secondary.opacity(0.1)).clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            if index < totalCount - 1 {
                Button(action: onDown) {
                    Image(systemName: "chevron.down")
                        .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
                        .padding(6).background(Color.secondary.opacity(0.1)).clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
