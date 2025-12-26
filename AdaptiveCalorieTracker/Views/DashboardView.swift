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
    
    @AppStorage("dailyCalorieGoal") private var dailyGoal: Int = 2000
    @AppStorage("targetWeight") private var targetWeight: Double = 70.0
    @AppStorage("goalType") private var goalType: String = "Cutting"
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Progress to Target Calculation (Updated)
                    targetProgressCard
                    
                    // 2. Weight Trend Graph
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
                                // Sort by date ascending so the line draws Left -> Right
                                ForEach(weights.sorted(by: { $0.date < $1.date })) { entry in
                                    LineMark(
                                        x: .value("Date", entry.date),
                                        y: .value("Weight", entry.weight)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(.blue)
                                    
                                    // Add dots for specific data points
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
                    
                    // 3. Calorie Balance Graph (Last 7 Days)
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

    private var targetProgressCard: some View {
        // Get the latest weight from the weight entries list
        let currentWeight = weights.first?.weight
        let avgSurplusDeficit = calculateAverageSurplusDeficit()
        
        return VStack(spacing: 12) {
            
            if let current = currentWeight, current > 0 {
                // --- UPDATE START: Display Current Weight ---
                VStack(spacing: 4) {
                    Text("Current Weight: \(current, specifier: "%.1f") kg")
                        .font(.title3) // Slightly larger
                        .fontWeight(.semibold)
                    
                    Text("Goal: \(targetWeight, specifier: "%.1f") kg (\(goalType))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                // --- UPDATE END ---
                
                // Determine if the goal is reached based on goalType
                let isGoalReached = goalType == "Cutting" ? current <= targetWeight : current >= targetWeight
                
                if isGoalReached {
                    Text("Target Reached!")
                        .font(.title).bold()
                        .foregroundColor(.green)
                } else {
                    // Calculation logic...
                    let weightToChange = abs(current - targetWeight)
                    let totalCaloriesNeeded = weightToChange * 7700
                    let effectiveDailyRate = goalType == "Cutting" ? avgSurplusDeficit : -avgSurplusDeficit
                    
                    if effectiveDailyRate > 0 {
                        let daysLeft = Int(totalCaloriesNeeded / Double(effectiveDailyRate))
                        Text("\(daysLeft)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.orange)
                        Text("Days until target hit")
                            .font(.headline)
                    } else {
                        // Spacer to separate stats from warning
                        Divider().padding(.vertical, 5)
                        
                        Text("Check Calories")
                            .font(.title3).bold()
                        Text(goalType == "Cutting" ? "Maintain a deficit to see estimate" : "Maintain a surplus to see estimate")
                            .font(.caption).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
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

    private func calculateAverageSurplusDeficit() -> Int {
        let last7Logs = logs.suffix(7)
        guard !last7Logs.isEmpty else { return 0 }
        let total = last7Logs.reduce(0) { $0 + ($1.caloriesBurned - $1.caloriesConsumed) }
        return total / last7Logs.count
    }

    private var settingsSheet: some View {
        NavigationView {
            Form {
                Section("Health Goals") {
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
            // Pass the goalType stored in DashboardView
            let newItem = DailyLog(date: today, goalType: goalType) // <--- UPDATED
            modelContext.insert(newItem)
        }
    }
}
