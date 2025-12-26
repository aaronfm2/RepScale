import SwiftUI
import SwiftData

struct WeightTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    // Sort by date descending
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    
    @AppStorage("goalType") private var currentGoalType: String = "Cutting"
    
    @State private var showingAddWeight = false
    @State private var newWeight: String = ""
    @State private var selectedDate: Date = Date()

    var body: some View {
        NavigationView {
            List {
                ForEach(weights) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.date, format: .dateTime.day().month().year())
                                .font(.body)
                            Text(entry.date, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(entry.weight, specifier: "%.1f") kg")
                            .fontWeight(.semibold)
                            .font(.title3)
                    }
                }
                .onDelete(perform: deleteWeight)
            }
            .navigationTitle("Weight History")
            .toolbar {
                Button(action: {
                    // Quick Add: Defaults to NOW when opened
                    selectedDate = Date()
                    newWeight = ""
                    showingAddWeight = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddWeight) {
                VStack(spacing: 20) {
                    Text("Log Weight").font(.headline)
                    
                    DatePicker("Date & Time", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .padding()
                    
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("0.0", text: $newWeight)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .frame(width: 100)
                    }
                    .padding(.horizontal)
                    
                    Button("Save Entry") {
                        saveWeight()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newWeight.isEmpty)
                }
                .padding()
                .presentationDetents([.large])
            }
        }
    }

    private func saveWeight() {
        guard let weightDouble = Double(newWeight) else { return }
        
        // 1. Save to Weight History (The list you see in this tab)
        let entry = WeightEntry(date: selectedDate, weight: weightDouble)
        modelContext.insert(entry)
        
        // 2. SYNC to Daily Log (The list you see in "Logs" tab)
        syncToDailyLog(date: selectedDate, weight: weightDouble)
        
        // Reset and close
        newWeight = ""
        showingAddWeight = false
    }

    private func syncToDailyLog(date: Date, weight: Double) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        
        let fetchDescriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == normalizedDate }
        )
        
        do {
            if let existingLog = try modelContext.fetch(fetchDescriptor).first {
                existingLog.weight = weight
                
                // --- FIX: Backfill Goal Type if missing ---
                if existingLog.goalType == nil {
                    existingLog.goalType = currentGoalType
                }
                // ------------------------------------------
                
            } else {
                // Include goalType when creating new log
                let newLog = DailyLog(date: normalizedDate, weight: weight, goalType: currentGoalType)
                modelContext.insert(newLog)
            }
        } catch {
            print("Failed to sync weight to daily log: \(error)")
        }
    }

    private func deleteWeight(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(weights[index])
            }
        }
    }
}
