import SwiftUI
import SwiftData
import Charts

struct DashboardCardConfig: Identifiable, Codable, Equatable {
    let type: DashboardCardType
    var isVisible: Bool
    var id: String { type.rawValue }
}

// MARK: - Main View
struct DashboardView: View {
    // --- CLOUD SYNC: Source of Truth ---
    @Bindable var profile: UserProfile
    
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \DailyLog.date, order: .forward) private var logs: [DailyLog]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    @EnvironmentObject var healthManager: HealthManager
    @State private var viewModel = DashboardViewModel()
    
    // --- Layout State (Loaded from Profile) ---
    @State private var layout: [DashboardCardConfig] = []
    
    // Time Ranges (Synced via Profile)
    var workoutTimeRange: TimeRange {
        get { TimeRange(rawValue: profile.workoutTimeRange) ?? .thirtyDays }
        nonmutating set { profile.workoutTimeRange = newValue.rawValue }
    }
    
    var weightHistoryTimeRange: TimeRange {
        get { TimeRange(rawValue: profile.weightHistoryTimeRange) ?? .thirtyDays }
        nonmutating set { profile.weightHistoryTimeRange = newValue.rawValue }
    }
    
    // --- Local UI State ---
    @State private var showingSettings = false
    @State private var showingCustomization = false
    @State private var showingMaintenanceInfo = false
    @State private var showingReconfigureGoal = false
    @State private var visibleMethods: Set<String> = []

    // Helper Accessors
    var weightLabel: String { profile.unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    // UPDATED: Reverted to always return blue as requested
    var goalColor: Color {
        return .blue
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Fixed Card (Always Top)
                    targetProgressCard
                    
                    // 2. Movable Cards
                    // FIX: Iterating indices is easier for the compiler than enumerated()
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
                // Leading: Customization
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingCustomization = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.blue)
                    }
                    .spotlightTarget(.dashboardCustomize)
                }
                
                // Trailing: Settings
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.blue)
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
                // FIX: Added 'profile' argument here
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
            // Refresh logic when CloudKit data changes
            .onChange(of: logs) { _, _ in refreshViewModel() }
            .onChange(of: weights) { _, _ in refreshViewModel() }
            .onChange(of: profile.dailyCalorieGoal) { _, _ in refreshViewModel() }
            .onChange(of: profile.targetWeight) { _, _ in refreshViewModel() }
            .onChange(of: profile.estimationMethod) { _, _ in
                refreshViewModel()
                if let method = EstimationMethod(rawValue: profile.estimationMethod) {
                    visibleMethods = [method.displayName]
                }
            }
            .onChange(of: profile.maintenanceCalories) { _, _ in refreshViewModel() }
            .onChange(of: profile.maintenanceTolerance) { _, _ in refreshViewModel() }
            .onChange(of: profile.isCalorieCountingEnabled) { _, _ in refreshViewModel() }
        }
    }

    @ViewBuilder
    private func cardView(for type: DashboardCardType, index: Int, totalCount: Int) -> some View {
        switch type {
        case .projection:
            projectionComparisonCard(index: index, totalCount: totalCount)
        case .weightChange:
            weightChangeCard(index: index, totalCount: totalCount)
        case .weightTrend:
            weightTrendCard(index: index, totalCount: totalCount)
        case .workoutDistribution:
            workoutDistributionCard(index: index, totalCount: totalCount)
        }
    }
    
    // MARK: - Reorder Arrows Component
    @ViewBuilder
    private func reorderArrows(index: Int, totalCount: Int) -> some View {
        HStack(spacing: 4) {
            // Up Arrow
            if index > 0 {
                Button(action: { moveCardUp(index) }) {
                    Image(systemName: "chevron.up")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Down Arrow
            if index < totalCount - 1 {
                Button(action: { moveCardDown(index) }) {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Logic & Persistence
    
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
        
        if visibleMethods.isEmpty {
            if let method = EstimationMethod(rawValue: profile.estimationMethod) {
                visibleMethods = [method.displayName]
            } else {
                visibleMethods = [EstimationMethod.weightTrend30Day.displayName]
            }
        }
        refreshViewModel()
    }
    
    private func loadLayout() {
        // Load layout from the CloudKit Profile JSON string
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
        // Save layout to the CloudKit Profile JSON string
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
        // Build settings from Profile data
        let settings = DashboardSettings(
            dailyGoal: profile.dailyCalorieGoal,
            targetWeight: profile.targetWeight,
            goalType: profile.goalType,
            maintenanceCalories: profile.maintenanceCalories,
            estimationMethod: profile.estimationMethod,
            enableCaloriesBurned: profile.enableCaloriesBurned,
            isCalorieCountingEnabled: profile.isCalorieCountingEnabled
        )
        viewModel.updateMetrics(logs: logs, weights: weights, settings: settings)
    }
    
    // MARK: - Card Definitions
    
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
                            Image(systemName: "gearshape.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
        // UPDATED: Enhanced Visuals (Gradient, Border, Shadow) with Always Blue
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
    
    private func weightChangeCard(index: Int, totalCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Arrows
            HStack {
                Text("Weight Change").font(.headline)
                Spacer()
                reorderArrows(index: index, totalCount: totalCount)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.weightChangeMetrics) { metric in
                    weightChangeCell(for: metric)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private func weightChangeCell(for metric: WeightChangeMetric) -> some View {
        VStack(spacing: 6) {
            Text(metric.period).font(.caption).fontWeight(.medium).foregroundColor(.secondary)
            if let val = metric.value {
                let converted = val.toUserWeight(system: profile.unitSystem)
                HStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Text(val > 0 ? "+" : "")
                        Text("\(converted, specifier: "%.1f")")
                        Text(" \(weightLabel)")
                    }
                    .foregroundColor(.primary)
                    if val > 0 { Image(systemName: "arrow.up").foregroundColor(.green).font(.caption).bold() }
                    else if val < 0 { Image(systemName: "arrow.down").foregroundColor(.red).font(.caption).bold() }
                }
                .font(.title3).fontWeight(.bold)
            } else {
                Text("--").font(.title3).fontWeight(.bold).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
    }
    
    private func checkGoalReached(current: Double) -> Bool {
        if profile.goalType == GoalType.cutting.rawValue { return current <= profile.targetWeight }
        else if profile.goalType == GoalType.bulking.rawValue { return current >= profile.targetWeight }
        else { return abs(current - profile.targetWeight) <= profile.maintenanceTolerance }
    }
    
    private func projectionComparisonCard(index: Int, totalCount: Int) -> some View {
        let currentWeightKg = weights.first?.weight ?? 0
        let currentDisplay = currentWeightKg.toUserWeight(system: profile.unitSystem)
        let targetDisplay = profile.targetWeight.toUserWeight(system: profile.unitSystem)
        let toleranceDisplay = profile.maintenanceTolerance.toUserWeight(system: profile.unitSystem)
        
        let projections = viewModel.projectionPoints.filter { visibleMethods.contains($0.method) }
            .map { ProjectionPoint(date: $0.date, weight: $0.weight.toUserWeight(system: profile.unitSystem), method: $0.method) }
        
        let allValues = projections.map { $0.weight } + [currentDisplay, targetDisplay]
        let lowerBound = max(0, (allValues.min() ?? 0) - 5)
        let upperBound = (allValues.max() ?? 100) + 5
        
        let methodColors: [EstimationMethod: Color] = [.weightTrend30Day: .blue, .currentEatingHabits: .purple, .perfectGoalAdherence: .orange]
        var baseMapping: [String: Color] = [:]
        for method in EstimationMethod.allCases { baseMapping[method.displayName] = methodColors[method] }
        
        let activeKeys = EstimationMethod.allCases.map { $0.displayName }.filter { visibleMethods.contains($0) }
        let activeColors = activeKeys.compactMap { baseMapping[$0] }
        
        return VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Projections (\(weightLabel))").font(.headline)
                    Text("Estimated weight over next 60 days").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                
                // Moved Menu BEFORE Arrows to push arrows to far right
                Menu {
                    Text("Visible Projections")
                    ForEach(EstimationMethod.allCases) { method in
                        if profile.isCalorieCountingEnabled || method == .weightTrend30Day {
                            Toggle(method.displayName, isOn: bindingForMethod(method.displayName))
                        }
                    }
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.title3).foregroundStyle(.primary).padding(8).background(Color.gray.opacity(0.1)).clipShape(Circle())
                }
                
                reorderArrows(index: index, totalCount: totalCount)
            }
            .padding(.bottom, 8)
            
            if currentWeightKg > 0 {
                Chart {
                    RuleMark(y: .value("Target", targetDisplay)).foregroundStyle(.green).lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .annotation(position: .top, alignment: .leading) { Text("Target").font(.caption).foregroundColor(.green) }
                    if profile.goalType == GoalType.maintenance.rawValue {
                        RuleMark(y: .value("Upper", targetDisplay + toleranceDisplay)).foregroundStyle(.green.opacity(0.3))
                        RuleMark(y: .value("Lower", targetDisplay - toleranceDisplay)).foregroundStyle(.green.opacity(0.3))
                    }
                    ForEach(projections) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Weight", point.weight))
                            .foregroundStyle(by: .value("Method", point.method))
                            .interpolationMethod(.catmullRom).lineStyle(StrokeStyle(lineWidth: 3))
                    }
                }
                .chartForegroundStyleScale(domain: activeKeys, range: activeColors)
                .chartLegend(.hidden)
                .frame(height: 250)
                .chartYScale(domain: lowerBound...upperBound)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 14)) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month().day()) }
                }
                if !activeKeys.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Projection Method").font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(activeKeys, id: \.self) { key in
                                HStack(spacing: 6) {
                                    Circle().fill(baseMapping[key] ?? .gray).frame(width: 8, height: 8)
                                    Text(key).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }.padding(.top, 10)
                }
            } else {
                Text("Log weight to see projections").frame(maxWidth: .infinity, alignment: .center).padding().font(.caption).foregroundColor(.secondary)
            }
        }
        .padding().background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private func bindingForMethod(_ method: String) -> Binding<Bool> {
        Binding(get: { visibleMethods.contains(method) }, set: { if $0 { visibleMethods.insert(method) } else { visibleMethods.remove(method) } })
    }
    
    private func workoutDistributionCard(index: Int, totalCount: Int) -> some View {
        // Filter Logic
        let filteredWorkouts: [Workout]
        if let startDate = workoutTimeRange.startDate(from: Date()) {
            filteredWorkouts = workouts.filter { $0.date >= startDate }
        } else {
            filteredWorkouts = workouts
        }
        
        let counts = Dictionary(grouping: filteredWorkouts, by: { $0.category }).mapValues { $0.count }
        let data = counts.sorted(by: { $0.value > $1.value }).map { (cat: $0.key, count: $0.value) }

        return VStack(alignment: .leading) {
            // Header with Arrows and Menu
            HStack {
                Text("Workout Focus").font(.headline)
                Spacer()
                
                // Moved Menu BEFORE Arrows to push arrows to far right
                Menu {
                    ForEach(TimeRange.allCases) { range in
                        Button(action: {
                            self.workoutTimeRange = range
                        }) {
                            Label(range.rawValue, systemImage: workoutTimeRange == range ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(workoutTimeRange.rawValue)
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1), in: Capsule())
                }
                
                reorderArrows(index: index, totalCount: totalCount)
            }
            .padding(.bottom, 4)
            
            if data.isEmpty {
                Text("No workouts logged in this period.").font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center).padding()
            } else {
                HStack(spacing: 20) {
                    Chart(data, id: \.cat) { item in
                        SectorMark(angle: .value("Count", item.count), innerRadius: .ratio(0.6), angularInset: 2).cornerRadius(5).foregroundStyle(byCategoryColor(item.cat))
                    }.frame(height: 150).frame(maxWidth: 150)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(data, id: \.cat) { item in
                            HStack {
                                Circle().fill(byCategoryColor(item.cat)).frame(width: 8, height: 8)
                                Text(item.cat).font(.caption).foregroundColor(.primary)
                                Spacer()
                                Text("\(item.count)").font(.caption).bold().foregroundColor(.secondary)
                            }
                        }
                    }.frame(maxWidth: .infinity)
                }
            }
        }.padding().background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private func weightTrendCard(index: Int, totalCount: Int) -> some View {
        // --- 1. FILTER HISTORY ---
        let filteredWeights: [WeightEntry]
        if let startDate = weightHistoryTimeRange.startDate(from: Date()) {
            filteredWeights = weights.filter { $0.date >= startDate }
        } else {
            filteredWeights = weights
        }
        
        let history = filteredWeights.map { (date: $0.date, weight: $0.weight.toUserWeight(system: profile.unitSystem)) }
        let allWeights = history.map { $0.weight }
        let lowerBound = max(0, (allWeights.min() ?? 0) - 5)
        let upperBound = (allWeights.max() ?? 100) + 5
        
        return VStack(alignment: .leading) {
            // Header with Arrows
            HStack {
                Text("Weight History (\(weightLabel))").font(.headline)
                Spacer()
                
                // --- 2. TIME RANGE MENU ---
                Menu {
                    ForEach(TimeRange.allCases) { range in
                        Button(action: {
                            self.weightHistoryTimeRange = range
                        }) {
                            Label(range.rawValue, systemImage: weightHistoryTimeRange == range ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(weightHistoryTimeRange.rawValue)
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1), in: Capsule())
                }
                
                reorderArrows(index: index, totalCount: totalCount)
            }
            .padding(.bottom, 4) // Spacing below header
            
            if filteredWeights.isEmpty {
                Text("No weight data available for this period.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart {
                    ForEach(history.sorted(by: { $0.date < $1.date }), id: \.date) { item in
                        AreaMark(x: .value("Date", item.date), yStart: .value("Base", lowerBound), yEnd: .value("Weight", item.weight))
                            .interpolationMethod(.catmullRom).foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .blue.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Date", item.date), y: .value("Weight", item.weight))
                            .interpolationMethod(.catmullRom).foregroundStyle(.blue).symbol { Circle().fill(.blue).frame(width: 6, height: 6) }
                    }
                }
                .frame(height: 180).chartYScale(domain: lowerBound...upperBound).chartXScale(domain: .automatic(includesZero: false))
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month().day()) } }
                .clipped()
            }
        }.padding().background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private func byCategoryColor(_ cat: String) -> Color {
        switch cat.lowercased() {
        case "push": return .red; case "pull": return .blue; case "legs": return .green; case "cardio": return .orange
        case "full body": return .purple; case "upper": return .teal; case "lower": return .brown; default: return .gray
        }
    }
}

// MARK: - Customization Sheet
struct CustomizationSheet: View {
    @Binding var layout: [DashboardCardConfig]
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($layout.indices, id: \.self) { index in
                        Toggle(isOn: $layout[index].isVisible) {
                            Text(layout[index].type.rawValue)
                                .fontWeight(.medium)
                        }
                    }
                } header: {
                    Text("Visible Cards")
                } footer: {
                    Text("Toggle which cards appear on your dashboard. Use the arrows on the cards themselves to reorder them.")
                }
            }
            .navigationTitle("Dashboard Layout")
            .toolbar {
                Button("Done") {
                    onSave()
                    dismiss()
                }
            }
        }
    }
}
