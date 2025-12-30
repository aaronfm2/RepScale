import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // Properties passed from Parent
    let estimatedMaintenance: Int?
    let currentWeight: Double?
    
    // Internal State
    @State private var showingReconfigureGoal = false
    
    // App Storage
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
    
    // Helper for Goal Color (Used ONLY for status text)
    var goalColor: Color {
        switch GoalType(rawValue: goalType) {
        case .cutting: return .green
        case .bulking: return .red
        case .maintenance: return .blue
        default: return .primary
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Section 1: General Preferences
                Section {
                    Picker(selection: $unitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Text(system.rawValue).tag(system.rawValue)
                        }
                    } label: {
                        Label("Unit System", systemImage: "ruler")
                            .foregroundColor(.primary)
                    }
                    
                    Toggle(isOn: $isDarkMode) {
                        Label("Dark Mode", systemImage: "moon")
                            .foregroundColor(.primary)
                    }
                    
                    Picker(selection: $userGender) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    } label: {
                        Label("Gender", systemImage: "person")
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("General")
                }
                
                // MARK: - Section 2: Tracking Configuration
                Section {
                    Toggle(isOn: $isCalorieCountingEnabled) {
                        Label("Enable Calorie Counting", systemImage: "flame")
                            .foregroundColor(.primary)
                    }
                    
                    if isCalorieCountingEnabled {
                        Toggle(isOn: $enableCaloriesBurned) {
                            Label("Track Calories Burned", systemImage: "figure.run")
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Text("Tracking")
                } footer: {
                    if isCalorieCountingEnabled {
                        Text("When enabled, active energy from Apple Health is deducted from your net calorie total.")
                    }
                }
                
                // MARK: - Section 3: Goal Dashboard
                if isCalorieCountingEnabled {
                    Section {
                        // Strategy Summary
                        LabeledContent {
                            // Keep color here as it indicates status (Green/Red/Blue)
                            Text(goalType)
                                .fontWeight(.semibold)
                                .foregroundColor(goalColor)
                        } label: {
                            Label("Goal Type", systemImage: "target")
                                .foregroundColor(.primary)
                        }
                        
                        LabeledContent("Daily Target") {
                            Text("\(dailyGoal) kcal")
                                .monospacedDigit()
                        }
                        
                        LabeledContent("Target Weight") {
                            Text("\(targetWeight.toUserWeight(system: unitSystem), specifier: "%.1f") \(weightLabel)")
                        }
                        
                        // Action Button (Neutral)
                        Button {
                            showingReconfigureGoal = true
                        } label: {
                            Label("Reconfigure Goal", systemImage: "slider.horizontal.3")
                                .foregroundColor(.primary)
                        }
                    } header: {
                        Text("Strategy")
                    }
                    
                    // Technical Settings
                    Section {
                        Picker(selection: $estimationMethod) {
                            ForEach(EstimationMethod.allCases) { method in
                                Text(method.displayName).tag(method.rawValue)
                            }
                        } label: {
                            Label("Prediction Logic", systemImage: "chart.xyaxis.line")
                                .foregroundColor(.primary)
                        }
                        
                        // Maintenance Tolerance
                        if goalType == GoalType.maintenance.rawValue {
                            let toleranceBinding = Binding<Double>(
                                get: { maintenanceTolerance.toUserWeight(system: unitSystem) },
                                set: { maintenanceTolerance = $0.toStoredWeight(system: unitSystem) }
                            )
                            HStack {
                                Label("Weight Tolerance", systemImage: "arrow.left.and.right")
                                    .foregroundColor(.primary)
                                Spacer()
                                TextField("0.0", value: toleranceBinding, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                Text(weightLabel)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Calculations")
                    } footer: {
                        Text("Determines how the dashboard estimates your future progress.")
                    }
                }
                
                // MARK: - Section 4: Community
                Section {
                    NavigationLink(destination: HelpSupportView()) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                            .foregroundColor(.primary)
                    }
                    
                    if let url = URL(string: "https://www.instagram.com/repscale.app/") {
                        Link(destination: url) {
                            Label("Follow @RepScale.app", systemImage: "camera")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if let url = URL(string: "https://apps.apple.com/app/id1234567890?action=write-review") {
                        Link(destination: url) {
                            Label("Review on AppStore", systemImage: "star")
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Text("Community")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
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
