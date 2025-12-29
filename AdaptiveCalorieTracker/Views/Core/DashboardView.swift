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
    
    @AppStorage("dailyCalorieGoal") private var dailyGoal: Int = 2000
    @AppStorage("targetWeight") private var targetWeight: Double = 70.0
    @AppStorage("goalType") private var goalType: String = "Cutting"
    @AppStorage("maintenanceCalories") private var maintenanceCalories: Int = 2500
    @AppStorage("estimationMethod") private var estimationMethod: Int = 0
    @AppStorage("enableCaloriesBurned") private var enableCaloriesBurned: Bool = true
    @AppStorage("maintenanceTolerance") private var maintenanceTolerance: Double = 2.0
    @AppStorage("unitSystem") private var unitSystem: String = UnitSystem.metric.rawValue
    
    @AppStorage("userGender") private var userGender: Gender = .male
    @AppStorage("isCalorieCountingEnabled") private var isCalorieCountingEnabled: Bool = true
    
    // --- Dark Mode State ---
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    
    @State private var showingSettings = false
    @State private var showingReconfigureGoal = false
    @State private var showingMaintenanceInfo = false

    var weightLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    
    // --- Custom "Lighter" Dark Background ---
    var appBackgroundColor: Color {
        // Uses a soft dark gray (approx #1C1C1E) instead of pure black
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
            .sheet(isPresented: $showingSettings) {
                settingsSheet
            }
            .sheet(isPresented: $showingReconfigureGoal) {
                GoalConfigurationView(
                    appEstimatedMaintenance: viewModel.estimatedMaintenance,
                    latestWeightKg: weights.first?.weight
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
    
    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Picker("Unit System", selection: $unitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Text(system.rawValue).tag(system.rawValue)
                        }
                    }
                    
                    // Dark Mode Toggle
                    Toggle("Dark Mode", isOn: $isDarkMode)
                    
                    Toggle("Enable Calorie Counting", isOn: $isCalorieCountingEnabled)
                    
                    if isCalorieCountingEnabled {
                        Toggle("Track Calories Burned", isOn: $enableCaloriesBurned)
                    }
                }
                
                Section("Profile") {
                    Picker("Gender", selection: $userGender) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }
                }
                
                if isCalorieCountingEnabled {
                    Section("Current Goal") {
                        HStack {
                            Text("Goal Type")
                            Spacer()
                            Text(goalType).foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text(goalType == GoalType.maintenance.rawValue ? "Maintenance Weight" : "Target Weight")
                            Spacer()
                            Text("\(targetWeight.toUserWeight(system: unitSystem), specifier: "%.1f") \(weightLabel)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Daily Calorie Goal")
                            Spacer()
                            Text("\(dailyGoal) kcal").foregroundColor(.secondary)
                        }
                        
                        Button("Reconfigure Goal") {
                            showingSettings = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showingReconfigureGoal = true
                            }
                        }
                        .foregroundColor(.blue)
                        .bold()
                    }
                    
                    Section("Prediction Logic") {
                        if isCalorieCountingEnabled {
                            Picker("Method", selection: $estimationMethod) {
                                Text("30-Day Weight Trend").tag(0)
                                Text("Avg 7 Day Cal Consumption").tag(1)
                                Text("Fixed Daily Cal").tag(2)
                            }
                        } else {
                            Text("Fixed to 30-Day Weight Trend")
                            Text("Calorie counting is disabled.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    
                    if goalType == GoalType.maintenance.rawValue {
                        Section("Maintenance Settings") {
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
    
    // --- WEIGHT CHANGE CARD ---
    private var weightChangeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weight Change").font(.headline)
            
            // Grid Layout
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Iterates over the array from ViewModel. Requires WeightChangeMetric to be in scope.
                ForEach(viewModel.weightChangeMetrics) { metric in
                    weightChangeCell(for: metric)
                }
            }
        }
        .padding()
        // Outer card background
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    // Helper function used by weightChangeCard to fix compiler complexity issues
    private func weightChangeCell(for metric: WeightChangeMetric) -> some View {
        VStack(spacing: 6) {
            Text(metric.period)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if let val = metric.value {
                let converted = val.toUserWeight(system: unitSystem)
                
                HStack(spacing: 4) {
                    // Value
                    HStack(spacing: 0) {
                        Text(val > 0 ? "+" : "")
                        Text("\(converted, specifier: "%.1f")")
                        Text(" \(weightLabel)")
                    }
                    .foregroundColor(.primary) // Neutral text color
                    
                    // Arrow Indicator
                    if val > 0 {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.green)
                            .font(.caption).bold()
                    } else if val < 0 {
                        Image(systemName: "arrow.down")
                            .foregroundColor(.red)
                            .font(.caption).bold()
                    }
                }
                .font(.title3)
                .fontWeight(.bold)
            } else {
                Text("--")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
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

// MARK: - Goal Configuration View (Reconfigure)

struct GoalConfigurationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool
    
    let appEstimatedMaintenance: Int?
    let latestWeightKg: Double?
    
    @AppStorage("userGender") private var userGender: Gender = .male
    @AppStorage("unitSystem") private var unitSystem: String = UnitSystem.metric.rawValue
    
    // Inputs
    @State private var targetWeight: Double? = nil
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
    
    // Maintenance Source logic
    @State private var maintenanceSource: Int = 0 // 0: Formula, 1: App Estimate, 2: Manual
    @State private var manualMaintenanceInput: String = ""
    @State private var maintenanceDisplay: Int = 0

    // Calculated Outputs
    @State private var dailyGoal: Int = 0
    @State private var calculatedDeficit: Int = 0
    @State private var derivedGoalType: GoalType = .maintenance
    
    private var dataManager: DataManager {
            DataManager(modelContext: modelContext)
        }
    
    var unitLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Goal Details")) {
                    HStack {
                        Text("Current Weight")
                        Spacer()
                        if let w = latestWeightKg {
                            Text("\(w.toUserWeight(system: unitSystem), specifier: "%.1f") \(unitLabel)")
                                .foregroundColor(.secondary)
                        } else {
                            Text("No Data").foregroundColor(.red)
                        }
                    }
                    
                    HStack {
                        Text("Target Weight (\(unitLabel))")
                        Spacer()
                        TextField("Required", value: $targetWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputFocused)
                            .onChange(of: targetWeight) { _, _ in recalculate() }
                    }
                    
                    DatePicker("Target Date", selection: $targetDate, in: Date()..., displayedComponents: .date)
                        .onChange(of: targetDate) { _, _ in recalculate() }
                }
                
                Section(header: Text("Maintenance Calorie Source")) {
                    Picker("Source", selection: $maintenanceSource) {
                        Text("Formula").tag(0)
                        if appEstimatedMaintenance != nil {
                            Text("App Estimate").tag(1)
                        }
                        Text("Manual").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: maintenanceSource) { _, _ in recalculate() }
                    
                    if maintenanceSource == 2 {
                        HStack {
                            Text("Manual Maintenance")
                            Spacer()
                            TextField("kcal", text: $manualMaintenanceInput)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .focused($isInputFocused)
                                .onChange(of: manualMaintenanceInput) { _, _ in recalculate() }
                        }
                    } else {
                        HStack {
                            Text("Base Maintenance")
                            Spacer()
                            Text("\(maintenanceDisplay) kcal").bold()
                        }
                    }
                }
                
                Section(header: Text("Results")) {
                    HStack {
                        Text("Goal Type")
                        Spacer()
                        Text(derivedGoalType.rawValue)
                            .bold()
                            .foregroundColor(derivedGoalType == .cutting ? .green : (derivedGoalType == .bulking ? .red : .blue))
                    }
                    
                    HStack {
                        Text("Daily Calorie Goal")
                        Spacer()
                        Text("\(dailyGoal) kcal").bold().foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Daily Adjustment")
                        Spacer()
                        Text(calculatedDeficit < 0 ? "\(calculatedDeficit) deficit" : "+\(calculatedDeficit) surplus")
                            .font(.caption)
                            .foregroundColor(calculatedDeficit < 0 ? .green : .orange)
                    }
                }
                
                Section {
                    Button("Save Configuration") {
                        save()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(targetWeight == nil || latestWeightKg == nil || (maintenanceSource == 2 && manualMaintenanceInput.isEmpty))
                }
            }
            .navigationTitle("Reconfigure Goal")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if appEstimatedMaintenance != nil {
                    maintenanceSource = 1
                }
                recalculate()
            }
        }
    }
    
    private func recalculate() {
        guard let currentKg = latestWeightKg else { return }
        
        // 1. Determine Maintenance
        switch maintenanceSource {
        case 0: // Formula
            let multiplier: Double = (userGender == .male) ? 32.0 : 29.0
            maintenanceDisplay = Int(currentKg * multiplier)
        case 1: // App Estimate
            maintenanceDisplay = appEstimatedMaintenance ?? 2500
        case 2: // Manual
            maintenanceDisplay = Int(manualMaintenanceInput) ?? 0
        default:
            break
        }
        
        // 2. Determine Goal Type
        guard let tWeightUser = targetWeight else { return }
        let tWeightKg = tWeightUser.toStoredWeight(system: unitSystem)
        
        if tWeightKg > currentKg {
            derivedGoalType = .bulking
        } else if tWeightKg < currentKg {
            derivedGoalType = .cutting
        } else {
            derivedGoalType = .maintenance
        }
        
        // 3. Calculate Daily Goal
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: targetDate)
        let days = Calendar.current.dateComponents([.day], from: today, to: target).day ?? 1
        
        if days <= 0 {
            dailyGoal = maintenanceDisplay
            calculatedDeficit = 0
            return
        }
        
        let weightDiff = tWeightKg - currentKg
        let totalCaloriesNeeded = weightDiff * 7700.0
        let dailyAdjustment = Int(totalCaloriesNeeded / Double(days))
        
        calculatedDeficit = dailyAdjustment
        dailyGoal = maintenanceDisplay + dailyAdjustment
    }
    
    private func save() {
        guard let tWeightUser = targetWeight else { return }
        
        let tWeightStored = tWeightUser.toStoredWeight(system: unitSystem)
                UserDefaults.standard.set(tWeightStored, forKey: "targetWeight")
                UserDefaults.standard.set(dailyGoal, forKey: "dailyCalorieGoal")
                UserDefaults.standard.set(derivedGoalType.rawValue, forKey: "goalType")
                UserDefaults.standard.set(maintenanceDisplay, forKey: "maintenanceCalories")
                
                let startW = latestWeightKg ?? 0.0
                
                dataManager.startNewGoalPeriod(
                    goalType: derivedGoalType.rawValue,
                    startWeight: startW,
                    targetWeight: tWeightStored,
                    dailyCalorieGoal: dailyGoal,
                    maintenanceCalories: maintenanceDisplay
                )
                
                dismiss()
            }
        }
