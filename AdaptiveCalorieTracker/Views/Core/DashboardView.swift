import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    // ... [Keep existing Queries] ...
    @Query(sort: \DailyLog.date, order: .forward) private var logs: [DailyLog]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    @EnvironmentObject var healthManager: HealthManager
    @State private var viewModel = DashboardViewModel()
    
    // ... [Keep existing AppStorage] ...
    @AppStorage("dailyCalorieGoal") private var dailyGoal: Int = 2000
    @AppStorage("targetWeight") private var targetWeight: Double = 70.0
    @AppStorage("goalType") private var goalType: String = "Cutting"
    @AppStorage("maintenanceCalories") private var maintenanceCalories: Int = 2500
    @AppStorage("estimationMethod") private var estimationMethod: Int = 0
    @AppStorage("enableCaloriesBurned") private var enableCaloriesBurned: Bool = true
    @AppStorage("maintenanceTolerance") private var maintenanceTolerance: Double = 2.0
    @AppStorage("unitSystem") private var unitSystem: String = UnitSystem.metric.rawValue
    
    // --- NEW: Calorie Counting Toggle ---
    @AppStorage("isCalorieCountingEnabled") private var isCalorieCountingEnabled: Bool = true
    
    @State private var showingSettings = false
    @State private var showingMaintenanceInfo = false

    var weightLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    targetProgressCard
                    weightTrendCard
                    projectionComparisonCard
                    workoutDistributionCard
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                settingsSheet
            }
            .alert("About Estimated Maintenance", isPresented: $showingMaintenanceInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This is based on your weight change and your calories consumed over the last 30 days.")
            }
            .onAppear(perform: setupOnAppear)
            // Add isCalorieCountingEnabled to change observers
            .onChange(of: logs) { _, _ in refreshViewModel() }
            .onChange(of: weights) { _, _ in refreshViewModel() }
            .onChange(of: dailyGoal) { _, _ in refreshViewModel() }
            .onChange(of: targetWeight) { _, _ in refreshViewModel() }
            .onChange(of: estimationMethod) { _, _ in refreshViewModel() }
            .onChange(of: maintenanceCalories) { _, _ in refreshViewModel() }
            .onChange(of: maintenanceTolerance) { _, _ in refreshViewModel() }
            .onChange(of: isCalorieCountingEnabled) { _, _ in refreshViewModel() }
        }
    }

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
    
    // ... [Keep checkGoalReached, targetProgressCard, projectionComparisonCard, weightTrendCard, workoutDistributionCard, byCategoryColor] ...
    // Note: projectionComparisonCard will automatically update based on viewModel.projectionPoints changing
    
    // MARK: - Settings Sheet
    private var settingsSheet: some View {
        NavigationView {
            Form {
                Section("Preferences") {
                    Picker("Unit System", selection: $unitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Text(system.rawValue).tag(system.rawValue)
                        }
                    }
                    
                    // --- NEW: Toggle ---
                    Toggle("Enable Calorie Counting", isOn: $isCalorieCountingEnabled)
                }
                
                Section("Goal Settings") {
                    Picker("Goal Type", selection: $goalType) {
                        ForEach(GoalType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 5)

                    let targetWeightBinding = Binding<Double>(
                        get: { targetWeight.toUserWeight(system: unitSystem) },
                        set: { targetWeight = $0.toStoredWeight(system: unitSystem) }
                    )
                    
                    HStack {
                        Text(goalType == GoalType.maintenance.rawValue ? "Maintenance Weight (\(weightLabel))" : "Target Weight (\(weightLabel))")
                        Spacer()
                        TextField("0.0", value: targetWeightBinding, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    if goalType == GoalType.maintenance.rawValue {
                        let toleranceBinding = Binding<Double>(
                            get: { maintenanceTolerance.toUserWeight(system: unitSystem) },
                            set: { maintenanceTolerance = $0.toStoredWeight(system: unitSystem) }
                        )
                        HStack {
                            Text("Tolerance (+/- \(weightLabel))")
                            Spacer()
                            TextField("0.0", value: toleranceBinding, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    // Hide Calorie options if disabled
                    if isCalorieCountingEnabled {
                        HStack {
                            Text("Daily Calorie Goal")
                            Spacer()
                            TextField("Calories", value: $dailyGoal, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        Toggle("Track Calories Burned", isOn: $enableCaloriesBurned)
                    }
                }
                
                Section("Prediction Logic") {
                    if isCalorieCountingEnabled {
                        Picker("Method", selection: $estimationMethod) {
                            Text("30-Day Weight Trend").tag(0)
                            Text("Avg 7 Day Cal Consumption").tag(1)
                            Text("Fixed Daily Cal").tag(2)
                        }
                        
                        if estimationMethod == 1 || estimationMethod == 2 {
                            HStack {
                                Text("Maintenance Calories")
                                Spacer()
                                TextField("Calories", value: $maintenanceCalories, format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                            }
                            Text("Used to calculate deficit/surplus.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    } else {
                        Text("Fixed to 30-Day Weight Trend")
                            .foregroundColor(.secondary)
                        Text("Calorie counting is disabled.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") { showingSettings = false }
            }
        }
    }

    private func setupOnAppear() {
        healthManager.fetchAllHealthData()
        let today = Calendar.current.startOfDay(for: Date())
        if !logs.contains(where: { $0.date == today }) {
            let newItem = DailyLog(date: today, goalType: goalType)
            modelContext.insert(newItem)
        }
        refreshViewModel()
    }
    
    // Need to include the components of targetProgressCard that rely on estimatedMaintenance
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
                    
                    // Only show if available (it will be nil if disabled)
                    if let estMaint = viewModel.estimatedMaintenance {
                        Divider().padding(.vertical, 8)
                        HStack(spacing: 6) {
                            Text("Your estimated Maintenance calories: \(estMaint)")
                                .font(.subheadline).fontWeight(.medium)
                            Button(action: { showingMaintenanceInfo = true }) {
                                Image(systemName: "info.circle").foregroundColor(.blue)
                            }
                        }
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
    
    // ... [Other sections remain unchanged] ...
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
    
    // ... [Re-include projectionComparisonCard etc from original file as they are largely unchanged but depend on viewModel] ...
    private var projectionComparisonCard: some View {
        let currentWeightKg = weights.first?.weight ?? 0
        let currentDisplay = currentWeightKg.toUserWeight(system: unitSystem)
        let targetDisplay = targetWeight.toUserWeight(system: unitSystem)
        let toleranceDisplay = maintenanceTolerance.toUserWeight(system: unitSystem)
        
        let projections = viewModel.projectionPoints.map { point in
            ProjectionPoint(date: point.date, weight: point.weight.toUserWeight(system: unitSystem), method: point.method)
        }
        
        let allValues = projections.map { $0.weight } + [currentDisplay, targetDisplay]
        let minW = allValues.min() ?? 0
        let maxW = allValues.max() ?? 100
        let lowerBound = max(0, minW - 5)
        let upperBound = maxW + 5
        
        return VStack(alignment: .leading) {
            Text("Projections (\(weightLabel))").font(.headline)
            Text("Estimated weight over the next 60 days").font(.caption).foregroundColor(.secondary)
            
            if currentWeightKg > 0 {
                Chart {
                    RuleMark(y: .value("Target", targetDisplay))
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                    
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
                .frame(height: 250)
                .chartYScale(domain: lowerBound...upperBound)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 14)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartLegend(position: .bottom, spacing: 10)
            } else {
                Text("Log weight to see projections").frame(maxWidth: .infinity, alignment: .center).padding().font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    // ... [workoutDistributionCard & weightTrendCard & byCategoryColor unchanged] ...
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
