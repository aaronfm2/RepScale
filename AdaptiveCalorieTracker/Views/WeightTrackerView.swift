import SwiftUI
import SwiftData

struct WeightTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    
    @State private var showingAddWeight = false
    @State private var newWeight: String = ""
    // 1. Add state to hold the selected date
    @State private var selectedDate: Date = Date()

    var body: some View {
        NavigationView {
            List {
                ForEach(weights) { entry in
                    HStack {
                        Text(entry.date, style: .date)
                        Spacer()
                        Text("\(entry.weight, specifier: "%.1f") kg")
                            .fontWeight(.semibold)
                    }
                }
                .onDelete(perform: deleteWeight)
            }
            .navigationTitle("Weight History")
            .toolbar {
                Button(action: {
                    selectedDate = Date() // Reset to today when opening
                    showingAddWeight = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddWeight) {
                VStack(spacing: 20) {
                    Text("Add Weight").font(.headline)
                    
                    // 2. Add the DatePicker
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                    
                    TextField("Enter weight (kg)", text: $newWeight)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .padding(.horizontal)
                    
                    Button("Save") {
                        if let weightDouble = Double(newWeight) {
                            // 3. Pass the selectedDate to the model
                            let entry = WeightEntry(date: selectedDate, weight: weightDouble)
                            modelContext.insert(entry)
                            
                            // Reset fields
                            newWeight = ""
                            showingAddWeight = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newWeight.isEmpty)
                }
                .padding()
                // Adjusted detent to .large to fit the graphical calendar
                .presentationDetents([.large])
            }
        }
    }

    private func deleteWeight(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(weights[index])
        }
    }
}
