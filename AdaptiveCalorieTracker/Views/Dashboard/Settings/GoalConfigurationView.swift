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
    
    @State private var targetWeight: Double? = nil
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
    
    @State private var maintenanceSource: Int = 0
    @State private var manualMaintenanceInput: String = ""
    @State private var maintenanceDisplay: Int = 0

    @State private var dailyGoal: Int = 0
    @State private var calculatedDeficit: Int = 0
    @State private var derivedGoalType: GoalType = .maintenance
    
    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }
    
    var unitLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Goal Details")) {
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
                    
                    HStack {
                        Text("Target Weight (\(unitLabel))")
                        Spacer()
                        TextField("Required", value: $targetWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputFocused)
                            .onChange(of: targetWeight) { _, _ in recalculate() }
                    }
                    
                    DatePicker("Target Date", selection: $targetDate, in: Date()..., displayedComponents: .date)
                        .onChange(of: targetDate) { _, _ in recalculate() }
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
                        Text("Goal Type")
                        Spacer()
                        Text(derivedGoalType.rawValue)
                            .bold()
                            .foregroundColor(derivedGoalType == .cutting ? .green : (derivedGoalType == .bulking ? .red : .blue))
                    }
                    
                    HStack {
                        Text("Daily Calorie Goal")
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
                    .disabled(targetWeight == nil || latestWeightKg == nil || (maintenanceSource == 2 && manualMaintenanceInput.isEmpty))
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
        
        guard let tWeightUser = targetWeight else { return }
        let tWeightKg = tWeightUser.toStoredWeight(system: unitSystem)
        
        if tWeightKg > currentKg {
            derivedGoalType = .bulking
        } else if tWeightKg < currentKg {
            derivedGoalType = .cutting
        } else {
            derivedGoalType = .maintenance
        }
        
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
        guard let tWeightUser = targetWeight else { return }
        
        let tWeightStored = tWeightUser.toStoredWeight(system: unitSystem)
        UserDefaults.standard.set(tWeightStored, forKey: "targetWeight")
        UserDefaults.standard.set(dailyGoal, forKey: "dailyCalorieGoal")
        UserDefaults.standard.set(derivedGoalType.rawValue, forKey: "goalType")
        UserDefaults.standard.set(maintenanceDisplay, forKey: "maintenanceCalories")
        
        let startW = latestWeightKg ?? 0.0
        
        dataManager.startNewGoalPeriod(
            goalType: derivedGoalType.rawValue,
            startWeight: startW,
            targetWeight: tWeightStored,
            dailyCalorieGoal: dailyGoal,
            maintenanceCalories: maintenanceDisplay
        )
        
        dismiss()
    }
}
