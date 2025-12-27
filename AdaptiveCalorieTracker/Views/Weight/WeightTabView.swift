import SwiftUI
import SwiftData

struct WeightTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    
    @AppStorage("goalType") private var currentGoalType: String = GoalType.cutting.rawValue
    // --- NEW ---
    @AppStorage("unitSystem") private var unitSystem: String = UnitSystem.metric.rawValue
    
    @State private var showingAddWeight = false
    @State private var newWeight: String = ""
    @State private var selectedDate: Date = Date()
    @FocusState private var isInputFocused: Bool

    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }
    
    var weightLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }

    var body: some View {
        NavigationView {
            List {
                ForEach(weights) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.date, format: .dateTime.day().month().year())
                                .font(.body)
                            Text(entry.date, format: .dateTime.hour().minute())
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        // --- UPDATED: Display converted weight ---
                        Text("\(entry.weight.toUserWeight(system: unitSystem), specifier: "%.1f") \(weightLabel)")
                            .fontWeight(.semibold)
                            .font(.title3)
                    }
                }
                .onDelete(perform: deleteWeight)
            }
            .navigationTitle("Weight History")
            .toolbar {
                Button(action: {
                    selectedDate = Date()
                    newWeight = ""
                    showingAddWeight = true
                }) {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
            }
            .sheet(isPresented: $showingAddWeight) {
                NavigationView {
                    VStack(spacing: 20) {
                        DatePicker("Date & Time", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                            .padding()
                        
                        HStack {
                            Text("Weight (\(weightLabel))")
                            Spacer()
                            TextField("0.0", text: $newWeight)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.decimalPad)
                                .frame(width: 100)
                                .focused($isInputFocused)
                        }
                        .padding(.horizontal)
                        
                        Button("Save Entry") {
                            saveWeight()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newWeight.isEmpty)
                        
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Log Weight")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { isInputFocused = false }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingAddWeight = false }
                        }
                    }
                }
                .presentationDetents([.large])
            }
        }
    }

    private func saveWeight() {
        guard let userValue = Double(newWeight) else { return }
        
        // --- UPDATED: Convert User Input -> Storage (Metric) ---
        let storedValue = userValue.toStoredWeight(system: unitSystem)
        
        dataManager.addWeightEntry(date: selectedDate, weight: storedValue, goalType: currentGoalType)
        newWeight = ""
        showingAddWeight = false
    }
    
    private func deleteWeight(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                dataManager.deleteWeightEntry(weights[index])
            }
        }
    }
}
