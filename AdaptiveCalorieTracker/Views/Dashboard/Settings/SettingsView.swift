import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // Properties passed from Parent
    let estimatedMaintenance: Int?
    let currentWeight: Double?
    
    // Internal State
    @State private var showingReconfigureGoal = false
    
    // App Storage (Copied from DashboardView)
    @AppStorage("dailyCalorieGoal") private var dailyGoal: Int = 2000
    @AppStorage("targetWeight") private var targetWeight: Double = 70.0
    @AppStorage("goalType") private var goalType: String = "Cutting"
    @AppStorage("maintenanceCalories") private var maintenanceCalories: Int = 2500
    @AppStorage("estimationMethod") private var estimationMethod: Int = 0
    @AppStorage("enableCaloriesBurned") private var enableCaloriesBurned: Bool = true
    @AppStorage("maintenanceTolerance") private var maintenanceTolerance: Double = 2.0
    @AppStorage("unitSystem") private var unitSystem: String = UnitSystem.metric.rawValue
    @AppStorage("userGender") private var userGender: Gender = .male
    @AppStorage("isCalorieCountingEnabled") private var isCalorieCountingEnabled: Bool = true
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true
    
    var weightLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Picker("Unit System", selection: $unitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Text(system.rawValue).tag(system.rawValue)
                        }
                    }
                    Toggle("Dark Mode", isOn: $isDarkMode)
                    Toggle("Enable Calorie Counting", isOn: $isCalorieCountingEnabled)
                    
                    if isCalorieCountingEnabled {
                        Toggle("Track Calories Burned", isOn: $enableCaloriesBurned)
                    }
                }
                
                Section("Profile") {
                    Picker("Gender", selection: $userGender) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }
                }
                
                if isCalorieCountingEnabled {
                    Section("Current Goal") {
                        HStack {
                            Text("Goal Type")
                            Spacer()
                            Text(goalType).foregroundColor(.secondary)
                        }
                        HStack {
                            Text(goalType == GoalType.maintenance.rawValue ? "Maintenance Weight" : "Target Weight")
                            Spacer()
                            Text("\(targetWeight.toUserWeight(system: unitSystem), specifier: "%.1f") \(weightLabel)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Daily Calorie Goal")
                            Spacer()
                            Text("\(dailyGoal) kcal").foregroundColor(.secondary)
                        }
                        Button("Reconfigure Goal") {
                            // Delay slightly to allow the sheet animation to process if needed, 
                            // or just toggle immediately. 
                            showingReconfigureGoal = true
                        }
                        .foregroundColor(.blue)
                        .bold()
                    }
                    
                    Section("Prediction Logic") {
                        if isCalorieCountingEnabled {
                            Picker("Method", selection: $estimationMethod) {
                                ForEach(EstimationMethod.allCases) { method in
                                    Text(method.displayName).tag(method.rawValue)
                                }
                            }
                        } else {
                            Text(EstimationMethod.weightTrend30Day.displayName)
                            Text("Calorie counting is disabled.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    
                    if goalType == GoalType.maintenance.rawValue {
                        Section("Maintenance Settings") {
                            let toleranceBinding = Binding<Double>(
                                get: { maintenanceTolerance.toUserWeight(system: unitSystem) },
                                set: { maintenanceTolerance = $0.toStoredWeight(system: unitSystem) }
                            )
                            HStack {
                                Text("Tolerance (+/- \(weightLabel))")
                                Spacer()
                                TextField("0.0", value: toleranceBinding, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }
                
                Section("Community & Support") {
                    NavigationLink(destination: HelpSupportView()) {
                        Label("Help and Support", systemImage: "questionmark.circle")
                    }
                    
                    if let url = URL(string: "https://www.instagram.com/repscale.app/") {
                        Link(destination: url) {
                            Label("Follow @RepScale.app", systemImage: "camera.fill")
                        }
                    }
                    
                    if let url = URL(string: "https://apps.apple.com/app/id1234567890?action=write-review") {
                        Link(destination: url) {
                            Label("Review on AppStore", systemImage: "star.fill")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") { dismiss() }
            }
            .sheet(isPresented: $showingReconfigureGoal) {
                GoalConfigurationView(
                    appEstimatedMaintenance: estimatedMaintenance,
                    latestWeightKg: currentWeight
                )
            }
        }
    }
}
