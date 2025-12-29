import SwiftUI
import SwiftData

struct WeightTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    
    @AppStorage("goalType") private var currentGoalType: String = GoalType.cutting.rawValue
    // --- NEW ---
    @AppStorage("unitSystem") private var unitSystem: String = UnitSystem.metric.rawValue
    
    // MARK: - Dark Mode & Colors
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true

    var appBackgroundColor: Color {
        isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var cardBackgroundColor: Color {
        isDarkMode ? Color(red: 0.153, green: 0.153, blue: 0.165) : Color.white
    }
    
    @State private var showingAddWeight = false
    @State private var newWeight: String = ""
    @State private var selectedDate: Date = Date()
    @FocusState private var isInputFocused: Bool

    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }
    
    var weightLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }

    var body: some View {
        NavigationStack {
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
                    .listRowBackground(cardBackgroundColor) // Apply Card Color
                }
                .onDelete(perform: deleteWeight)
            }
            .scrollContentBackground(.hidden) // Hide system default
            .background(appBackgroundColor)   // Apply Main Background
            .navigationTitle("Weight History")
            .toolbar {
                Button(action: {
                    selectedDate = Date()
                    newWeight = ""
                    showingAddWeight = true
                }) {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .spotlightTarget(.addWeight)
            }
            .sheet(isPresented: $showingAddWeight) {
                            NavigationStack {
                                Form {
                                    // Section 1: Date
                                    Section {
                                        DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                                    }
                                    
                                    // Section 2: Weight Input
                                    Section {
                                        HStack {
                                            Text("Weight")
                                                .font(.headline)
                                            
                                            Spacer()
                                            
                                            TextField("0.0", text: $newWeight)
                                                .keyboardType(.decimalPad)
                                                .multilineTextAlignment(.trailing)
                                                .font(.title3)
                                                .focused($isInputFocused)
                                                .frame(minWidth: 50)
                                            
                                            Text(weightLabel)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    // Section 3: Save Button
                                    Section {
                                        Button("Save Entry") {
                                            saveWeight()
                                        }
                                        .bold()
                                        .frame(maxWidth: .infinity)
                                        .disabled(newWeight.isEmpty)
                                    }
                                }
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
                            .presentationDetents([.medium, .large])
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
