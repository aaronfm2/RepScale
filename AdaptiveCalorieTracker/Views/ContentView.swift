import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    
    // Fetch workouts to link them to logs
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    @StateObject var healthManager = HealthManager()
    @AppStorage("dailyCalorieGoal") private var dailyGoal: Int = 2000
    @AppStorage("goalType") private var currentGoalType: String = "Cutting"
    
    // Sheet State
    @State private var showingLogSheet = false
    @State private var selectedLogDate = Date()
    @State private var inputMode = 0
    
    // Inputs
    @State private var caloriesInput = ""
    @State private var proteinInput = ""
    @State private var carbsInput = ""
    @State private var fatInput = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                summaryHeader
                
                List {
                    ForEach(logs) { log in
                        // --- NAVIGATION LINK ---
                        NavigationLink(destination: LogDetailView(
                            log: log,
                            workout: getWorkout(for: log.date)
                        )) {
                            logRow(for: log)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Daily Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedLogDate = Date()
                        caloriesInput = ""
                        proteinInput = ""
                        carbsInput = ""
                        fatInput = ""
                        inputMode = 0
                        showingLogSheet = true
                    }) {
                        Label("Add Log", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                logSheetContent
            }
            .onAppear(perform: setupOnAppear)
            // --- SYNC HEALTHKIT DATA CHANGES ---
            .onChange(of: healthManager.caloriesBurnedToday) { _, newValue in
                updateTodayLog { $0.caloriesBurned = Int(newValue) }
            }
            .onChange(of: healthManager.caloriesConsumedToday) { _, newValue in
                // Only update if HealthKit has data (> 0) to avoid wiping manual entries on launch if HK is slow
                if newValue > 0 {
                    updateTodayLog { $0.caloriesConsumed = Int(newValue) }
                }
            }
            .onChange(of: healthManager.proteinToday) { _, newValue in
                if newValue > 0 {
                    updateTodayLog { $0.protein = Int(newValue) }
                }
            }
            .onChange(of: healthManager.carbsToday) { _, newValue in
                if newValue > 0 {
                    updateTodayLog { $0.carbs = Int(newValue) }
                }
            }
            .onChange(of: healthManager.fatToday) { _, newValue in
                if newValue > 0 {
                    updateTodayLog { $0.fat = Int(newValue) }
                }
            }
            // ------------------------------------
        }
    }

    // MARK: - Helper Methods
    
    private func getWorkout(for date: Date) -> Workout? {
        // Find workout on the same calendar day
        workouts.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
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
                
                if inputMode == 1 {
                    Section {
                        Text("Warning: 'Set Total' overwrites existing data for this date.")
                            .font(.caption).foregroundColor(.red)
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
        let pVal = Int(proteinInput)
        let cVal = Int(carbsInput)
        let fVal = Int(fatInput)
        
        if let existingLog = logs.first(where: { $0.date == logDate }) {
            if inputMode == 0 {
                // Add mode: Append calories, but for macros we usually just overwrite or add if not nil
                existingLog.caloriesConsumed += calVal
            } else {
                existingLog.caloriesConsumed = calVal
            }
            
            // Update macros if user typed something
            if pVal != nil { existingLog.protein = pVal }
            if cVal != nil { existingLog.carbs = cVal }
            if fVal != nil { existingLog.fat = fVal }
            
            if existingLog.goalType == nil { existingLog.goalType = currentGoalType }
            
        } else {
            let newLog = DailyLog(
                date: logDate,
                caloriesConsumed: calVal,
                goalType: currentGoalType,
                protein: pVal,
                carbs: cVal,
                fat: fVal
            )
            modelContext.insert(newLog)
        }
        
        showingLogSheet = false
    }
    
    private func setupOnAppear() {
        healthManager.requestAuthorization()
        // Call the new method that fetches everything (Calories Burned + Nutrition)
        healthManager.fetchAllHealthData()
    }
    
    // Generic helper to update Today's log safely
    private func updateTodayLog(update: (DailyLog) -> Void) {
        let todayDate = Calendar.current.startOfDay(for: Date())
        
        if let todayLog = logs.first(where: { $0.date == todayDate }) {
            // Update existing log
            update(todayLog)
        } else {
            // Create new log if it doesn't exist yet (e.g. first launch of the day)
            let newLog = DailyLog(date: todayDate, goalType: currentGoalType)
            update(newLog)
            modelContext.insert(newLog)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets { modelContext.delete(logs[index]) }
        }
    }
    
    @ViewBuilder
    private var summaryHeader: some View {
        if let today = logs.first(where: { Calendar.current.isDateInToday($0.date) }) {
            let remaining = dailyGoal + today.caloriesBurned - today.caloriesConsumed
            VStack(spacing: 5) {
                Text("\(remaining)")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.blue)
                Text("Calories Left Today")
                    .font(.caption).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.05))
        }
    }
    
    private func logRow(for log: DailyLog) -> some View {
        let workout = getWorkout(for: log.date)
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.date, style: .date).font(.body)
                HStack(spacing: 4) {
                    if let w = log.weight {
                        Text("\(w, specifier: "%.1f") kg")
                    }
                    if let goal = log.goalType {
                        Text("(\(goal))").font(.caption2).padding(2).background(Color.gray.opacity(0.1)).cornerRadius(4)
                    }
                    if let w = workout {
                        Text("• \(w.category)").font(.caption2).foregroundColor(.blue)
                    }
                }
                .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "fork.knife").font(.caption2)
                    Text("\(log.caloriesConsumed) kcal")
                }.foregroundColor(.blue)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.caption2)
                    Text("\(log.caloriesBurned) kcal")
                }.foregroundColor(.orange)
            }
            .font(.subheadline)
        }
    }
}
