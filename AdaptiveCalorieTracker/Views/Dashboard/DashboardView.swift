import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \DailyLog.date, order: .forward) private var logs: [DailyLog]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    @EnvironmentObject var healthManager: HealthManager
    @State private var viewModel = DashboardViewModel()
    
    // MARK: - App Storage (Dashboard Display)
    @AppStorage("dailyCalorieGoal") private var dailyGoal: Int = 2000
    @AppStorage("targetWeight") private var targetWeight: Double = 70.0
    @AppStorage("goalType") private var goalType: String = "Cutting"
    @AppStorage("maintenanceCalories") private var maintenanceCalories: Int = 2500
    @AppStorage("estimationMethod") private var estimationMethod: Int = 0
    @AppStorage("enableCaloriesBurned") private var enableCaloriesBurned: Bool = true
    @AppStorage("maintenanceTolerance") private var maintenanceTolerance: Double = 2.0
    @AppStorage("unitSystem") private var unitSystem: String = UnitSystem.metric.rawValue
    @AppStorage("isCalorieCountingEnabled") private var isCalorieCountingEnabled: Bool = true
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    
    // MARK: - Local State
    @State private var showingSettings = false
    @State private var showingMaintenanceInfo = false
    @State private var visibleMethods: Set<String> = []

    var weightLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    
    var appBackgroundColor: Color {
        isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    targetProgressCard
                    weightChangeCard
                    projectionComparisonCard
                    weightTrendCard
                    workoutDistributionCard
                }
                .padding()
            }
            .background(appBackgroundColor)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                    .spotlightTarget(.settings)
                }
            }
            // Present the new, separate SettingsView
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    estimatedMaintenance: viewModel.estimatedMaintenance,
                    currentWeight: weights.first?.weight
                )
            }
            .alert("About Estimated Maintenance", isPresented: $showingMaintenanceInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This is based on your weight change and your calories consumed over the last 30 days. Please note this number should only be used as a guide, the accuracy will be dependant on accuracy of calories submitted and small weight fluctuations can impact this value")
            }
            .onAppear(perform: setupOnAppear)
            .onChange(of: logs) { _, _ in refreshViewModel() }
            .onChange(of: weights) { _, _ in refreshViewModel() }
            .onChange(of: dailyGoal) { _, _ in refreshViewModel() }
            .onChange(of: targetWeight) { _, _ in refreshViewModel() }
            .onChange(of: estimationMethod) { _, _ in
                refreshViewModel()
                if let method = EstimationMethod(rawValue: estimationMethod) {
                    visibleMethods = [method.displayName]
                }
            }
            .onChange(of: maintenanceCalories) { _, _ in refreshViewModel() }
            .onChange(of: maintenanceTolerance) { _, _ in refreshViewModel() }
            .onChange(of: isCalorieCountingEnabled) { _, _ in refreshViewModel() }
        }
    }

    // MARK: - View Model Logic

    private func refreshViewModel() {
        let settings = DashboardSettings(
            dailyGoal: dailyGoal,
            targetWeight: targetWeight,
            goalType: goalType,
            maintenanceCalories: maintenanceCalories,
            estimationMethod: estimationMethod,
            enableCaloriesBurned: enableCaloriesBurned,
            isCalorieCountingEnabled: isCalorieCountingEnabled
        )
        viewModel.updateMetrics(logs: logs, weights: weights, settings: settings)
    }
    
    private func setupOnAppear() {
        healthManager.fetchAllHealthData()
        let today = Calendar.current.startOfDay(for: Date())
        if !logs.contains(where: { $0.date == today }) {
            let newItem = DailyLog(date: today, goalType: goalType)
            modelContext.insert(newItem)
        }
        
        if visibleMethods.isEmpty {
            if let method = EstimationMethod(rawValue: estimationMethod) {
                visibleMethods = [method.displayName]
            } else {
                visibleMethods = [EstimationMethod.weightTrend30Day.displayName]
            }
        }
        
        refreshViewModel()
    }
    
    // MARK: - Dashboard Cards
    
    private var weightChangeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weight Change").font(.headline)
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
            Text(metric.period)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if let val = metric.value {
                let converted = val.toUserWeight(system: unitSystem)
                HStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Text(val > 0 ? "+" : "")
                        Text("\(converted, specifier: "%.1f")")
                        Text(" \(weightLabel)")
                    }
                    .foregroundColor(.primary)
                    if val > 0 {
                        Image(systemName: "arrow.up").foregroundColor(.green).font(.caption).bold()
                    } else if val < 0 {
                        Image(systemName: "arrow.down").foregroundColor(.red).font(.caption).bold()
                    }
                }
                .font(.title3)
                .fontWeight(.bold)
            } else {
                Text("--").font(.title3).fontWeight(.bold).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
    }
    
    private var targetProgressCard: some View {
        let currentWeightKg = weights.first?.weight
        let currentDisplay = currentWeightKg?.toUserWeight(system: unitSystem)
        let targetDisplay = targetWeight.toUserWeight(system: unitSystem)
        let toleranceDisplay = maintenanceTolerance.toUserWeight(system: unitSystem)
        
        return VStack(spacing: 12) {
            if let current = currentDisplay, let rawCurrent = currentWeightKg, rawCurrent > 0 {
                VStack(spacing: 4) {
                    Text("Current Weight: \(current, specifier: "%.1f") \(weightLabel)")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Goal: \(targetDisplay, specifier: "%.1f") \(weightLabel) (\(goalType))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if checkGoalReached(current: rawCurrent) {
                    Text("Target Reached!")
                        .font(.title).bold()
                        .foregroundColor(.green)
                    if goalType == GoalType.maintenance.rawValue {
                        Text("Within \(toleranceDisplay, specifier: "%.1f") \(weightLabel) of goal").font(.caption).foregroundColor(.secondary)
                    }
                } else {
                    if let daysLeft = viewModel.daysRemaining {
                        Text("\(daysLeft)").font(.system(size: 60, weight: .bold)).foregroundColor(.orange)
                        Text("Days until target hit").font(.headline)
                        Text(viewModel.logicDescription).font(.caption).foregroundColor(.secondary).padding(.top, 4)
                    } else {
                        Divider().padding(.vertical, 5)
                        Text("Estimate Unavailable").font(.title3).bold()
                        Text(viewModel.progressWarningMessage).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    }
                }
            } else {
                Text("\(goalType): \(targetDisplay, specifier: "%.1f") \(weightLabel)").font(.subheadline).foregroundColor(.secondary)
                Text("No Weight Data").font(.title3).bold().foregroundColor(.secondary)
                Text("Log your weight in the Weight tab").font(.caption).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 15).fill(Color.orange.opacity(0.1)))
    }
    
    private func checkGoalReached(current: Double) -> Bool {
        if goalType == GoalType.cutting.rawValue {
            return current <= targetWeight
        } else if goalType == GoalType.bulking.rawValue {
            return current >= targetWeight
        } else {
            let diff = abs(current - targetWeight)
            return diff <= maintenanceTolerance
        }
    }
    
    private var projectionComparisonCard: some View {
        let currentWeightKg = weights.first?.weight ?? 0
        let currentDisplay = currentWeightKg.toUserWeight(system: unitSystem)
        let targetDisplay = targetWeight.toUserWeight(system: unitSystem)
        let toleranceDisplay = maintenanceTolerance.toUserWeight(system: unitSystem)
        
        let projections = viewModel.projectionPoints
            .filter { visibleMethods.contains($0.method) }
            .map { point in
                ProjectionPoint(date: point.date, weight: point.weight.toUserWeight(system: unitSystem), method: point.method)
            }
        
        let allValues = projections.map { $0.weight } + [currentDisplay, targetDisplay]
        let minW = allValues.min() ?? 0
        let maxW = allValues.max() ?? 100
        let lowerBound = max(0, minW - 5)
        let upperBound = maxW + 5
        
        // Define colors
        let methodColors: [EstimationMethod: Color] = [
            .weightTrend30Day: .blue,
            .currentEatingHabits: .purple,
            .perfectGoalAdherence: .orange
        ]
        
        // Map Display Strings -> Colors
        var baseMapping: [String: Color] = [:]
        for method in EstimationMethod.allCases {
            baseMapping[method.displayName] = methodColors[method]
        }
        
        // Create ordered keys for the legend based on enum order
        let activeKeys = EstimationMethod.allCases
            .map { $0.displayName }
            .filter { visibleMethods.contains($0) }
            
        let activeColors = activeKeys.compactMap { baseMapping[$0] }
        
        return VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Projections (\(weightLabel))").font(.headline)
                    Text("Estimated weight over next 60 days").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                
                Menu {
                    Text("Visible Projections")
                    ForEach(EstimationMethod.allCases) { method in
                        if isCalorieCountingEnabled || method == .weightTrend30Day {
                            Toggle(method.displayName, isOn: bindingForMethod(method.displayName))
                        }
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 8)
            
            if currentWeightKg > 0 {
                Chart {
                    RuleMark(y: .value("Target", targetDisplay))
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Target").font(.caption).foregroundColor(.green)
                        }
                    
                    if goalType == GoalType.maintenance.rawValue {
                        RuleMark(y: .value("Upper", targetDisplay + toleranceDisplay)).foregroundStyle(.green.opacity(0.3))
                        RuleMark(y: .value("Lower", targetDisplay - toleranceDisplay)).foregroundStyle(.green.opacity(0.3))
                    }

                    ForEach(projections) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Weight", point.weight))
                        .foregroundStyle(by: .value("Method", point.method))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                    }
                }
                .chartForegroundStyleScale(domain: activeKeys, range: activeColors)
                .chartLegend(.hidden)
                .frame(height: 250)
                .chartYScale(domain: lowerBound...upperBound)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 14)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                
                // --- Custom Legend ---
                if !activeKeys.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Projection Method")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(activeKeys, id: \.self) { key in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(baseMapping[key] ?? .gray)
                                        .frame(width: 8, height: 8)
                                    Text(key)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                }
                
            } else {
                Text("Log weight to see projections").frame(maxWidth: .infinity, alignment: .center).padding().font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private func bindingForMethod(_ method: String) -> Binding<Bool> {
        Binding(
            get: { visibleMethods.contains(method) },
            set: { shouldShow in
                if shouldShow {
                    visibleMethods.insert(method)
                } else {
                    visibleMethods.remove(method)
                }
            }
        )
    }
    
    private var workoutDistributionCard: some View {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let recentWorkouts = workouts.filter { $0.date >= thirtyDaysAgo }
        let counts = Dictionary(grouping: recentWorkouts, by: { $0.category }).mapValues { $0.count }
        let data = counts.sorted(by: { $0.value > $1.value }).map { (cat: $0.key, count: $0.value) }

        return VStack(alignment: .leading) {
            HStack {
                Text("Workout Focus").font(.headline)
                Spacer()
                Text("Last 30 Days").font(.caption).foregroundColor(.secondary)
            }
            if data.isEmpty {
                Text("No workouts logged recently.").font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center).padding()
            } else {
                HStack(spacing: 20) {
                    Chart(data, id: \.cat) { item in
                        SectorMark(angle: .value("Count", item.count), innerRadius: .ratio(0.6), angularInset: 2)
                            .cornerRadius(5)
                            .foregroundStyle(byCategoryColor(item.cat))
                    }
                    .frame(height: 150).frame(maxWidth: 150)
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
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private var weightTrendCard: some View {
        let history = weights.map { (date: $0.date, weight: $0.weight.toUserWeight(system: unitSystem)) }
        let allWeights = history.map { $0.weight }
        let minW = allWeights.min() ?? 0
        let maxW = allWeights.max() ?? 100
        let lowerBound = max(0, minW - 5)
        let upperBound = maxW + 5
        
        return VStack(alignment: .leading) {
            Text("Weight History (\(weightLabel))").font(.headline)
            if weights.isEmpty {
                Text("No weight data logged yet").font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center).padding()
            } else {
                Chart {
                    ForEach(history.sorted(by: { $0.date < $1.date }), id: \.date) { item in
                        AreaMark(
                            x: .value("Date", item.date),
                            yStart: .value("Base", lowerBound),
                            yEnd: .value("Weight", item.weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .blue.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        LineMark(x: .value("Date", item.date), y: .value("Weight", item.weight))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.blue)
                        .symbol { Circle().fill(.blue).frame(width: 6, height: 6) }
                    }
                }
                .frame(height: 180)
                .chartYScale(domain: lowerBound...upperBound)
                .chartXScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                     AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                         AxisGridLine()
                         AxisTick()
                         AxisValueLabel(format: .dateTime.month().day())
                     }
                 }
                 .clipped()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private func byCategoryColor(_ cat: String) -> Color {
        switch cat.lowercased() {
        case "push": return .red
        case "pull": return .blue
        case "legs": return .green
        case "cardio": return .orange
        case "full body": return .purple
        case "upper": return .teal
        case "lower": return .brown
        default: return .gray
        }
    }
}
