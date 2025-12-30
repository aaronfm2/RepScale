import SwiftUI
import SwiftData

struct WeightTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    
    // Fetch the active goal period to get the true "Start Weight" for the current goal
    @Query(filter: #Predicate<GoalPeriod> { $0.endDate == nil }) private var activeGoalPeriods: [GoalPeriod]
    
    // Fetch ALL goal periods to display history labels
    @Query(sort: \GoalPeriod.startDate, order: .reverse) private var allGoalPeriods: [GoalPeriod]
    
    @AppStorage("goalType") private var currentGoalType: String = GoalType.cutting.rawValue
    @AppStorage("unitSystem") private var unitSystem: String = UnitSystem.metric.rawValue
    @AppStorage("targetWeight") private var targetWeight: Double = 70.0 // Stored in KG
    
    // MARK: - Dark Mode & Colors
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true

    var appBackgroundColor: Color {
        isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var cardBackgroundColor: Color {
        isDarkMode ? Color(red: 0.153, green: 0.153, blue: 0.165) : Color.white
    }
    
    @State private var showingAddWeight = false
    @State private var showingStats = false
    @State private var showingReconfigureGoal = false
    @State private var newWeight: String = ""
    @State private var selectedDate: Date = Date()
    @FocusState private var isInputFocused: Bool

    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }
    
    var weightLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header Section
                if let current = weights.first {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            
                            // 1. Journey Progress Card
                            JourneyProgressCard(
                                currentKg: current.weight,
                                startKg: activeGoalPeriods.first?.startWeight ?? weights.last?.weight ?? current.weight,
                                targetKg: targetWeight,
                                goalType: currentGoalType,
                                unitSystem: unitSystem,
                                cardColor: cardBackgroundColor,
                                onEdit: { showingReconfigureGoal = true }
                            )
                            
                            // 2. Streak Card
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
                        VStack(alignment: .leading, spacing: 6) {
                            // 1. Date and Weight Row
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(entry.date, format: .dateTime.day().month().year())
                                        .font(.body)
                                    Text(entry.date, format: .dateTime.hour().minute())
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(entry.weight.toUserWeight(system: unitSystem), specifier: "%.1f") \(weightLabel)")
                                    .fontWeight(.semibold)
                                    .font(.title3)
                            }
                            
                            // 2. Goal Change Labels
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
                        .padding(.vertical, 2)
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
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedDate = Date()
                        newWeight = ""
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
            .sheet(isPresented: $showingStats) {
                WeightStatsView()
            }
            // --- Reconfigure Goal Sheet ---
            .sheet(isPresented: $showingReconfigureGoal) {
                // Reusing GoalConfigurationView from DashboardView.swift
                // appEstimatedMaintenance is nil here as we don't have the dashboard VM,
                // but the view handles nil by defaulting to formula/manual.
                GoalConfigurationView(
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
            events.append("\(significantEnd.goalType) Ended")
        }
        
        if let latestStart = allGoalPeriods.first(where: { Calendar.current.isDate($0.startDate, inSameDayAs: date) }) {
             events.append("\(latestStart.goalType) Started")
        }
        
        return events
    }

    private func saveWeight() {
        guard let userValue = Double(newWeight) else { return }
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
                
                // --- NEW: Settings Cog ---
                Button(action: onEdit) {
                    Image(systemName: "gearshape.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Progress Bar
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
        
        // Check if streak is alive (last entry must be today or yesterday)
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
