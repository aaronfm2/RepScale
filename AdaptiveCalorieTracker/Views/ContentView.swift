import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    // Sort by date descending so newest logs are at the top
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @StateObject var healthManager = HealthManager()
    
    @AppStorage("dailyCalorieGoal") private var dailyGoal: Int = 2000
    // Access the current goal type setting
    @AppStorage("goalType") private var currentGoalType: String = "Cutting" // <--- NEW
    
    // Sheet State
    @State private var showingLogSheet = false
    @State private var caloriesInput = ""
    
    // 1. New State for Date and Input Mode
    @State private var selectedLogDate = Date()
    @State private var inputMode = 0 // 0 = Add, 1 = Set

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                summaryHeader
                
                List {
                    ForEach(logs) { log in
                        logRow(for: log)
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Daily Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Reset defaults when opening the sheet
                        selectedLogDate = Date()
                        caloriesInput = ""
                        inputMode = 0
                        showingLogSheet = true
                    }) {
                        Label("Add Calories", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                VStack(spacing: 20) {
                    Text("Manage Calories").font(.headline)
                    
                    // 2. Date Picker to choose which day to modify
                    DatePicker("Log Date", selection: $selectedLogDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(.horizontal)

                    // 3. Picker to switch between Adding or Overwriting
                    Picker("Mode", selection: $inputMode) {
                        Text("Add to Total").tag(0)
                        Text("Set Total").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    TextField("Calories (e.g. 500)", text: $caloriesInput)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .font(.title3)
                    
                    if inputMode == 1 {
                        Text("Warning: This will overwrite the current total for this date.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    HStack(spacing: 20) {
                        Button("Cancel", role: .cancel) {
                            showingLogSheet = false
                        }
                        
                        Button("Save") {
                            saveCalories()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(caloriesInput.isEmpty)
                    }
                }
                .presentationDetents([.medium])
                .padding()
            }
            .onAppear(perform: setupOnAppear)
            .onChange(of: healthManager.caloriesBurnedToday) { _, newValue in
                updateTodayBurned(newValue)
            }
        }
    }

    // MARK: - Logic Updates

    private func saveCalories() {
        guard let inputVal = Int(caloriesInput) else { return }
        
        // 4. Normalize the selected date
        let logDate = Calendar.current.startOfDay(for: selectedLogDate)
        
        // Find the log for that specific date
        if let existingLog = logs.first(where: { $0.date == logDate }) {
            if inputMode == 0 {
                // Add mode: Append to existing
                existingLog.caloriesConsumed += inputVal
            } else {
                // Set mode: Overwrite completely
                existingLog.caloriesConsumed = inputVal
            }
        } else {
            // Create new log if it doesn't exist, INCLUDING THE GOAL TYPE
            let newLog = DailyLog(date: logDate, caloriesConsumed: inputVal, goalType: currentGoalType) // <--- UPDATED
            modelContext.insert(newLog)
        }
        
        showingLogSheet = false
    }
    
    // ... (Existing helper functions) ...
    
    private func setupOnAppear() {
        healthManager.requestAuthorization()
        healthManager.fetchTodayCaloriesBurned()
        
        // Use AppStorage directly here if needed, but saveCalories handles manual adds.
        // For auto-creation on load, we assume 'Cutting' default or whatever is in AppStorage
    }
    
    private func updateTodayBurned(_ newValue: Double) {
        let todayDate = Calendar.current.startOfDay(for: Date())
        if let today = logs.first(where: { $0.date == todayDate }) {
            today.caloriesBurned = Int(newValue)
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
        HStack {
            VStack(alignment: .leading) {
                Text(log.date, style: .date).font(.body)
                if let w = log.weight {
                    // Display Weight AND Goal Type
                    HStack(spacing: 4) {
                        Text("\(w, specifier: "%.1f") kg")
                        if let goal = log.goalType {
                            Text("(\(goal))") // <--- NEW DISPLAY
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
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
