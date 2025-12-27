import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Fetch logs for calorie data
    @Query(sort: \DailyLog.date, order: .forward) private var logs: [DailyLog]
    
    // Fetch weights for the graph (Reverse order so first is latest)
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    
    @StateObject var healthManager = HealthManager()
    
    // --- VIEW MODEL ---
    @State private var viewModel = DashboardViewModel()
    
    // --- APP STORAGE SETTINGS ---
    @AppStorage("dailyCalorieGoal") private var dailyGoal: Int = 2000
    @AppStorage("targetWeight") private var targetWeight: Double = 70.0
    @AppStorage("goalType") private var goalType: String = "Cutting"
    @AppStorage("maintenanceCalories") private var maintenanceCalories: Int = 2500
    @AppStorage("estimationMethod") private var estimationMethod: Int = 0
    @AppStorage("enableCaloriesBurned") private var enableCaloriesBurned: Bool = true
    
    @State private var showingSettings = false
    @State private var showingMaintenanceInfo = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Progress to Target Calculation
                    targetProgressCard
                    
                    // 2. Projection Comparison Graph
                    projectionComparisonCard
                    
                    // 3. Weight Trend Graph
                    weightTrendCard
                    
                    // 4. Calorie Balance Graph (Last 7 Days)
                    calorieBalanceCard
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
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
            // Recalculate whenever data or settings change
            .onChange(of: logs) { _, _ in refreshViewModel() }
            .onChange(of: weights) { _, _ in refreshViewModel() }
            .onChange(of: dailyGoal) { _, _ in refreshViewModel() }
            .onChange(of: targetWeight) { _, _ in refreshViewModel() }
            .onChange(of: estimationMethod) { _, _ in refreshViewModel() }
            .onChange(of: maintenanceCalories) { _, _ in refreshViewModel() }
        }
    }

    // MARK: - Logic / ViewModel Binding
    private func refreshViewModel() {
        let settings = DashboardSettings(
            dailyGoal: dailyGoal,
            targetWeight: targetWeight,
            goalType: goalType,
            maintenanceCalories: maintenanceCalories,
            estimationMethod: estimationMethod,
            enableCaloriesBurned: enableCaloriesBurned
        )
        
        viewModel.updateMetrics(logs: logs, weights: weights, settings: settings)
    }

    // MARK: - Progress Card
    private var targetProgressCard: some View {
        let currentWeight = weights.first?.weight
        
        return VStack(spacing: 12) {
            
            if let current = currentWeight, current > 0 {
                VStack(spacing: 4) {
                    Text("Current Weight: \(current, specifier: "%.1f") kg")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Goal: \(targetWeight, specifier: "%.1f") kg (\(goalType))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Determine if the goal is reached
                let isGoalReached = goalType == GoalType.cutting.rawValue ? current <= targetWeight : current >= targetWeight
                
                if isGoalReached {
                    Text("Target Reached!")
                        .font(.title).bold()
                        .foregroundColor(.green)
                } else {
                    // Use ViewModel Data
                    if let daysLeft = viewModel.daysRemaining {
                        Text("\(daysLeft)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.orange)
                        Text("Days until target hit")
                            .font(.headline)
                        
                        Text(viewModel.logicDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    } else {
                        Divider().padding(.vertical, 5)
                        
                        Text("Estimate Unavailable")
                            .font(.title3).bold()
                        Text(viewModel.progressWarningMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // --- Estimated Maintenance (From ViewModel) ---
                    if let estMaint = viewModel.estimatedMaintenance {
                        Divider().padding(.vertical, 8)
                        
                        HStack(spacing: 6) {
                            Text("Your estimated Maintenance calories: \(estMaint)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Button(action: { showingMaintenanceInfo = true }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } else {
                Text("\(goalType): \(targetWeight, specifier: "%.1f") kg")
                    .font(.subheadline).foregroundColor(.secondary)
                
                Text("No Weight Data")
                    .font(.title3).bold()
                    .foregroundColor(.secondary)
                Text("Log your weight in the Weight tab")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 15).fill(Color.orange.opacity(0.1)))
    }

    // MARK: - Projection Graph
    private var projectionComparisonCard: some View {
        let currentWeight = weights.first?.weight ?? 0
        let projections = viewModel.projectionPoints
        
        let allValues = projections.map { $0.weight } + [currentWeight, targetWeight]
        let minW = allValues.min() ?? 0
        let maxW = allValues.max() ?? 100
        let lowerBound = max(0, minW - 1.5)
        let upperBound = maxW + 1.5
        
        return VStack(alignment: .leading) {
            Text("Projections").font(.headline)
            Text("Estimated weight over the next 60 days").font(.caption).foregroundColor(.secondary)
            
            if currentWeight > 0 {
                Chart {
                    RuleMark(y: .value("Target", targetWeight))
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .annotation(position: .topLeading, alignment: .leading) {
                            Text("Goal: \(targetWeight, specifier: "%.1f")")
                                .font(.caption2).bold().foregroundColor(.green)
                        }

                    ForEach(projections) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
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
                Text("Log weight to see projections")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding().font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    // MARK: - Graphs
    private var weightTrendCard: some View {
        let allWeights = weights.map { $0.weight }
        let minW = allWeights.min() ?? 0
        let maxW = allWeights.max() ?? 100
        let lowerBound = max(0, minW - 1.0)
        let upperBound = maxW + 1.0
        
        return VStack(alignment: .leading) {
            Text("Weight History").font(.headline)
            
            if weights.isEmpty {
                Text("No weight data logged yet")
                    .font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center).padding()
            } else {
                Chart {
                    ForEach(weights.sorted(by: { $0.date < $1.date })) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
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
    
    private var calorieBalanceCard: some View {
        VStack(alignment: .leading) {
            Text(enableCaloriesBurned ? "Net Calories (Last 7 Days)" : "Calories Consumed (Last 7 Days)")
                .font(.headline)
            
            Chart {
                ForEach(logs.suffix(7)) { log in
                    let val = enableCaloriesBurned ? log.netCalories : log.caloriesConsumed
                    BarMark(
                        x: .value("Day", log.date, unit: .day),
                        y: .value("Net", val)
                    )
                    .foregroundStyle(val > 0 ? .red : .green)
                }
            }
            .frame(height: 150)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }

    // MARK: - Settings Sheet
    private var settingsSheet: some View {
        NavigationView {
            Form {
                Section("Goal Settings") {
                    Picker("Goal Type", selection: $goalType) {
                        ForEach(GoalType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 5)

                    HStack {
                        Text("Target Weight (kg)")
                        Spacer()
                        TextField("kg", value: $targetWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Daily Calorie Goal")
                        Spacer()
                        TextField("Calories", value: $dailyGoal, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Toggle("Track Calories Burned", isOn: $enableCaloriesBurned)
                }
                
                Section("Prediction Logic") {
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
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") { showingSettings = false }
            }
        }
    }

    private func setupOnAppear() {
        healthManager.requestAuthorization()
        healthManager.fetchTodayCaloriesBurned()
        
        let today = Calendar.current.startOfDay(for: Date())
        if !logs.contains(where: { $0.date == today }) {
            let newItem = DailyLog(date: today, goalType: goalType)
            modelContext.insert(newItem)
        }
        
        refreshViewModel()
    }
}
