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
    
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Progress to Target Calculation
                    targetProgressCard
                    
                    // 2. Weight Trend Graph
                    weightTrendCard
                    
                    // 3. Calorie Balance Graph (Last 7 Days)
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

    private func calculateDaysRemaining(currentWeight: Double) -> Int? {
        let weightDiff = abs(targetWeight - currentWeight)
        let totalCaloriesNeeded = weightDiff * 7700
        
        // Logic 1: Weight Trend (Last 30 Days)
        if estimationMethod == 0 {
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            // weights is sorted reverse (newest first). Get those in range and sort Oldest -> Newest
            let recentWeights = weights.filter { $0.date >= thirtyDaysAgo }.sorted { $0.date < $1.date }
            
            // Need at least 2 points to calculate a trend
            guard recentWeights.count >= 2,
                  let first = recentWeights.first,
                  let last = recentWeights.last else { return nil }
            
            let timeSpan = Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 0
            if timeSpan > 0 {
                let weightChange = last.weight - first.weight // Negative if lost weight
                let kgPerDay = weightChange / Double(timeSpan)
                
                // If Cutting, kgPerDay should be negative. If Bulking, positive.
                if (goalType == "Cutting" && kgPerDay < 0) || (goalType == "Bulking" && kgPerDay > 0) {
                    return Int(weightDiff / abs(kgPerDay))
                }
            }
        }
        
        // Logic 2: Avg Intake (User Maintenance - 7 Day Avg)
        if estimationMethod == 1 {
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            let recentLogs = logs.filter { $0.date >= sevenDaysAgo }
            
            if !recentLogs.isEmpty {
                let totalConsumed = recentLogs.reduce(0) { $0 + $1.caloriesConsumed }
                let avgConsumed = Double(totalConsumed) / Double(recentLogs.count)
                
                let diff = Double(maintenanceCalories) - avgConsumed
                let dailyRate = goalType == "Cutting" ? diff : -diff
                
                if dailyRate > 0 {
                    return Int(totalCaloriesNeeded / dailyRate)
                }
            }
        }
        
        // Logic 3: Fixed Target (User Maintenance - User Target)
        if estimationMethod == 2 {
            let diff = Double(maintenanceCalories - dailyGoal)
            // If Cutting, we need positive diff (Maint > Goal). If Bulking, negative diff (Goal > Maint).
            // We standardize "Rate" to be positive amount of progress per day.
            let dailyRate = goalType == "Cutting" ? diff : -diff
            
            if dailyRate > 0 {
                return Int(totalCaloriesNeeded / dailyRate)
            }
        }
        
        return nil
    }

    // MARK: - Graphs
    private var weightTrendCard: some View {
        VStack(alignment: .leading) {
            Text("Weight Trend").font(.headline)
            
            if weights.isEmpty {
                Text("No weight data logged yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart {
                    ForEach(weights.sorted(by: { $0.date < $1.date })) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.blue)
                        
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 180)
                .chartXScale(domain: .automatic(includesZero: false))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private var calorieBalanceCard: some View {
        VStack(alignment: .leading) {
            Text("Net Calories (Last 7 Days)").font(.headline)
            Chart {
                ForEach(logs.suffix(7)) { log in
                    BarMark(
                        x: .value("Day", log.date, unit: .day),
                        y: .value("Net", log.netCalories)
                    )
                    .foregroundStyle(log.netCalories > 0 ? .red : .green)
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
