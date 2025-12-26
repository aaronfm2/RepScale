import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Fetch logs for calorie data
    @Query(sort: \DailyLog.date, order: .forward) private var logs: [DailyLog]
    
    // Fetch weights for the graph and progress (Reverse order so first is latest)
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    
    @StateObject var healthManager = HealthManager()
    
    // --- APP STORAGE SETTINGS ---
    @AppStorage("dailyCalorieGoal") private var dailyGoal: Int = 2000
    @AppStorage("targetWeight") private var targetWeight: Double = 70.0
    @AppStorage("goalType") private var goalType: String = "Cutting"
    
    // New Settings for Estimation Logic
    @AppStorage("maintenanceCalories") private var maintenanceCalories: Int = 2500
    @AppStorage("estimationMethod") private var estimationMethod: Int = 0
    // 0 = Fixed Target (Logic 1), 1 = Avg Intake (Logic 2), 2 = Weight Trend (Logic 3)
    
    // --- NEW TOGGLE ---
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
        }
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
                let isGoalReached = goalType == "Cutting" ? current <= targetWeight : current >= targetWeight
                
                if isGoalReached {
                    Text("Target Reached!")
                        .font(.title).bold()
                        .foregroundColor(.green)
                } else {
                    // Calculate based on selected logic
                    if let daysLeft = calculateDaysRemaining(currentWeight: current) {
                        Text("\(daysLeft)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.orange)
                        Text("Days until target hit")
                            .font(.headline)
                        
                        Text(logicDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    } else {
                        Divider().padding(.vertical, 5)
                        
                        Text("Estimate Unavailable")
                            .font(.title3).bold()
                        Text(progressWarningMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // --- Estimated Maintenance ---
                    if let estMaint = calculateEstimatedMaintenance() {
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
                    // -----------------------------
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

    // MARK: - Calculation Logic
    
    private var logicDescription: String {
        switch estimationMethod {
        case 0: return "Based on 30-day weight trend"
        case 1: return "Based on 7-day average intake"
        case 2: return "Based on maintenance vs daily goal"
        default: return ""
        }
    }
    
    private var progressWarningMessage: String {
        switch estimationMethod {
        case 0: // Weight Trend
            return "Need more weight data over 30 days, or trend is moving away from goal."
        case 1: // Avg Intake
            return goalType == "Cutting"
                ? "Eat less than maintenance on average to see estimate"
                : "Eat more than maintenance on average to see estimate"
        case 2: // Fixed Target
            return goalType == "Cutting"
                ? "Your daily goal must be lower than your maintenance (\(maintenanceCalories))"
                : "Your daily goal must be higher than your maintenance (\(maintenanceCalories))"
        default: return ""
        }
    }
    
    private func calculateEstimatedMaintenance() -> Int? {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        
        // Get weights in range, sorted Oldest -> Newest
        let recentWeights = weights.filter { $0.date >= thirtyDaysAgo }.sorted { $0.date < $1.date }
        
        // Need at least 2 distinct weight entries
        guard let first = recentWeights.first, let last = recentWeights.last, first.id != last.id else {
            return nil
        }
        
        // --- FIX: Use startOfDay to count calendar days correctly ---
        let start = Calendar.current.startOfDay(for: first.date)
        let end = Calendar.current.startOfDay(for: last.date)
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        
        guard days > 0 else { return nil }
        
        // Weight Change (+ve gain, -ve loss)
        let weightChange = last.weight - first.weight
        
        // Exclude Today's Logs
        let today = Calendar.current.startOfDay(for: Date())
        
        // Get logs strictly within this date range AND strictly before today
        let relevantLogs = logs.filter { $0.date >= first.date && $0.date <= last.date && $0.date < today }
        
        guard !relevantLogs.isEmpty else { return nil }
        
        // Calculate Average Daily Intake
        let totalConsumed = relevantLogs.reduce(0) { $0 + $1.caloriesConsumed }
        let avgDailyIntake = Double(totalConsumed) / Double(relevantLogs.count)
        
        // Calculate Daily Energy Imbalance from Weight Change
        let dailyImbalance = (weightChange * 7700.0) / Double(days)
        
        // Maintenance = Intake - Imbalance
        let estimatedMaintenance = avgDailyIntake - dailyImbalance
        
        return Int(estimatedMaintenance)
    }

    private func calculateKgChangePerDay(method: Int) -> Double? {
        // Method 0: Weight Trend (Last 30 Days)
        if method == 0 {
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            let recentWeights = weights.filter { $0.date >= thirtyDaysAgo }.sorted { $0.date < $1.date }
            
            guard let first = recentWeights.first, let last = recentWeights.last, first.id != last.id else { return nil }
            
            // --- FIX: Use startOfDay for robust day difference ---
            let start = Calendar.current.startOfDay(for: first.date)
            let end = Calendar.current.startOfDay(for: last.date)
            let timeSpan = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
            
            if timeSpan > 0 {
                let weightChange = last.weight - first.weight
                return weightChange / Double(timeSpan)
            }
        }
        
        // Method 1: Avg Intake (User Maintenance - 7 Day Avg)
        if method == 1 {
            let today = Calendar.current.startOfDay(for: Date())
            // Look at 7 days *before* today
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
            
            let recentLogs = logs.filter { $0.date >= sevenDaysAgo && $0.date < today }
            
            if !recentLogs.isEmpty {
                let totalConsumed = recentLogs.reduce(0) { $0 + $1.caloriesConsumed }
                let avgConsumed = Double(totalConsumed) / Double(recentLogs.count)
                
                return (avgConsumed - Double(maintenanceCalories)) / 7700.0
            }
        }
        
        // Method 2: Fixed Target (User Maintenance - User Target)
        if method == 2 {
            return (Double(dailyGoal) - Double(maintenanceCalories)) / 7700.0
        }
        
        return nil
    }

    private func calculateDaysRemaining(currentWeight: Double) -> Int? {
        guard let kgPerDay = calculateKgChangePerDay(method: estimationMethod) else { return nil }
        
        if goalType == "Cutting" && kgPerDay >= 0 { return nil }
        if goalType == "Bulking" && kgPerDay <= 0 { return nil }
        
        let weightDiff = targetWeight - currentWeight
        let days = weightDiff / kgPerDay
        
        if days > 0 { return Int(days) }
        return nil
    }

    // MARK: - New Projection Graph
    private struct ProjectionPoint: Identifiable {
        let id = UUID()
        let date: Date
        let weight: Double
        let method: String
    }
    
    private var projectionComparisonCard: some View {
        let currentWeight = weights.first?.weight ?? 0
        let projections = generateProjections(startWeight: currentWeight)
        
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
    
    private func generateProjections(startWeight: Double) -> [ProjectionPoint] {
        var points: [ProjectionPoint] = []
        let today = Date()
        let comparisonMethods = [(0, "Trend (30d)"), (1, "Avg Intake (7d)"), (2, "Fixed Goal")]
        
        for (methodId, label) in comparisonMethods {
            // --- FIX: Removed the abs(rate) > 0.001 check so even small trends show ---
            if let rate = calculateKgChangePerDay(method: methodId) {
                points.append(ProjectionPoint(date: today, weight: startWeight, method: label))
                for i in 1...60 {
                    let nextDate = Calendar.current.date(byAdding: .day, value: i, to: today)!
                    let projectedWeight = startWeight + (rate * Double(i))
                    points.append(ProjectionPoint(date: nextDate, weight: projectedWeight, method: label))
                }
            }
        }
        return points
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
            // Dynamic Title based on Toggle
            Text(enableCaloriesBurned ? "Net Calories (Last 7 Days)" : "Calories Consumed (Last 7 Days)")
                .font(.headline)
            
            Chart {
                ForEach(logs.suffix(7)) { log in
                    // Determine value to plot
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
                        Text("Cutting (Lose Weight)").tag("Cutting")
                        Text("Bulking (Gain Weight)").tag("Bulking")
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
                    
                    // --- NEW TOGGLE ---
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
    }
}
