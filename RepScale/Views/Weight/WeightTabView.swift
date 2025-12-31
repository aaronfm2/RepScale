import SwiftUI
import SwiftData

struct WeightTrackerView: View {
    // --- CLOUD SYNC: Injected Profile ---
    @Bindable var profile: UserProfile
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    
    // We fetch all periods to determine streaks and phase history
    @Query(filter: #Predicate<GoalPeriod> { $0.endDate == nil }) private var activeGoalPeriods: [GoalPeriod]
    @Query(sort: \GoalPeriod.startDate, order: .reverse) private var allGoalPeriods: [GoalPeriod]
    
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var cardBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.153, green: 0.153, blue: 0.165) : Color.white
    }
    
    @State private var showingAddWeight = false
    @State private var showingStats = false
    @State private var showingReconfigureGoal = false
    
    // --- Edit State ---
    @State private var selectedEntry: WeightEntry?
    
    // --- Add Sheet State ---
    @State private var newWeight: String = ""
    @State private var newNote: String = ""
    @State private var selectedDate: Date = Date()
    @FocusState private var isInputFocused: Bool

    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }
    
    var weightLabel: String { profile.unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    
    // Helper to simplify the ViewBuilder
    private var startWeightForCurrentPeriod: Double {
        activeGoalPeriods.first?.startWeight ?? weights.last?.weight ?? weights.first?.weight ?? 70.0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header Section
                if let current = weights.first {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            JourneyProgressCard(
                                currentKg: current.weight,
                                startKg: startWeightForCurrentPeriod,
                                targetKg: profile.targetWeight,
                                goalType: profile.goalType,
                                unitSystem: profile.unitSystem,
                                cardColor: cardBackgroundColor,
                                onEdit: { showingReconfigureGoal = true }
                            )
                            StreakCard(weights: weights, cardColor: cardBackgroundColor)
                        }
                        .padding([.horizontal, .top])
                        .padding(.bottom, 10)
                    }
                    .background(appBackgroundColor)
                }
                
                // MARK: - Weight List
                List {
                    ForEach(weights) { entry in
                        NavigationLink(destination: WeightEntryDetailView(entry: entry, profile: profile)) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(entry.date, format: .dateTime.day().month().year())
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(entry.date, format: .dateTime.hour().minute())
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("\(entry.weight.toUserWeight(system: profile.unitSystem), specifier: "%.1f") \(weightLabel)")
                                        .fontWeight(.semibold)
                                        .font(.title3)
                                        .foregroundColor(.primary)
                                }
                                // CHECK FOR PHOTOS: Added camera icon indicator
                                if let photos = entry.photos, !photos.isEmpty {
                                    Image(systemName: "camera.fill")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .padding(4)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                
                                if !entry.note.isEmpty {
                                    Text(entry.note)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .padding(.top, 2)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                // Goal Change Labels
                                let events = getGoalEvents(for: entry.date)
                                if !events.isEmpty {
                                    HStack(spacing: 6) {
                                        ForEach(events, id: \.self) { event in
                                            Text(event)
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .padding(.vertical, 3)
                                                .padding(.horizontal, 8)
                                                .background(event.contains("Started") ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                                .foregroundColor(event.contains("Started") ? .green : .red)
                                                .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(cardBackgroundColor)
                    }
                    .onDelete(perform: deleteWeight)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(appBackgroundColor)
            }
            .navigationTitle("Weight History")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingStats = true }) {
                        Image(systemName: "chart.bar")
                            .font(.body)
                    }
                    .spotlightTarget(.weightStats)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedDate = Date()
                        newWeight = ""
                        newNote = ""
                        showingAddWeight = true
                    }) {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .spotlightTarget(.addWeight)
                }
            }
            .sheet(isPresented: $showingAddWeight) {
                NavigationStack {
                    Form {
                        Section {
                            DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        }
                        Section {
                            HStack {
                                Text("Weight")
                                Spacer()
                                TextField("0.0", text: $newWeight)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.title3)
                                    .focused($isInputFocused)
                                    .frame(minWidth: 50)
                                Text(weightLabel).foregroundColor(.secondary)
                            }
                        }
                        Section {
                            TextField("Optional Note", text: $newNote)
                        }
                        Section {
                            Button("Save Entry") { saveWeight() }
                                .bold()
                                .frame(maxWidth: .infinity)
                                .disabled(newWeight.isEmpty)
                        }
                    }
                    .navigationTitle("Log Weight")
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
                .presentationDetents([.medium])
            }
            .sheet(item: $selectedEntry) { entry in
                EditWeightView(
                    entry: entry,
                    unitSystem: profile.unitSystem,
                    weightLabel: weightLabel,
                    onSave: { d, w, n in
                        dataManager.updateWeightEntry(entry, newDate: d, newWeight: w, newNote: n, goalType: profile.goalType)
                        selectedEntry = nil
                    }
                )
            }
            .sheet(isPresented: $showingStats) {
                // Pass profile to stats view
                WeightStatsView(profile: profile)
            }
            .sheet(isPresented: $showingReconfigureGoal) {
                GoalConfigurationView(
                    profile: profile,
                    appEstimatedMaintenance: nil,
                    latestWeightKg: weights.first?.weight
                )
            }
        }
    }

    // MARK: - Logic
    
    private func getGoalEvents(for date: Date) -> [String] {
        var events: [String] = []
        
        if let significantEnd = allGoalPeriods.first(where: { p in
            guard let end = p.endDate else { return false }
            return Calendar.current.isDate(end, inSameDayAs: date) &&
                   !Calendar.current.isDate(p.startDate, inSameDayAs: date)
        }) {
            events.append("\(significantEnd.goalType) Goal Ended")
        }
        
        if let latestStart = allGoalPeriods.first(where: { Calendar.current.isDate($0.startDate, inSameDayAs: date) }) {
             events.append("\(latestStart.goalType) Goal Started")
        }
        
        return events
    }

    private func saveWeight() {
        guard let userValue = Double(newWeight) else { return }
        let storedValue = userValue.toStoredWeight(system: profile.unitSystem)
        dataManager.addWeightEntry(date: selectedDate, weight: storedValue, goalType: profile.goalType, note: newNote)
        newWeight = ""
        newNote = ""
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

// MARK: - Edit View

struct EditWeightView: View {
    let entry: WeightEntry
    let unitSystem: String
    let weightLabel: String
    var onSave: (Date, Double, String) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var editDate: Date
    @State private var editWeightStr: String
    @State private var editNote: String
    
    init(entry: WeightEntry, unitSystem: String, weightLabel: String, onSave: @escaping (Date, Double, String) -> Void) {
        self.entry = entry
        self.unitSystem = unitSystem
        self.weightLabel = weightLabel
        self.onSave = onSave
        
        _editDate = State(initialValue: entry.date)
        _editNote = State(initialValue: entry.note)
        
        // Convert stored KG to user preference for display
        let userVal = entry.weight.toUserWeight(system: unitSystem)
        _editWeightStr = State(initialValue: String(format: "%.1f", userVal))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $editDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0.0", text: $editWeightStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(weightLabel).foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Note")) {
                    TextField("Optional Note", text: $editNote)
                }
                
                Section {
                    Button("Save Changes") {
                        if let val = Double(editWeightStr) {
                            // Convert back to stored KG
                            let storedVal = val.toStoredWeight(system: unitSystem)
                            onSave(editDate, storedVal, editNote)
                        }
                    }
                    .bold()
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Edit Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Feature Views

struct JourneyProgressCard: View {
    let currentKg: Double
    let startKg: Double
    let targetKg: Double
    let goalType: String
    let unitSystem: String
    let cardColor: Color
    var onEdit: () -> Void
    
    var progress: Double {
        let totalDiff = abs(targetKg - startKg)
        guard totalDiff > 0 else { return 1.0 }
        let covered = abs(currentKg - startKg)
        return min(max(covered / totalDiff, 0), 1)
    }
    
    var displayTarget: String {
        let val = targetKg.toUserWeight(system: unitSystem)
        return String(format: "%.1f", val)
    }
    
    var displayStart: String {
        let val = startKg.toUserWeight(system: unitSystem)
        return String(format: "%.1f", val)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flag.checkered")
                    .foregroundColor(.purple)
                Text("To Goal")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "gearshape.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    Capsule().fill(Color.purple)
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
            
            HStack(alignment: .bottom) {
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                Spacer()
                
                Grid(alignment: .trailing, horizontalSpacing: 4, verticalSpacing: 0) {
                    GridRow {
                        Text("Start:")
                        Text(displayStart)
                    }
                    .font(.caption2)
                    
                    GridRow {
                        Text("Goal:")
                        Text(displayTarget)
                    }
                    .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(width: 170, height: 110)
        .background(cardColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct StreakCard: View {
    let weights: [WeightEntry]
    let cardColor: Color
    
    var streak: Int {
        let sorted = weights.map { Calendar.current.startOfDay(for: $0.date) }
                            .sorted(by: >)
        let uniqueDays = Array(Set(sorted)).sorted(by: >)
        
        guard let lastDate = uniqueDays.first else { return 0 }
        
        let today = Calendar.current.startOfDay(for: Date())
        let diff = Calendar.current.dateComponents([.day], from: lastDate, to: today).day ?? 0
        if diff > 1 { return 0 }
        
        var count = 0
        var currentDate = lastDate
        
        for date in uniqueDays {
            if Calendar.current.isDate(date, inSameDayAs: currentDate) {
                count += 1
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        return count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("Streak")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(streak)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("days")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .offset(y: -4)
        }
        .padding(12)
        .frame(width: 100, height: 110, alignment: .topLeading)
        .background(cardColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
