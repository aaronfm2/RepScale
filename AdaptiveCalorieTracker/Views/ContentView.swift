import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @StateObject var healthManager = HealthManager()
    
    @AppStorage("dailyCalorieGoal") private var dailyGoal: Int = 2000
    
    // 1. Add state variables for the input sheet
    @State private var showingLogSheet = false
    @State private var caloriesInput = ""

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
                
                // 2. Change the "+" button to open the sheet
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingLogSheet = true }) {
                        Label("Add Calories", systemImage: "plus")
                    }
                }
            }
            // 3. Add the Sheet for entering calories
            .sheet(isPresented: $showingLogSheet) {
                VStack(spacing: 20) {
                    Text("Log Food").font(.headline)
                    
                    TextField("Calories (e.g. 500)", text: $caloriesInput)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .font(.title3)
                    
                    HStack(spacing: 20) {
                        Button("Cancel", role: .cancel) {
                            caloriesInput = ""
                            showingLogSheet = false
                        }
                        
                        Button("Add Calories") {
                            saveCalories()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(caloriesInput.isEmpty)
                    }
                }
                .presentationDetents([.height(200)]) // Keeps the sheet small
                .padding()
            }
            .onAppear(perform: setupOnAppear)
            .onChange(of: healthManager.caloriesBurnedToday) { _, newValue in
                updateTodayBurned(newValue)
            }
        }
    }

    // ... (Keep your existing summaryHeader and logRow code here) ...

    // 4. Update the Save Logic
    private func saveCalories() {
        guard let addedCalories = Int(caloriesInput) else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        // Find today's log, or create one if it doesn't exist
        if let todayLog = logs.first(where: { $0.date == today }) {
            todayLog.caloriesConsumed += addedCalories // Adds to existing total
        } else {
            let newLog = DailyLog(date: today, caloriesConsumed: addedCalories)
            modelContext.insert(newLog)
        }
        
        // Reset and close
        caloriesInput = ""
        showingLogSheet = false
    }
    
    // ... (Keep existing setupOnAppear, updateTodayBurned, and deleteItems) ...
    
    // Remove the old 'addItem' function since 'saveCalories' handles creation now.
    // If you need it for setupOnAppear, just make sure it creates a blank log:
    private func setupOnAppear() {
        healthManager.requestAuthorization()
        healthManager.fetchTodayCaloriesBurned()
        
        let today = Calendar.current.startOfDay(for: Date())
        if !logs.contains(where: { $0.date == today }) {
             let newItem = DailyLog(date: today)
             modelContext.insert(newItem)
        }
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
    
    // Helper subviews (Copy from previous response if needed)
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
                    Text("\(w, specifier: "%.1f") kg").font(.caption).foregroundColor(.secondary)
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
