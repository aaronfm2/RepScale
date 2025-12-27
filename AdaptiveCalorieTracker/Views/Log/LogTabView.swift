import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    
    // Fetch workouts to link them to logs
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    // Fetch Weight Entries to find the starting date
    @Query(sort: \WeightEntry.date, order: .forward) private var weightEntries: [WeightEntry]
    
    @EnvironmentObject var healthManager: HealthManager
    
    @AppStorage("dailyCalorieGoal") private var dailyGoal: Int = 2000
    @AppStorage("goalType") private var currentGoalType: String = GoalType.cutting.rawValue
    @AppStorage("enableCaloriesBurned") private var enableCaloriesBurned: Bool = true
    
    // --- NEW: Toggle to control visibility ---
    @AppStorage("isCalorieCountingEnabled") private var isCalorieCountingEnabled: Bool = true
    
    // Sheet State
    @State private var showingLogSheet = false
    @State private var selectedLogDate = Date()
    @State private var inputMode = 0
    
    @State private var showingInfoAlert = false
    
    // Refresh State
    @State private var isRefreshingHistory = false
    
    // Inputs
    @State private var caloriesInput = ""
    @State private var proteinInput = ""
    @State private var carbsInput = ""
    @State private var fatInput = ""

    // MARK: - Computed Properties for Grouping
    
    struct LogSection: Identifiable {
        var id: Date { month }
        let month: Date
        let logs: [DailyLog]
    }
    
    var groupedSections: [LogSection] {
        let grouped = Dictionary(grouping: logs) { log in
            // Group by the first day of the month
            Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: log.date))!
        }
        
        // Sort months descending (newest first)
        let sortedMonths = grouped.keys.sorted(by: >)
        
        return sortedMonths.map { month in
            LogSection(month: month, logs: grouped[month]!)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Only show calorie summary if enabled
                if isCalorieCountingEnabled {
                    summaryHeader
                }
                
                List {
                    ForEach(groupedSections) { section in
                        Section(header: Text(section.month, format: .dateTime.month(.wide).year())) {
                            ForEach(section.logs) { log in
                                NavigationLink(destination: LogDetailView(
                                    log: log,
                                    workouts: getWorkouts(for: log.date)
                                )) {
                                    logRow(for: log)
                                }
                            }
                            .onDelete { indexSet in
                                deleteItems(at: indexSet, from: section.logs)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Daily Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingInfoAlert = true }) {
                        Image(systemName: "info.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: refreshLast365Days) {
                            if isRefreshingHistory {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isRefreshingHistory)
                        
                        Button(action: {
                            selectedLogDate = Date()
                            caloriesInput = ""
                            proteinInput = ""
                            carbsInput = ""
                            fatInput = ""
                            inputMode = 0
                            showingLogSheet = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                logSheetContent
            }
            .alert("Apple Health Sync", isPresented: $showingInfoAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This data is automatically synced with Apple Health. Manual entries are added ON TOP of HealthKit data.")
            }
            .onAppear(perform: setupOnAppear)
            // Real-time sync for Today
            .onChange(of: healthManager.caloriesBurnedToday) { _, newValue in
                updateTodayLog { $0.caloriesBurned = Int(newValue) }
            }
            .onChange(of: healthManager.caloriesConsumedToday) { _, newValue in
                if newValue > 0 {
                    updateTodayLog { $0.caloriesConsumed = Int(newValue) + $0.manualCalories }
                }
            }
            .onChange(of: healthManager.proteinToday) { _, newValue in
                if newValue > 0 {
                    updateTodayLog { $0.protein = Int(newValue) + $0.manualProtein }
                }
            }
            .onChange(of: healthManager.carbsToday) { _, newValue in
                if newValue > 0 {
                    updateTodayLog { $0.carbs = Int(newValue) + $0.manualCarbs }
                }
            }
            .onChange(of: healthManager.fatToday) { _, newValue in
                if newValue > 0 {
                    updateTodayLog { $0.fat = Int(newValue) + $0.manualFat }
                }
            }
        }
    }

    // MARK: - Helper Methods
    
    private func refreshLast365Days() {
        isRefreshingHistory = true
        
        // 1. Get the date of the very first weight entry
        // Since the query is sorted .forward, the first item is the oldest.
        let firstWeightDate = weightEntries.first?.date
        
        Task {
            let today = Calendar.current.startOfDay(for: Date())
            
            for i in 0..<365 {
                guard let date = Calendar.current.date(byAdding: .day, value: -i, to: today) else { continue }
                
                // 2. CHECK: Is this date older than our first weight entry?
                // If we have a first weight date, and the current 'date' is strictly before it (ignoring time), SKIP.
                if let startLimit = firstWeightDate {
                    let startOfDayLimit = Calendar.current.startOfDay(for: startLimit)
                    // If date < startLimit, skip.
                    if date < startOfDayLimit {
                        continue
                    }
                }
                
                let data = await healthManager.fetchHistoricalHealthData(for: date)
                
                await MainActor.run {
                    if let log = logs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                        log.caloriesConsumed = Int(data.consumed) + log.manualCalories
                        if enableCaloriesBurned { log.caloriesBurned = Int(data.burned) }
                        
                        log.protein = Int(data.protein) + log.manualProtein
                        log.carbs = Int(data.carbs) + log.manualCarbs
                        log.fat = Int(data.fat) + log.manualFat
                        
                    } else if data.consumed > 0 || data.burned > 0 {
                        let newLog = DailyLog(date: date, goalType: currentGoalType)
                        newLog.caloriesConsumed = Int(data.consumed)
                        if enableCaloriesBurned { newLog.caloriesBurned = Int(data.burned) }
                        newLog.protein = Int(data.protein)
                        newLog.carbs = Int(data.carbs)
                        newLog.fat = Int(data.fat)
                        modelContext.insert(newLog)
                    }
                }
            }
            
            await MainActor.run {
                withAnimation { isRefreshingHistory = false }
            }
        }
    }
    
    private func getWorkouts(for date: Date) -> [Workout] {
        workouts.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    private var logSheetContent: some View {
        NavigationView {
            Form {
                Section("Date & Mode") {
                    DatePicker("Log Date", selection: $selectedLogDate, displayedComponents: .date)
                    Picker("Mode", selection: $inputMode) {
                        Text("Add to Total").tag(0)
                        Text("Set Total").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                
                if isCalorieCountingEnabled {
                    Section("Energy") {
                        HStack {
                            Text("Calories")
                            Spacer()
                            TextField("kcal", text: $caloriesInput)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    Section("Macros (Optional)") {
                        HStack {
                            Text("Protein (g)")
                            Spacer()
                            TextField("0", text: $proteinInput)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Carbs (g)")
                            Spacer()
                            TextField("0", text: $carbsInput)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Fat (g)")
                            Spacer()
                            TextField("0", text: $fatInput)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    Section(footer: Text(inputMode == 0 ? "Values will be added to existing HealthKit data." : "Calculates the offset needed to reach this total.")) { }
                } else {
                    Section {
                        Text("Calorie counting is currently disabled in Settings.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Log Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingLogSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveLog() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func saveLog() {
        let logDate = Calendar.current.startOfDay(for: selectedLogDate)
        let calVal = Int(caloriesInput) ?? 0
        let pVal = Int(proteinInput) ?? 0
        let cVal = Int(carbsInput) ?? 0
        let fVal = Int(fatInput) ?? 0
        
        let existingLog = logs.first(where: { $0.date == logDate })
        
        if let log = existingLog {
            if inputMode == 0 {
                // Add Mode
                log.manualCalories += calVal
                log.caloriesConsumed += calVal
                
                log.manualProtein += pVal
                log.protein = (log.protein ?? 0) + pVal
                
                log.manualCarbs += cVal
                log.carbs = (log.carbs ?? 0) + cVal
                
                log.manualFat += fVal
                log.fat = (log.fat ?? 0) + fVal
                
            } else {
                // Set Mode
                let currentHKCalories = log.caloriesConsumed - log.manualCalories
                log.manualCalories = calVal - currentHKCalories
                log.caloriesConsumed = calVal
                
                if !proteinInput.isEmpty {
                    let currentHKP = (log.protein ?? 0) - log.manualProtein
                    log.manualProtein = pVal - currentHKP
                    log.protein = pVal
                }
                if !carbsInput.isEmpty {
                    let currentHKC = (log.carbs ?? 0) - log.manualCarbs
                    log.manualCarbs = cVal - currentHKC
                    log.carbs = cVal
                }
                if !fatInput.isEmpty {
                    let currentHKF = (log.fat ?? 0) - log.manualFat
                    log.manualFat = fVal - currentHKF
                    log.fat = fVal
                }
            }
            
            if log.goalType == nil { log.goalType = currentGoalType }
            
        } else {
            // New Log
            let newLog = DailyLog(
                date: logDate,
                caloriesConsumed: calVal,
                goalType: currentGoalType,
                protein: pVal,
                carbs: cVal,
                fat: fVal
            )
            newLog.manualCalories = calVal
            newLog.manualProtein = pVal
            newLog.manualCarbs = cVal
            newLog.manualFat = fVal
            
            modelContext.insert(newLog)
        }
        
        showingLogSheet = false
    }
    
    private func setupOnAppear() {
        healthManager.requestAuthorization()
        healthManager.fetchAllHealthData()
        
        if healthManager.caloriesConsumedToday > 0 {
            updateTodayLog { $0.caloriesConsumed = Int(healthManager.caloriesConsumedToday) + $0.manualCalories }
        }
        
        if enableCaloriesBurned {
            updateTodayLog { $0.caloriesBurned = Int(healthManager.caloriesBurnedToday) }
        }
        
        if healthManager.proteinToday > 0 { updateTodayLog { $0.protein = Int(healthManager.proteinToday) + $0.manualProtein } }
        if healthManager.carbsToday > 0 { updateTodayLog { $0.carbs = Int(healthManager.carbsToday) + $0.manualCarbs } }
        if healthManager.fatToday > 0 { updateTodayLog { $0.fat = Int(healthManager.fatToday) + $0.manualFat } }
    }
    
    private func updateTodayLog(update: (DailyLog) -> Void) {
        let todayDate = Calendar.current.startOfDay(for: Date())
        
        if let todayLog = logs.first(where: { $0.date == todayDate }) {
            update(todayLog)
        } else {
            let newLog = DailyLog(date: todayDate, goalType: currentGoalType)
            update(newLog)
            modelContext.insert(newLog)
        }
    }
    
    // Updated delete function to work with sections
    private func deleteItems(at offsets: IndexSet, from sectionLogs: [DailyLog]) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sectionLogs[index])
            }
        }
    }
    
    @ViewBuilder
    private var summaryHeader: some View {
        if let today = logs.first(where: { Calendar.current.isDateInToday($0.date) }) {
            let burned = enableCaloriesBurned ? today.caloriesBurned : 0
            let remaining = dailyGoal + burned - today.caloriesConsumed
            
            VStack(spacing: 5) {
                Text("\(remaining)")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(remaining < 0 ? .red : .blue)
                Text("Calories Left Today")
                    .font(.caption).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.05))
        }
    }
    
    private func logRow(for log: DailyLog) -> some View {
        let dailyWorkouts = getWorkouts(for: log.date)
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.date, format: .dateTime.day().month(.abbreviated).year())
                        .font(.body)
                    
                    if log.isOverridden && isCalorieCountingEnabled {
                        Image(systemName: "o.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
                
                HStack(spacing: 4) {
                    if let w = log.weight {
                        Text("\(w, specifier: "%.1f") kg")
                    }
                    if let goal = log.goalType {
                        Text("(\(goal))").font(.caption2).padding(2).background(Color.gray.opacity(0.1)).cornerRadius(4)
                    }
                    
                    ForEach(dailyWorkouts) { w in
                        Text("• \(w.category)").font(.caption2).foregroundColor(.blue)
                    }
                }
                .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            
            if isCalorieCountingEnabled {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "fork.knife").font(.caption2)
                        Text("\(log.caloriesConsumed) kcal")
                    }.foregroundColor(.blue)
                    
                    if enableCaloriesBurned {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill").font(.caption2)
                            Text("\(log.caloriesBurned) kcal")
                        }.foregroundColor(.orange)
                    }
                }
                .font(.subheadline)
            }
        }
    }
}
