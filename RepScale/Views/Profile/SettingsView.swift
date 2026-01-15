import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var profile: UserProfile
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var healthManager: HealthManager
    
    @AppStorage("hasSeenAppTutorial") private var hasSeenAppTutorial: Bool = true
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted: Bool = true
    
    let estimatedMaintenance: Int?
    let currentWeight: Double?
    
    @State private var showingReconfigureGoal = false
    @State private var showingRestartAlert = false
    
    // Local state for Height UI to prevent drift
    @State private var selectedHeightUnit: UnitSystem = .metric
    
    // MARK: - FIX: Focus State
    @FocusState private var isInputFocused: Bool
    
    // MARK: - FIX: Keyboard State
    @State private var isKeyboardVisible = false
    
    var weightLabel: String { profile.unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    
    var goalColor: Color {
        switch GoalType(rawValue: profile.goalType) {
        case .cutting: return .green
        case .bulking: return .red
        case .maintenance: return .blue
        default: return .primary
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // MARK: - Section 1: General Preferences
                    Section {
                        Picker(selection: $profile.unitSystem) {
                            ForEach(UnitSystem.allCases, id: \.self) { system in
                                Text(system.rawValue).tag(system.rawValue)
                            }
                        } label: { Label("Unit System", systemImage: "ruler").foregroundColor(.primary) }
                        
                        Toggle(isOn: $profile.isDarkMode) {
                            Label("Dark Mode", systemImage: "moon").foregroundColor(.primary)
                        }.tint(.blue)
                    } header: {
                        Text("General")
                    }
                    
                    // MARK: - Section 2: Personal Details
                    Section {
                        Picker(selection: $profile.gender) {
                            ForEach(Gender.allCases, id: \.self) { gender in
                                Text(gender.rawValue).tag(gender.rawValue)
                            }
                        } label: { Label("Gender", systemImage: "person").foregroundColor(.primary) }
                        .onChange(of: profile.gender) { _, _ in recalculateMaintenance() }
                        
                        // Date of Birth
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Label("Date of Birth", systemImage: "calendar").foregroundColor(.primary)
                                Spacer()
                                Text("Age: \(profile.age)").foregroundColor(.secondary)
                            }
                            DatePicker("", selection: $profile.dateOfBirth, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .onChange(of: profile.dateOfBirth) { _, _ in recalculateMaintenance() }
                        }
                        .padding(.vertical, 4)
                        
                        // Height
                        VStack(alignment: .leading) {
                            HStack {
                                Label("Height", systemImage: "arrow.up.and.down").foregroundColor(.primary)
                                Spacer()
                                Picker("", selection: $selectedHeightUnit) {
                                    Text("cm").tag(UnitSystem.metric)
                                    Text("ft/in").tag(UnitSystem.imperial)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 100)
                                .onChange(of: selectedHeightUnit) { _, newVal in
                                    // Save preference
                                    profile.heightUnitPreference = newVal.rawValue
                                }
                            }
                            
                            HStack {
                                Spacer()
                                if selectedHeightUnit == .metric {
                                    TextField("cm", value: $profile.height, format: .number)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                        .focused($isInputFocused)
                                    Text("cm").foregroundColor(.secondary)
                                } else {
                                    // Smart bindings to prevent drift
                                    let ftBinding = Binding<Int?>(
                                        get: {
                                            let totalInches = profile.height / 2.54
                                            return Int(totalInches / 12)
                                        },
                                        set: { newFt in
                                            let currentTotalInches = profile.height / 2.54
                                            let currentIn = Int(currentTotalInches.truncatingRemainder(dividingBy: 12))
                                            let inches = Double((newFt ?? 0) * 12 + currentIn)
                                            profile.height = inches * 2.54
                                        }
                                    )
                                    let inBinding = Binding<Int?>(
                                        get: {
                                            let totalInches = profile.height / 2.54
                                            return Int(totalInches.truncatingRemainder(dividingBy: 12))
                                        },
                                        set: { newIn in
                                            let currentTotalInches = profile.height / 2.54
                                            let currentFt = Int(currentTotalInches / 12)
                                            let inches = Double(currentFt * 12 + (newIn ?? 0))
                                            profile.height = inches * 2.54
                                        }
                                    )
                                    
                                    TextField("ft", value: ftBinding, format: .number)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 50)
                                        .focused($isInputFocused)
                                    Text("ft").foregroundColor(.secondary)
                                    
                                    TextField("in", value: inBinding, format: .number)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 50)
                                        .focused($isInputFocused)
                                    Text("in").foregroundColor(.secondary)
                                }
                            }
                        }
                        .onChange(of: profile.height) { _, _ in recalculateMaintenance() }
                        
                        Picker(selection: $profile.activityLevel) {
                            ForEach(ActivityLevel.allCases, id: \.self) { level in
                                Text(level.rawValue).tag(level.rawValue)
                            }
                        } label: { Label("Activity Level", systemImage: "figure.walk").foregroundColor(.primary) }
                        .onChange(of: profile.activityLevel) { _, _ in recalculateMaintenance() }
                        
                    } header: {
                        Text("About You")
                    }
                    
                    // MARK: - Section 3: Tracking Configuration
                    Section {
                        Toggle(isOn: $profile.isCalorieCountingEnabled) {
                            Label("Enable Calorie Counting", systemImage: "flame").foregroundColor(.primary)
                        }.tint(.blue)
                        
                        if profile.isCalorieCountingEnabled {
                            Toggle(isOn: $profile.enableCaloriesBurned) {
                                Label("Track Calories Burned", systemImage: "figure.run").foregroundColor(.primary)
                            }.tint(.blue)
                        }
                        
                        Toggle(isOn: $profile.enableHealthKitSync) {
                            Label("HealthKit Sync", systemImage: "heart.text.square").foregroundColor(.primary)
                        }.tint(.blue)
                    } header: {
                        Text("Tracking")
                    } footer: {
                        if profile.isCalorieCountingEnabled {
                            Text("Enable Apple Health to automatically import nutrition data from apps like MyFitnessPal, Cronometer, or Lose It!.")
                        }
                    }
                    
                    // MARK: - Section 4: Goal Dashboard
                    if profile.isCalorieCountingEnabled {
                        Section {
                            LabeledContent {
                                Text(profile.goalType).fontWeight(.semibold).foregroundColor(goalColor)
                            } label: { Label("Goal Type", systemImage: "target").foregroundColor(.primary) }
                            
                            LabeledContent("Daily Target") { Text("\(profile.dailyCalorieGoal) kcal").monospacedDigit() }
                            
                            LabeledContent("Target Weight") {
                                Text("\(profile.targetWeight.toUserWeight(system: profile.unitSystem), specifier: "%.1f") \(weightLabel)")
                            }
                            
                            Button { showingReconfigureGoal = true } label: {
                                Label("Reconfigure Goal", systemImage: "slider.horizontal.3").foregroundColor(.primary)
                            }
                        } header: { Text("Strategy") }
                        
                        Section {
                            Picker(selection: $profile.estimationMethod) {
                                ForEach(EstimationMethod.allCases) { method in
                                    Text(method.displayName).tag(method.rawValue)
                                }
                            } label: { Label("Prediction Logic", systemImage: "chart.xyaxis.line").foregroundColor(.primary) }
                            
                            if profile.goalType == GoalType.maintenance.rawValue {
                                let toleranceBinding = Binding<Double>(
                                    get: { profile.maintenanceTolerance.toUserWeight(system: profile.unitSystem) },
                                    set: { profile.maintenanceTolerance = $0.toStoredWeight(system: profile.unitSystem) }
                                )
                                HStack {
                                    Label("Weight Tolerance", systemImage: "arrow.left.and.right").foregroundColor(.primary)
                                    Spacer()
                                    TextField("0.0", value: toleranceBinding, format: .number)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 60)
                                        .focused($isInputFocused)
                                    Text(weightLabel).foregroundColor(.secondary)
                                }
                            }
                        } header: { Text("Calculations") }
                    }
                    
                    // MARK: - FIX: Spacer to enable Swipe-to-Dismiss and keyboard visiblity
                    Section {
                        Color.clear.frame(height: 80)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // MARK: - Custom Keyboard Toolbar
                VStack {
                    Spacer()
                    if isKeyboardVisible {
                        VStack(spacing: 0) {
                            Divider()
                            HStack {
                                Spacer()
                                Button("Done") {
                                    hideKeyboard()
                                }
                                .bold()
                                .tint(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .background(.bar)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("Settings")
            // 1. Navigation Bar items
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingReconfigureGoal) {
                GoalConfigurationView(profile: profile, appEstimatedMaintenance: estimatedMaintenance, latestWeightKg: currentWeight)
            }
            .presentationDetents([.large])
            // MARK: - Keyboard Observers
            .onAppear {
                // Initialize local height unit from profile preference
                if let pref = UnitSystem(rawValue: profile.heightUnitPreference) {
                    selectedHeightUnit = pref
                } else {
                    selectedHeightUnit = UnitSystem(rawValue: profile.unitSystem) ?? .metric
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isKeyboardVisible = true
                    }
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isKeyboardVisible = false
                    }
                }
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Auto-Recalculate Maintenance Logic
    private func recalculateMaintenance() {
        guard let currentKg = currentWeight else { return }
        
        let age = Double(profile.age)
        let height = profile.height // stored in cm
        let activity = ActivityLevel(rawValue: profile.activityLevel) ?? .Active
        let isMale = (profile.gender == Gender.male.rawValue)
        
        // Mifflin-St Jeor Calculation
        let base: Double = (10 * currentKg) + (6.25 * height) - (5 * age)
        let genderOffset: Double = isMale ? 5 : -161
        let bmr = base + genderOffset
        
        let newMaintenance = Int(bmr * activity.multiplier)
        
        withAnimation {
            profile.maintenanceCalories = newMaintenance
            
            // If user's goal is maintenance, sync the daily target too
            if profile.goalType == GoalType.maintenance.rawValue {
                profile.dailyCalorieGoal = newMaintenance
            }
        }
    }
}
