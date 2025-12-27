import SwiftUI
import SwiftData

struct WeightTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    // Sort by date descending
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    
    @AppStorage("goalType") private var currentGoalType: String = GoalType.cutting.rawValue
    
    @State private var showingAddWeight = false
    @State private var newWeight: String = ""
    @State private var selectedDate: Date = Date()

    // Helper to initialize DataManager with the current context
    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }

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
        
        // --- CHANGED: Use DataManager ---
        // This handles both inserting the weight AND syncing it to the DailyLog
        dataManager.addWeightEntry(date: selectedDate, weight: weightDouble, goalType: currentGoalType)
        
        // Reset and close
        newWeight = ""
        showingAddWeight = false
    }

    private func deleteWeight(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let weightToDelete = weights[index]
                
                // --- CHANGED: Use DataManager ---
                // This deletes the weight AND fixes the DailyLog if necessary
                dataManager.deleteWeightEntry(weightToDelete)
            }
        }
    }
}
