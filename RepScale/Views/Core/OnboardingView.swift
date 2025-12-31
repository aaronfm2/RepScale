import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Navigation State
    @State private var currentStep = 0
    
    // MARK: - Local Data Collection (Transferred to UserProfile on completion)
    @State private var unitSystem: UnitSystem = .metric
    @State private var isDarkMode: Bool = true
    @State private var gender: Gender = .male
    
    @State private var currentWeight: Double? = nil
    @State private var targetWeight: Double? = nil
    @State private var goalType: GoalType = .cutting
    
    // Strategy & Calorie Settings
    @State private var isCalorieCountingEnabled: Bool = true
    @State private var trackCaloriesBurned: Bool = false
    @State private var maintenanceTolerance: Double = 2.0 // Stored in Kg
    
    // Calculation State
    @State private var knowsDetails: Bool = false
    @State private var maintenanceInput: String = ""
    @State private var dailyGoalInput: String = ""
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
    
    // MARK: - Helpers
    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }

    var unitLabel: String {
        return unitSystem == .imperial ? "lbs" : "kg"
    }
    
    var appBackgroundColor: Color {
        isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    func toKg(_ value: Double) -> Double {
        return unitSystem == .imperial ? value / 2.20462 : value
    }
    
    // Helper to convert stored Kg to display unit
    func toDisplay(_ kgValue: Double) -> Double {
        return unitSystem == .imperial ? kgValue * 2.20462 : kgValue
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            appBackgroundColor.ignoresSafeArea()
            
            VStack {
                ProgressView(value: Double(currentStep), total: 4)
                    .padding()
                
                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    biometricsStep.tag(1)
                    goalsStep.tag(2)
                    strategyStep.tag(3)
                    finalStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            hideKeyboard()
                            currentStep -= 1
                        }
                        .foregroundColor(.secondary)
                    }
                    Spacer()
                    if currentStep < 4 {
                        Button("Next") {
                            hideKeyboard()
                            withAnimation {
                                if currentStep == 1 { estimateMaintenance() }
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(cannotMoveForward)
                    } else {
                        Button("Get Started") {
                            hideKeyboard()
                            completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    // MARK: - Validation
    var cannotMoveForward: Bool {
        if currentStep == 1 { return currentWeight == nil }
        if currentStep == 2 {
            if goalType == .maintenance { return false }
            guard let t = targetWeight, let c = currentWeight else { return true }
            if goalType == .cutting && t >= c { return true }
            if goalType == .bulking && t <= c { return true }
            return false
        }
        return false
    }
    
    // MARK: - Steps
    
    var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            Text("Welcome to RepScale")
                .font(.largeTitle).bold()
            Text("Let's set up your profile to personalize your calorie and workout tracking.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
        }
    }
    
    var biometricsStep: some View {
        Form {
            Section(header: Text("Preferences")) {
                Picker("Units", selection: $unitSystem) {
                    ForEach(UnitSystem.allCases, id: \.self) { system in
                        Text(system.rawValue).tag(system)
                    }
                }
                .pickerStyle(.segmented)
                
            }
            Section(header: Text("Biometrics")) {
                Picker("Gender", selection: $gender) {
                    ForEach(Gender.allCases, id: \.self) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Current Weight (\(unitLabel))")
                    Spacer()
                    TextField("Required", value: $currentWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            Section(footer: Text("We use this to estimate your baseline metabolic rate.")) { }
        }
        .scrollContentBackground(.hidden)
        .background(appBackgroundColor)
    }
    
    var goalsStep: some View {
        Form {
            Section(header: Text("Select Goal")) {
                Picker("Goal Type", selection: $goalType) {
                    ForEach(GoalType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            if goalType == .maintenance {
                Section(header: Text("Maintenance Settings"), footer: Text("Weight fluctuations within this range (+/-) are considered normal maintenance.")) {
                    HStack {
                        Text("Tolerance (+/- \(unitLabel))")
                        Spacer()
                        // Binding to convert display value to/from stored kg value
                        TextField("2.0", value: Binding(
                            get: { toDisplay(maintenanceTolerance) },
                            set: { maintenanceTolerance = toKg($0) }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    }
                }
            } else {
                Section(header: Text("Target"), footer: validationFooter) {
                    HStack {
                        Text("Target Weight (\(unitLabel))")
                        Spacer()
                        TextField("Required", value: $targetWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(appBackgroundColor)
    }
    
    @ViewBuilder
    var validationFooter: some View {
        if let t = targetWeight, let c = currentWeight {
            if goalType == .cutting && t >= c {
                Text("Target weight must be lower than current weight for cutting.").foregroundColor(.red)
            } else if goalType == .bulking && t <= c {
                Text("Target weight must be higher than current weight for bulking.").foregroundColor(.red)
            } else {
                Text("Enter your desired target weight.")
            }
        } else {
            Text("Enter your desired target weight.")
        }
    }

    var strategyStep: some View {
        Form {
            Section(header: Text("Preferences")) {
                Toggle("Enable Calorie Counting", isOn: $isCalorieCountingEnabled)
                
                if isCalorieCountingEnabled {
                    Toggle("Track Calories Burned?", isOn: $trackCaloriesBurned)
                }
            }
            
            if isCalorieCountingEnabled {
                Section(header: Text("Strategy")) {
                    Toggle("I already know my calorie targets", isOn: $knowsDetails)
                }
                
                if knowsDetails {
                    Section(header: Text("Enter Details")) {
                        HStack {
                            Text("Maintenance Calories")
                            Spacer()
                            TextField("kcal", text: $maintenanceInput)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Daily Calorie Target")
                            Spacer()
                            TextField("kcal", text: $dailyGoalInput)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } else {
                    Section(header: Text("Timeframe")) {
                        DatePicker("Achieve Goal By", selection: $targetDate, in: Date()..., displayedComponents: .date)
                            .onChange(of: targetDate) { _, _ in calculateGoalFromDate() }
                            .onChange(of: maintenanceInput) { _, _ in calculateGoalFromDate() }
                    }
                    
                    Section(header: Text("Calculations")) {
                        HStack {
                            Text("Est. Maintenance")
                            Text("Est. using your Gender & Weight.")
                                .font(.caption).foregroundColor(.secondary)
                            Spacer()
                            TextField("kcal", text: $maintenanceInput)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Recommended Daily Goal")
                            Spacer()
                            Text("\(dailyGoalInput) kcal")
                                .bold()
                                .foregroundColor(.blue)
                        }
                        
                        if let goal = Int(dailyGoalInput), let maint = Int(maintenanceInput) {
                            let diff = goal - maint
                            Text(diff < 0 ? "\(diff) deficit / day" : "+\(diff) surplus / day")
                                .font(.caption)
                                .foregroundColor(diff < 0 ? .green : .orange)
                        }
                    }
                    .onAppear {
                        calculateGoalFromDate()
                    }
                }
            } else {
                Section {
                    Text("With calorie counting disabled, the app will focus on tracking your weight trends and workouts.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(appBackgroundColor)
    }
    
    var finalStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("You're All Set!")
                .font(.title).bold()
            
            Text("We've saved your starting weight and configured your profile.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
            
            if isCalorieCountingEnabled {
                VStack(spacing: 10) {
                    Text("Daily Goal: \(dailyGoalInput) kcal").bold()
                    Text("Maintenance: \(maintenanceInput) kcal").foregroundColor(.secondary)
                }
                .padding()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Logic
    
    func estimateMaintenance() {
        guard let cWeight = currentWeight else { return }
        let weightKg = toKg(cWeight)
        let multiplier: Double = (gender == .male) ? 32.0 : 29.0
        let estimated = Int(weightKg * multiplier)
        maintenanceInput = String(estimated)
        // If daily goal isn't set yet, default it to maintenance initially
        if dailyGoalInput.isEmpty {
            dailyGoalInput = String(estimated)
        }
    }
    
    func calculateGoalFromDate() {
        guard !knowsDetails else { return }
        guard let maintenance = Int(maintenanceInput) else { return }
        guard let cWeight = currentWeight else { return }
        
        let currentKg = toKg(cWeight)
        
        // Handle Maintenance Case
        if goalType == .maintenance {
            dailyGoalInput = String(maintenance)
            return
        }
        
        // Handle Cutting/Bulking
        guard let tWeight = targetWeight else { return }
        let targetKg = toKg(tWeight)
        
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: targetDate)
        let components = Calendar.current.dateComponents([.day], from: today, to: target)
        let days = components.day ?? 1
        
        guard days > 0 else {
            dailyGoalInput = String(maintenance)
            return
        }
        
        let weightDiff = targetKg - currentKg
        let totalCaloriesNeeded = weightDiff * 7700.0
        let dailyAdjustment = Int(totalCaloriesNeeded / Double(days))
        let calculatedGoal = maintenance + dailyAdjustment
        dailyGoalInput = String(calculatedGoal)
    }
    
    func completeOnboarding() {
        guard let finalCurrent = currentWeight else { return }
        
        // 1. Resolve final target
        let finalTarget: Double
        if goalType == .maintenance {
            finalTarget = finalCurrent
        } else {
            finalTarget = targetWeight ?? finalCurrent
        }
        
        // 2. Normalize to storage units (Kg)
        let storedCurrentWeightKg = toKg(finalCurrent)
        let storedTargetWeightKg = toKg(finalTarget)
        
        // 3. Resolve Calorie values
        let storedMaintenance = Int(maintenanceInput) ?? 2500
        let storedDailyGoal = Int(dailyGoalInput) ?? 2000
        
        // 4. Create and Save UserProfile (This syncs to CloudKit)
        let profile = UserProfile()
        profile.unitSystem = unitSystem.rawValue
        profile.isDarkMode = isDarkMode
        profile.gender = gender.rawValue
        
        profile.goalType = goalType.rawValue
        profile.targetWeight = storedTargetWeightKg
        profile.maintenanceTolerance = maintenanceTolerance // Already in Kg
        
        profile.isCalorieCountingEnabled = isCalorieCountingEnabled
        profile.enableCaloriesBurned = trackCaloriesBurned
        profile.dailyCalorieGoal = storedDailyGoal
        profile.maintenanceCalories = storedMaintenance
        profile.estimationMethod = 0 // Default to simple
        
        modelContext.insert(profile)
        
        // --- ADDED THIS LINE ---
        // Mark onboarding as complete in Keychain so it survives re-installs
        KeychainManager.standard.setOnboardingComplete()
        // -----------------------
        
        // 5. Create First Weight Entry
        let firstEntry = WeightEntry(date: Date(), weight: storedCurrentWeightKg, note: "")
        modelContext.insert(firstEntry)
                
        // 6. Start First Goal Period
        dataManager.startNewGoalPeriod(
            goalType: goalType.rawValue,
            startWeight: storedCurrentWeightKg,
            targetWeight: storedTargetWeightKg,
            dailyCalorieGoal: storedDailyGoal,
            maintenanceCalories: storedMaintenance
        )
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
