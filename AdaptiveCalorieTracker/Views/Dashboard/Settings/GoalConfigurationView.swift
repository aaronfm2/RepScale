import SwiftUI
import SwiftData

struct GoalConfigurationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool
    
    // Properties passed in
    let appEstimatedMaintenance: Int?
    let latestWeightKg: Double?
    
    @AppStorage("userGender") private var userGender: Gender = .male
    @AppStorage("unitSystem") private var unitSystem: String = UnitSystem.metric.rawValue
    
    // --- NEW APP STORAGE ---
    @AppStorage("maintenanceTolerance") private var maintenanceTolerance: Double = 2.0
    @AppStorage("goalType") private var storedGoalType: String = GoalType.cutting.rawValue
    
    @State private var targetWeight: Double? = nil
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
    
    @State private var maintenanceSource: Int = 0
    @State private var manualMaintenanceInput: String = ""
    @State private var maintenanceDisplay: Int = 0

    @State private var dailyGoal: Int = 0
    @State private var calculatedDeficit: Int = 0
    
    // --- CHANGED: Explicit Selection State ---
    @State private var selectedGoalType: GoalType = .maintenance
    
    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }
    
    var unitLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    
    // --- NEW: Validation Logic ---
    var validationError: String? {
        guard let t = targetWeight, let c = latestWeightKg else { return nil }
        let tKgVal = t.toStoredWeight(system: unitSystem)
        
        if selectedGoalType == .cutting && tKgVal >= c { return "Target must be less than current." }
        if selectedGoalType == .bulking && tKgVal <= c { return "Target must be greater than current." }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // --- NEW SECTION: Goal Type ---
                Section(header: Text("Goal Configuration")) {
                    Picker("Goal Type", selection: $selectedGoalType) {
                        ForEach(GoalType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedGoalType) { _, _ in recalculate() }
                    
                    HStack {
                        Text("Current Weight")
                        Spacer()
                        if let w = latestWeightKg {
                            Text("\(w.toUserWeight(system: unitSystem), specifier: "%.1f") \(unitLabel)")
                                .foregroundColor(.secondary)
                        } else {
                            Text("No Data").foregroundColor(.red)
                        }
                    }

                    // --- Conditional Input ---
                    if selectedGoalType != .maintenance {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Target Weight (\(unitLabel))")
                                Spacer()
                                TextField("Required", value: $targetWeight, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .focused($isInputFocused)
                                    .onChange(of: targetWeight) { _, _ in recalculate() }
                            }
                            if let error = validationError {
                                Text(error).font(.caption).foregroundColor(.red)
                            }
                        }
                        
                        DatePicker("Target Date", selection: $targetDate, in: Date()..., displayedComponents: .date)
                            .onChange(of: targetDate) { _, _ in recalculate() }
                    }
                }
                
                // --- Maintenance Tolerance Section ---
                if selectedGoalType == .maintenance {
                    Section(header: Text("Maintenance Range"), footer: Text("Weight fluctuations within this range (+/-) are considered normal maintenance.")) {
                        HStack {
                            Text("Tolerance (+/-)")
                            Spacer()
                            TextField("2.0", value: Binding(
                                get: { maintenanceTolerance.toUserWeight(system: unitSystem) },
                                set: { maintenanceTolerance = $0.toStoredWeight(system: unitSystem) }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputFocused)
                            .frame(width: 80)
                            Text(unitLabel).foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Maintenance Calorie Source")) {
                    Picker("Source", selection: $maintenanceSource) {
                        Text("Formula").tag(0)
                        if appEstimatedMaintenance != nil {
                            Text("App Estimate").tag(1)
                        }
                        Text("Manual").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: maintenanceSource) { _, _ in recalculate() }
                    
                    if maintenanceSource == 2 {
                        HStack {
                            Text("Manual Maintenance")
                            Spacer()
                            TextField("kcal", text: $manualMaintenanceInput)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .focused($isInputFocused)
                                .onChange(of: manualMaintenanceInput) { _, _ in recalculate() }
                        }
                    } else {
                        HStack {
                            Text("Base Maintenance")
                            Spacer()
                            Text("\(maintenanceDisplay) kcal").bold()
                        }
                    }
                }
                
                Section(header: Text("Results")) {
                    HStack {
                        Text("Daily Goal")
                        Spacer()
                        Text("\(dailyGoal) kcal").bold().foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Daily Adjustment")
                        Spacer()
                        Text(calculatedDeficit < 0 ? "\(calculatedDeficit) deficit" : "+\(calculatedDeficit) surplus")
                            .font(.caption)
                            .foregroundColor(calculatedDeficit < 0 ? .green : .orange)
                    }
                }
                
                Section {
                    Button("Save Configuration") {
                        save()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    // Disable if validation fails, goal is invalid, or maintenance source incomplete
                    .disabled(
                        (selectedGoalType != .maintenance && (targetWeight == nil || validationError != nil)) ||
                        latestWeightKg == nil ||
                        (maintenanceSource == 2 && manualMaintenanceInput.isEmpty)
                    )
                }
            }
            .navigationTitle("Reconfigure Goal")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // Initialize state from AppStorage or defaults
                if let saved = GoalType(rawValue: storedGoalType) {
                    selectedGoalType = saved
                }
                
                if appEstimatedMaintenance != nil {
                    maintenanceSource = 1
                }
                recalculate()
            }
        }
    }
    
    private func recalculate() {
        guard let currentKg = latestWeightKg else { return }
        
        switch maintenanceSource {
        case 0:
            let multiplier: Double = (userGender == .male) ? 32.0 : 29.0
            maintenanceDisplay = Int(currentKg * multiplier)
        case 1:
            maintenanceDisplay = appEstimatedMaintenance ?? 2500
        case 2:
            maintenanceDisplay = Int(manualMaintenanceInput) ?? 0
        default:
            break
        }
        
        // If maintenance, deficit is 0 and goal equals maintenance
        if selectedGoalType == .maintenance {
            dailyGoal = maintenanceDisplay
            calculatedDeficit = 0
            return
        }
        
        // For cutting/bulking, ensure we have a target
        guard let tWeightUser = targetWeight else {
            dailyGoal = maintenanceDisplay
            calculatedDeficit = 0
            return
        }
        
        let tWeightKg = tWeightUser.toStoredWeight(system: unitSystem)
        
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: targetDate)
        let days = Calendar.current.dateComponents([.day], from: today, to: target).day ?? 1
        
        if days <= 0 {
            dailyGoal = maintenanceDisplay
            calculatedDeficit = 0
            return
        }
        
        let weightDiff = tWeightKg - currentKg
        let totalCaloriesNeeded = weightDiff * 7700.0
        let dailyAdjustment = Int(totalCaloriesNeeded / Double(days))
        
        calculatedDeficit = dailyAdjustment
        dailyGoal = maintenanceDisplay + dailyAdjustment
    }
    
    private func save() {
        let tWeightStored: Double
        
        if selectedGoalType == .maintenance {
            // If maintenance, set target to current weight
            tWeightStored = latestWeightKg ?? 0.0
        } else {
            guard let t = targetWeight else { return }
            tWeightStored = t.toStoredWeight(system: unitSystem)
        }
        
        UserDefaults.standard.set(tWeightStored, forKey: "targetWeight")
        UserDefaults.standard.set(dailyGoal, forKey: "dailyCalorieGoal")
        UserDefaults.standard.set(selectedGoalType.rawValue, forKey: "goalType")
        UserDefaults.standard.set(maintenanceDisplay, forKey: "maintenanceCalories")
        
        let startW = latestWeightKg ?? 0.0
        
        dataManager.startNewGoalPeriod(
            goalType: selectedGoalType.rawValue,
            startWeight: startW,
            targetWeight: tWeightStored,
            dailyCalorieGoal: dailyGoal,
            maintenanceCalories: maintenanceDisplay
        )
        
        dismiss()
    }
}
