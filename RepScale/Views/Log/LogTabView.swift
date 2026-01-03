import SwiftUI
import SwiftData

struct LogTabView: View {
    // --- CLOUD SYNC: Injected Profile ---
    @Bindable var profile: UserProfile
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    
    // Fetch workouts to link them to logs
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    // Fetch Weight Entries to find the starting date
    @Query(sort: \WeightEntry.date, order: .forward) private var weightEntries: [WeightEntry]
    
    @EnvironmentObject var healthManager: HealthManager

    // MARK: - Color Palette
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var cardBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.153, green: 0.153, blue: 0.165) : Color.white
    }
    
    // Sheet State
    @State private var showingLogSheet = false
    @State private var selectedLogDate = Date()
    @State private var inputMode = 0
    @State private var showingInfoSheet = false
    @State private var isRefreshingHistory = false
    
    // Inputs
    @State private var caloriesInput = ""
    @State private var proteinInput = ""
    @State private var carbsInput = ""
    @State private var fatInput = ""

    // --- FOCUS STATE MANAGEMENT ---
    enum LogField {
        case calories, protein, carbs, fat
    }
    @FocusState private var focusedField: LogField?

    // MARK: - Computed Properties for Grouping
    struct LogSection: Identifiable {
        var id: Date { month }
        let month: Date
        let logs: [DailyLog]
    }
    
    var groupedSections: [LogSection] {
        let grouped = Dictionary(grouping: logs) { log in
            Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: log.date))!
        }
        let sortedMonths = grouped.keys.sorted(by: >)
        return sortedMonths.map { month in
            LogSection(month: month, logs: grouped[month]!)
        }
    }
    
    var averageCalories30Days: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        
        let recentLogs = logs.filter {
            $0.date >= thirtyDaysAgo &&
            $0.date < today &&
            $0.caloriesConsumed > 0
        }
        
        guard !recentLogs.isEmpty else { return 0 }
        let total = recentLogs.reduce(0) { $0 + $1.caloriesConsumed }
        return total / recentLogs.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary Header
                if profile.isCalorieCountingEnabled {
                    summaryHeader
                        .background(appBackgroundColor)
                        .padding(.top, 8)
                }
                
                // List
                List {
                    ForEach(groupedSections) { section in
                        Section(header: Text(section.month, format: .dateTime.month(.wide).year())) {
                            ForEach(section.logs) { log in
                                NavigationLink(destination: LogDetailView(
                                    log: log,
                                    workouts: getWorkouts(for: log.date),
                                    weightEntry: getWeightEntry(for: log.date),
                                    profile: profile
                                )) {
                                    logRow(for: log)
                                }
                                .listRowBackground(cardBackgroundColor)
                            }
                            .onDelete { indexSet in
                                deleteItems(at: indexSet, from: section.logs)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(appBackgroundColor)
            }
            .background(appBackgroundColor)
            .navigationTitle("Daily Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingInfoSheet = true }) {
                        Image(systemName: "info.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if profile.enableHealthKitSync {
                            Button(action: refreshLast365Days) {
                                if isRefreshingHistory {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .disabled(isRefreshingHistory)
                        }
                        
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
                        .spotlightTarget(.addLog)
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                logSheetContent
            }
            .sheet(isPresented: $showingInfoSheet) {
                AppleHealthInfoSheet(profile: profile)
            }
            .onAppear(perform: setupOnAppear)
            .onChange(of: healthManager.caloriesBurnedToday) { _, newValue in
                if profile.enableHealthKitSync {
                    updateTodayLog { $0.caloriesBurned = Int(newValue) }
                }
            }
            .onChange(of: healthManager.caloriesConsumedToday) { _, newValue in
                if profile.enableHealthKitSync && newValue > 0 {
                    updateTodayLog { $0.caloriesConsumed = Int(newValue) + $0.manualCalories }
                }
            }
            .onChange(of: healthManager.proteinToday) { _, newValue in
                if profile.enableHealthKitSync && newValue > 0 {
                    updateTodayLog { $0.protein = Int(newValue) + $0.manualProtein }
                }
            }
            .onChange(of: healthManager.carbsToday) { _, newValue in
                if profile.enableHealthKitSync && newValue > 0 {
                    updateTodayLog { $0.carbs = Int(newValue) + $0.manualCarbs }
                }
            }
            .onChange(of: healthManager.fatToday) { _, newValue in
                if profile.enableHealthKitSync && newValue > 0 {
                    updateTodayLog { $0.fat = Int(newValue) + $0.manualFat }
                }
            }
        }
    }

    // MARK: - Helper Methods
    
    /// Checks for duplicate DailyLog entries for the same date and removes them.
    /// Keeps the entry with the most manual data or the first one found.
    private func deduplicateLogs() {
        let grouped = Dictionary(grouping: logs) { Calendar.current.startOfDay(for: $0.date) }
        
        for (_, dayLogs) in grouped where dayLogs.count > 1 {
            // Sort by data "richness" to decide which one to keep
            let sorted = dayLogs.sorted {
                let s1 = abs($0.manualCalories) + abs($0.manualProtein)
                let s2 = abs($1.manualCalories) + abs($1.manualProtein)
                return s1 > s2
            }
            
            if let keep = sorted.first {
                print("Deduplicating logs for date \(keep.date). Keeping 1, deleting \(sorted.count - 1).")
                for duplicate in sorted.dropFirst() {
                    modelContext.delete(duplicate)
                }
            }
        }
    }

    /// Fetches a log directly from the context to avoid stale Query results
    private func fetchLog(for date: Date) -> DailyLog? {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == normalizedDate }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func refreshLast365Days() {
        guard profile.enableHealthKitSync else { return }
        isRefreshingHistory = true
        let firstWeightDate = weightEntries.first?.date
        
        Task {
            let today = Calendar.current.startOfDay(for: Date())
            let dataManager = DataManager(modelContext: modelContext)
            
            for i in 0..<365 {
                guard let date = Calendar.current.date(byAdding: .day, value: -i, to: today) else { continue }
                
                if let startLimit = firstWeightDate {
                    let startOfDayLimit = Calendar.current.startOfDay(for: startLimit)
                    if date < startOfDayLimit {
                        continue
                    }
                }
                
                // Fetch Nutrition
                let data = await healthManager.fetchHistoricalHealthData(for: date)
                // Fetch Weight
                let weight = await healthManager.fetchBodyMass(for: date)
                
                await MainActor.run {
                    let normalizedDate = Calendar.current.startOfDay(for: date)
                    
                    // 1. Update Logs (Refined Logic with Direct Fetch)
                    // Use a direct fetch to check for existence, bypassing potential @Query lag
                    let descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.date == normalizedDate })
                    let existingLog = try? modelContext.fetch(descriptor).first
                    
                    if let log = existingLog {
                        log.caloriesConsumed = Int(data.consumed) + log.manualCalories
                        if profile.enableCaloriesBurned { log.caloriesBurned = Int(data.burned) }
                        log.protein = Int(data.protein) + log.manualProtein
                        log.carbs = Int(data.carbs) + log.manualCarbs
                        log.fat = Int(data.fat) + log.manualFat
                        
                    } else if data.consumed > 0 || data.burned > 0 {
                        let newLog = DailyLog(date: date, goalType: profile.goalType)
                        newLog.caloriesConsumed = Int(data.consumed)
                        if profile.enableCaloriesBurned { newLog.caloriesBurned = Int(data.burned) }
                        newLog.protein = Int(data.protein)
                        newLog.carbs = Int(data.carbs)
                        newLog.fat = Int(data.fat)
                        modelContext.insert(newLog)
                    }
                    
                    // 2. Update Weight
                    if weight > 0 {
                        let hasWeightEntry = weightEntries.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
                        if !hasWeightEntry {
                            dataManager.addWeightEntry(date: date, weight: weight, goalType: profile.goalType)
                        }
                    }
                }
            }
            
            await MainActor.run {
                deduplicateLogs() // Run cleanup after refresh
                withAnimation { isRefreshingHistory = false }
            }
        }
    }
    
    private func getWorkouts(for date: Date) -> [Workout] {
        workouts.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    private func getWeightEntry(for date: Date) -> WeightEntry? {
        let dayEntries = weightEntries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
        return dayEntries.last
    }
    
    private var logSheetContent: some View {
        NavigationStack {
            Form {
                Section("Date & Mode") {
                    DatePicker("Log Date", selection: $selectedLogDate, displayedComponents: .date)
                    Picker("Mode", selection: $inputMode) {
                        Text("Add to Total").tag(0)
                        Text("Set Total").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                
                if profile.isCalorieCountingEnabled {
                    Section("Energy") {
                        HStack {
                            Text("Calories")
                            Spacer()
                            TextField("kcal", text: $caloriesInput)
                                .focused($focusedField, equals: .calories)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    Section("Macros (Optional)") {
                        HStack {
                            Text("Protein (g)")
                            Spacer()
                            TextField("0", text: $proteinInput)
                                .focused($focusedField, equals: .protein)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Carbs (g)")
                            Spacer()
                            TextField("0", text: $carbsInput)
                                .focused($focusedField, equals: .carbs)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Fat (g)")
                            Spacer()
                            TextField("0", text: $fatInput)
                                .focused($focusedField, equals: .fat)
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
                
                Section {
                    Color.clear
                        .frame(height: 350)
                }
                .listRowBackground(Color.clear)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Log Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingLogSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveLog() }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.large])
    }

    private func saveLog() {
        let logDate = Calendar.current.startOfDay(for: selectedLogDate)
        let calVal = Int(caloriesInput) ?? 0
        let pVal = Int(proteinInput) ?? 0
        let cVal = Int(carbsInput) ?? 0
        let fVal = Int(fatInput) ?? 0
        
        let dayWeights = weightEntries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: logDate)
        }
        let latestWeight = dayWeights.sorted(by: { $0.date < $1.date }).last?.weight
        
        // Use direct fetch instead of @Query array to ensure we find the log if it exists
        let existingLog = fetchLog(for: logDate)
        
        if let log = existingLog {
            if let w = latestWeight {
                log.weight = w
            }
            
            if inputMode == 0 {
                log.manualCalories += calVal
                log.caloriesConsumed += calVal
                log.manualProtein += pVal
                log.protein = (log.protein ?? 0) + pVal
                log.manualCarbs += cVal
                log.carbs = (log.carbs ?? 0) + cVal
                log.manualFat += fVal
                log.fat = (log.fat ?? 0) + fVal
            } else {
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
            if log.goalType == nil { log.goalType = profile.goalType }
        } else {
            let newLog = DailyLog(
                date: logDate,
                weight: latestWeight,
                caloriesConsumed: calVal,
                goalType: profile.goalType,
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
        deduplicateLogs() // Clean up any duplicates on appear
        
        if profile.enableHealthKitSync {
            healthManager.requestAuthorization()
            healthManager.fetchAllHealthData()
        }
            
        for log in logs {
            let dayWeights = weightEntries.filter {
                Calendar.current.isDate($0.date, inSameDayAs: log.date)
            }
            
            if let latestEntry = dayWeights.sorted(by: { $0.date < $1.date }).last {
                if log.weight != latestEntry.weight {
                    log.weight = latestEntry.weight
                }
            }
        }

        if healthManager.caloriesConsumedToday > 0 {
            updateTodayLog { $0.caloriesConsumed = Int(healthManager.caloriesConsumedToday) + $0.manualCalories }
        }
        if profile.enableCaloriesBurned {
            updateTodayLog { $0.caloriesBurned = Int(healthManager.caloriesBurnedToday) }
        }
        if healthManager.proteinToday > 0 { updateTodayLog { $0.protein = Int(healthManager.proteinToday) + $0.manualProtein } }
        if healthManager.carbsToday > 0 { updateTodayLog { $0.carbs = Int(healthManager.carbsToday) + $0.manualCarbs } }
        if healthManager.fatToday > 0 { updateTodayLog { $0.fat = Int(healthManager.fatToday) + $0.manualFat } }
    }
    
    private func updateTodayLog(update: (DailyLog) -> Void) {
        let todayDate = Calendar.current.startOfDay(for: Date())
        
        // Use direct fetch to prevent creating a duplicate if @Query hasn't updated yet
        if let todayLog = fetchLog(for: todayDate) {
            update(todayLog)
        } else {
            let newLog = DailyLog(date: todayDate, goalType: profile.goalType)
            update(newLog)
            modelContext.insert(newLog)
        }
    }
    
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
            let burned = profile.enableCaloriesBurned ? today.caloriesBurned : 0
            let consumed = today.caloriesConsumed
            let remaining = profile.dailyCalorieGoal + burned - consumed
            
            // Progress Calculation
            let totalBudget = Double(profile.dailyCalorieGoal + burned)
            let progress = totalBudget > 0 ? Double(consumed) / totalBudget : 0
            let isOverBudget = remaining < 0
            
            VStack(spacing: 16) {
                HStack(alignment: .center, spacing: 24) {
                    // 1. Progress Ring
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 10)
                            .opacity(0.15)
                            .foregroundColor(isOverBudget ? .red : .blue)
                        
                        Circle()
                            .trim(from: 0.0, to: min(progress, 1.0))
                            .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                            .foregroundColor(isOverBudget ? .red : .blue)
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear, value: progress)
                        
                        VStack(spacing: 2) {
                            Text("\(remaining)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(isOverBudget ? .red : .primary)
                            Text("Left")
                                .font(.system(size: 10, weight: .bold))
                                .textCase(.uppercase)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 100, height: 100)
                    
                    // 2. Stats Column
                    if profile.enableCaloriesBurned {
                        // Full Layout with Exercise
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Goal").font(.caption2).bold().foregroundColor(.secondary)
                                    HStack(spacing: 2) {
                                        Text("\(profile.dailyCalorieGoal)").font(.system(.callout, design: .rounded)).fontWeight(.semibold)
                                        Text("kcal").font(.system(size: 10)).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Food").font(.caption2).bold().foregroundColor(.secondary)
                                    HStack(spacing: 2) {
                                        Text("\(consumed)").font(.system(.callout, design: .rounded)).fontWeight(.semibold)
                                        Text("kcal").font(.system(size: 10)).foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Exercise").font(.caption2).bold().foregroundColor(.orange)
                                    HStack(spacing: 2) {
                                        Text("\(burned)").font(.system(.callout, design: .rounded)).fontWeight(.semibold).foregroundColor(.orange)
                                        Text("kcal").font(.system(size: 10)).foregroundColor(.orange.opacity(0.8))
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Net").font(.caption2).bold().foregroundColor(.secondary)
                                    HStack(spacing: 2) {
                                        Text("\(consumed - burned)").font(.system(.callout, design: .rounded)).fontWeight(.semibold)
                                        Text("kcal").font(.system(size: 10)).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    } else {
                        // Simple Layout (Goal & Food Only)
                        HStack(spacing: 0) {
                            Spacer()
                            VStack(spacing: 4) {
                                Text("Daily Goal")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                HStack(spacing: 2) {
                                    Text("\(profile.dailyCalorieGoal)")
                                        .font(.system(.title3, design: .rounded))
                                        .bold()
                                    Text("kcal").font(.system(size: 12)).foregroundColor(.secondary).fontWeight(.medium)
                                }
                            }
                            
                            Spacer()
                            Divider().frame(height: 35)
                            Spacer()
                            
                            VStack(spacing: 4) {
                                Text("Consumed")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                HStack(spacing: 2) {
                                    Text("\(consumed)")
                                        .font(.system(.title3, design: .rounded))
                                        .bold()
                                    Text("kcal").font(.system(size: 12)).foregroundColor(.secondary).fontWeight(.medium)
                                }
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Bottom Row: 30-Day Avg
                if averageCalories30Days > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        Text("30-Day Average: \(averageCalories30Days) kcal")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(cardBackgroundColor))
            .padding(.horizontal)
            .padding(.bottom, 8)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    private func logRow(for log: DailyLog) -> some View {
        let dailyWorkouts = getWorkouts(for: log.date)
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.date, format: .dateTime.day().month(.abbreviated).year())
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if log.isOverridden && profile.isCalorieCountingEnabled {
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
            
            if profile.isCalorieCountingEnabled {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "fork.knife").font(.caption2)
                        Text("\(log.caloriesConsumed) kcal")
                    }.foregroundColor(.blue)
                    
                    if profile.enableCaloriesBurned {
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

// MARK: - Apple Health Info Sheet
struct AppleHealthInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var healthManager: HealthManager
    
    // --- CLOUD SYNC: Injected Profile ---
    var profile: UserProfile
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Image
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                        .padding(.top, 20)
                    
                    // Title & Description
                    VStack(spacing: 12) {
                        Text("Apple Health Integration")
                            .font(.title2).bold()
                        
                        Text("RepScale connects seamlessly with Apple Health to keep your nutrition goals up to date.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    // Instructions Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How to connect other apps")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            InstructionRow(num: 1, text: "Log your meals in apps like MyFitnessPal, Cronometer, or Lose It!")
                            InstructionRow(num: 2, text: "Open that app's settings and ensure 'Write to Apple Health' is enabled.")
                            InstructionRow(num: 3, text: "RepScale will automatically read that data to update your daily summaries here.")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(profile.isDarkMode ? Color.gray.opacity(0.1) : Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Apple Health Troubleshooting
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Apple Health Troubleshooting")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            InstructionRow(num: 1, text: "Open the Health app.")
                            InstructionRow(num: 2, text: "Tap Sharing -> Apps -> RepScale.")
                            InstructionRow(num: 3, text: "Then turn on all.")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(profile.isDarkMode ? Color.gray.opacity(0.1) : Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("Sync Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .background(profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground))
        }
    }
}

struct InstructionRow: View {
    let num: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(num)")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue.opacity(0.1)))
                .foregroundColor(.blue)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
