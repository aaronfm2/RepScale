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
    
    // 1. Add FocusState to control the keyboard
    @FocusState private var isInputFocused: Bool

    // Use the DataManager for clean logic
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
                    selectedDate = Date()
                    newWeight = ""
                    showingAddWeight = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .sheet(isPresented: $showingAddWeight) {
                // 2. Wrap in NavigationView so the toolbar appears correctly
                NavigationView {
                    VStack(spacing: 20) {
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
                                .focused($isInputFocused) // 3. Bind focus state
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
                        // 4. Add a 'Done' button to the keyboard
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isInputFocused = false
                            }
                        }
                        
                        // Optional: Add a Cancel button to the top-left
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingAddWeight = false
                            }
                        }
                    }
                }
                .presentationDetents([.large]) // Ensure it has enough height
            }
        }
    }

    private func saveWeight() {
        guard let weightDouble = Double(newWeight) else { return }
        
        // Use DataManager to save and sync
        dataManager.addWeightEntry(date: selectedDate, weight: weightDouble, goalType: currentGoalType)
        
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
