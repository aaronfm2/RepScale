import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted: Bool = false
    
    // MARK: - Navigation State
    @State private var currentStep = 0
    @FocusState private var isInputFocused: Bool
    
    // MARK: - Local Data Collection
    @State private var unitSystem: UnitSystem = .metric
    @State private var isDarkMode: Bool = true
    @State private var gender: Gender = .male
    
    // Biometrics
    @State private var currentWeight: Double? = nil
    
    // Height Logic
    @State private var heightUnit: UnitSystem = .metric // Independent toggle
    @State private var currentHeight: Double? = nil // Master source (cm)
    @State private var heightFt: Int? = nil // Temporary input
    @State private var heightIn: Int? = nil // Temporary input
    
    // Age Logic
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date())!
    
    @State private var activityLevel: ActivityLevel = .moderatelyActive
    
    @State private var targetWeight: Double? = nil
    @State private var goalType: GoalType = .cutting
    
    // Strategy & Calorie Settings
    @State private var isCalorieCountingEnabled: Bool = true
    @State private var trackCaloriesBurned: Bool = false
    @State private var maintenanceTolerance: Double = 2.0
    
    // Calculation State
    @State private var knowsDetails: Bool = false
    @State private var maintenanceInput: String = ""
    @State private var dailyGoalInput: String = ""
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
    
    // MARK: - Helpers
    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }
    
    private var computedAge: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 25
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
    
    func toDisplay(_ kgValue: Double) -> Double {
        return unitSystem == .imperial ? kgValue * 2.20462 : kgValue
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            appBackgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if currentStep > 0 && currentStep < 4 {
                    ProgressView(value: Double(currentStep), total: 4)
                        .tint(.blue)
                        .padding(.horizontal)
                        .padding(.top, 10)
                }
                
                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    biometricsStep.tag(1)
                    goalsStep.tag(2)
                    strategyStep.tag(3)
                    finalStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                
                // Bottom Navigation
                if currentStep < 4 {
                    HStack {
                        if currentStep > 0 {
                            Button(action: {
                                hideKeyboard()
                                withAnimation { currentStep -= 1 }
                            }) {
                                Text("Back").fontWeight(.medium).foregroundColor(.secondary)
                            }
                        } else {
                            Spacer()
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            hideKeyboard()
                            withAnimation {
                                if currentStep == 1 {
                                    resolveHeight()
                                    estimateMaintenance()
                                }
                                currentStep += 1
                            }
                        }) {
                            HStack {
                                Text(currentStep == 0 ? "Get Started" : "Next")
                                Image(systemName: "arrow.right")
                            }
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(cannotMoveForward ? Color.gray : Color.blue)
                            .clipShape(Capsule())
                        }
                        .disabled(cannotMoveForward)
                    }
                    .padding()
                    .background(appBackgroundColor.opacity(0.9))
                } else {
                    Button(action: {
                        hideKeyboard()
                        completeOnboarding()
                    }) {
                        Text("Start Your Journey")
                            .font(.headline).fontWeight(.bold).foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }.fontWeight(.bold).foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Validation
    var cannotMoveForward: Bool {
        if currentStep == 1 {
            // Must have weight
            if currentWeight == nil { return true }
            // Must have height (either direct cm or ft/in depending on mode)
            // Logic: if currentHeight is nil, we check if the user entered ft/in validly
            if currentHeight == nil {
                if heightUnit == .metric { return true }
                if heightUnit == .imperial && (heightFt == nil || heightIn == nil) { return true }
            }
            return false
        }
        if currentStep == 2 {
            if goalType == .maintenance { return false }
            guard let t = targetWeight, let c = currentWeight else { return true }
            if goalType == .cutting && t >= c { return true }
            if goalType == .bulking && t <= c { return true }
            return false
        }
        return false
    }
    
    // MARK: - Step 0: Welcome
    var welcomeStep: some View {
        VStack(spacing: 30) {
            Spacer()
            ZStack {
                Circle().fill(Color.blue.opacity(0.1)).frame(width: 200, height: 200)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 80)).foregroundColor(.blue)
            }
            VStack(spacing: 12) {
                Text("Welcome to RepScale").font(.system(size: 32, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                Text("Your personal companion for tracking weight,\nworkouts, and calories.").multilineTextAlignment(.center).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    // MARK: - Step 1: Biometrics
    var biometricsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerText(title: "Tell us about yourself", subtitle: "We use this to calculate your maintenance calories.")
                
                // Units
                HStack(spacing: 0) {
                    ForEach(UnitSystem.allCases, id: \.self) { system in
                        Button(action: {
                            withAnimation {
                                unitSystem = system
                                // Sync height unit only if it hasn't been explicitly toggled?
                                // Or just let them default together but change separately.
                                // Let's keep height unit separate as requested.
                            }
                        }) {
                            Text(system.rawValue)
                                .font(.subheadline).fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(unitSystem == system ? Color.blue : Color.clear)
                                .foregroundColor(unitSystem == system ? .white : .primary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                
                // Gender
                HStack(spacing: 16) {
                    selectionCard(title: "Male", icon: "figure.stand", isSelected: gender == .male) { gender = .male }
                    selectionCard(title: "Female", icon: "figure.stand.dress", isSelected: gender == .female) { gender = .female }
                }
                .padding(.horizontal)
                
                // Grid for Inputs
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    
                    // Age (Date of Birth)
                    VStack(alignment: .leading) {
                        Text("Date of Birth").font(.caption).foregroundColor(.secondary)
                        DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Height
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Height").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            // Independent Toggle
                            Picker("Height Unit", selection: $heightUnit) {
                                Text("cm").tag(UnitSystem.metric)
                                Text("ft/in").tag(UnitSystem.imperial)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 80)
                            .scaleEffect(0.8)
                            .onChange(of: heightUnit) { oldVal, newVal in
                                // Drift Prevention: Only convert display values when entering the mode.
                                if newVal == .imperial {
                                    if let cm = currentHeight {
                                        let totalInches = cm / 2.54
                                        heightFt = Int(totalInches / 12)
                                        heightIn = Int(totalInches.truncatingRemainder(dividingBy: 12))
                                    }
                                }
                                // When switching back to metric, we DO NOT auto-update 'currentHeight' from ft/in
                                // unless the user edited them. This keeps '180' as '180' even if 5'11" is slightly off.
                            }
                        }
                        
                        if heightUnit == .metric {
                            HStack {
                                TextField("cm", value: $currentHeight, format: .number)
                                    .keyboardType(.numberPad)
                                Text("cm").foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .focused($isInputFocused)
                        } else {
                            HStack {
                                TextField("ft", value: $heightFt, format: .number)
                                    .keyboardType(.numberPad)
                                    .onChange(of: heightFt) { _, _ in updateHeightFromImperial() }
                                Text("'")
                                TextField("in", value: $heightIn, format: .number)
                                    .keyboardType(.numberPad)
                                    .onChange(of: heightIn) { _, _ in updateHeightFromImperial() }
                                Text("\"")
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .focused($isInputFocused)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Activity Level
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity Level").font(.headline)
                    Picker("Activity", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    Text(activityLevel.description)
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Weight Input
                VStack(spacing: 10) {
                    Text("Current Weight").font(.headline).foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        TextField("0", value: $currentWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .frame(width: 150)
                            .focused($isInputFocused)
                        Text(unitLabel).font(.title2).fontWeight(.semibold).foregroundColor(.secondary)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.gray.opacity(0.1)))
                }
                
                Spacer(minLength: 50)
            }
            .padding(.top)
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    // MARK: - Step 2, 3, 4 (Standard)
    var goalsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerText(title: "What is your goal?", subtitle: "Select a path to focus your training and nutrition.")
                
                VStack(spacing: 12) {
                    selectionRow(title: "Cutting", subtitle: "Lose fat & preserve muscle", icon: "arrow.down.right.circle.fill", color: .green, isSelected: goalType == .cutting) { goalType = .cutting }
                    selectionRow(title: "Bulking", subtitle: "Build muscle & strength", icon: "arrow.up.right.circle.fill", color: .orange, isSelected: goalType == .bulking) { goalType = .bulking }
                    selectionRow(title: "Maintenance", subtitle: "Maintain current physique", icon: "equal.circle.fill", color: .blue, isSelected: goalType == .maintenance) { goalType = .maintenance }
                }
                .padding(.horizontal)
                
                Divider().padding(.horizontal)
                
                if goalType == .maintenance {
                    VStack(spacing: 10) {
                        Text("Maintenance Tolerance (+/-)").font(.headline).foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline) {
                            TextField("2.0", value: Binding(
                                get: { toDisplay(maintenanceTolerance) },
                                set: { maintenanceTolerance = toKg($0) }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .frame(width: 100).multilineTextAlignment(.center).focused($isInputFocused)
                            Text(unitLabel).font(.headline).foregroundColor(.secondary)
                        }
                        .padding().background(RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.1)))
                    }
                } else {
                    VStack(spacing: 10) {
                        Text("Target Weight").font(.headline).foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            TextField("0", value: $targetWeight, format: .number)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 60, weight: .bold, design: .rounded))
                                .frame(width: 150).multilineTextAlignment(.center).focused($isInputFocused)
                            Text(unitLabel).font(.title2).fontWeight(.semibold).foregroundColor(.secondary)
                        }
                        .padding().background(RoundedRectangle(cornerRadius: 20).fill(Color.gray.opacity(0.1)))
                        
                        if let t = targetWeight, let c = currentWeight {
                            if goalType == .cutting && t >= c {
                                Label("Target must be lower than current", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundColor(.red)
                            } else if goalType == .bulking && t <= c {
                                Label("Target must be higher than current", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundColor(.red)
                            }
                        }
                    }
                }
                Spacer(minLength: 50)
            }
            .padding(.top)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    var strategyStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerText(title: "Tracking Strategy", subtitle: "Choose how you want to achieve your goals.")
                
                VStack(spacing: 0) {
                    Toggle(isOn: $isCalorieCountingEnabled) {
                        VStack(alignment: .leading) {
                            Text("Count Calories").font(.headline)
                            Text("Track daily intake targets").font(.caption).foregroundColor(.secondary)
                        }
                    }.padding()
                    
                    if isCalorieCountingEnabled {
                        Divider().padding(.leading)
                        Toggle(isOn: $trackCaloriesBurned) {
                            VStack(alignment: .leading) {
                                Text("Track Calories Burned").font(.headline)
                                Text("Adjust goal based on activity").font(.caption).foregroundColor(.secondary)
                            }
                        }.padding()
                        Divider().padding(.leading)
                        Toggle(isOn: $knowsDetails) {
                            VStack(alignment: .leading) {
                                Text("Manual Entry").font(.headline)
                                Text("I know my specific macro targets").font(.caption).foregroundColor(.secondary)
                            }
                        }.padding()
                    }
                }
                .background(Color.gray.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
                
                if isCalorieCountingEnabled {
                    if knowsDetails {
                        VStack(spacing: 16) {
                            Text("Enter your custom targets").font(.headline)
                            HStack {
                                inputField(title: "Maintenance", text: $maintenanceInput)
                                inputField(title: "Daily Goal", text: $dailyGoalInput)
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Goal Deadline").font(.headline)
                                DatePicker("Achieve Goal By", selection: $targetDate, in: Date()..., displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .background(Color.gray.opacity(0.1)).cornerRadius(12)
                                    .onChange(of: targetDate) { _, _ in calculateGoalFromDate() }
                                    .onChange(of: maintenanceInput) { _, _ in calculateGoalFromDate() }
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 16) {
                                Text("Recommended Plan").font(.headline)
                                HStack(spacing: 30) {
                                    VStack { Text("Maintenance").font(.caption).foregroundColor(.secondary); Text(maintenanceInput).font(.title2).bold() }
                                    Image(systemName: "arrow.right").foregroundColor(.secondary)
                                    VStack { Text("Daily Goal").font(.caption).foregroundColor(.secondary); Text(dailyGoalInput).font(.title2).bold().foregroundColor(.blue) }
                                }
                                if let goal = Int(dailyGoalInput), let maint = Int(maintenanceInput) {
                                    let diff = goal - maint
                                    Text(diff < 0 ? "\(abs(diff)) calorie deficit / day" : "+\(diff) calorie surplus / day")
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(diff < 0 ? .green : .orange)
                                        .padding(.vertical, 4).padding(.horizontal, 12)
                                        .background((diff < 0 ? Color.green : Color.orange).opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding().frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.3), lineWidth: 1)).padding(.horizontal)
                            .onAppear { calculateGoalFromDate() }
                        }
                    }
                }
                Spacer(minLength: 50)
            }
            .padding(.top)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: currentStep) { _, newValue in
            if newValue == 3 {
                calculateGoalFromDate()
            }
        }
    }
    
    var finalStep: some View {
        VStack(spacing: 30) {
            Spacer()
            ZStack {
                Circle().fill(Color.green.opacity(0.1)).frame(width: 160, height: 160)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 80)).foregroundColor(.green)
                    .scaleEffect(1.0).animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2), value: true)
            }
            VStack(spacing: 12) {
                Text("You're All Set!").font(.title).bold()
                Text("We've saved your starting weight and configured your profile.").multilineTextAlignment(.center).foregroundColor(.secondary)
            }
            if isCalorieCountingEnabled {
                HStack(spacing: 40) {
                    VStack { Text("\(dailyGoalInput)").font(.title).bold(); Text("Daily Goal").font(.caption).foregroundColor(.secondary) }
                    VStack { Text("\(maintenanceInput)").font(.title).bold(); Text("Maintenance").font(.caption).foregroundColor(.secondary) }
                }
                .padding().background(Color.gray.opacity(0.1)).cornerRadius(16)
            }
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Views
    private func headerText(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.title2).fontWeight(.bold)
            Text(subtitle).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
    
    private func selectionCard(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation { action() } }) {
            VStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 32))
                Text(title).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2))
            .cornerRadius(16).foregroundColor(isSelected ? .blue : .primary).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func selectionRow(title: String, subtitle: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation { action() } }) {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.title).foregroundColor(isSelected ? color : .gray)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).fontWeight(.semibold).foregroundColor(.primary)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundColor(color) }
            }
            .padding().background(isSelected ? color.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? color : Color.clear, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func inputField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.secondary)
            TextField("0", text: text).keyboardType(.numberPad).font(.title2).bold().padding().background(Color.gray.opacity(0.1)).cornerRadius(10).focused($isInputFocused)
        }
    }
    
    // MARK: - Logic
    
    func updateHeightFromImperial() {
        if let ft = heightFt, let inches = heightIn {
            let totalInches = (Double(ft) * 12.0) + Double(inches)
            currentHeight = totalInches * 2.54
        }
    }
    
    // Final check to ensure consistency if they typed in Imperial but didn't trigger an update (rare) or just to be safe
    func resolveHeight() {
        if heightUnit == .imperial {
            updateHeightFromImperial()
        }
    }
    
    func estimateMaintenance() {
        guard let cWeight = currentWeight,
              let cHeight = currentHeight else { return }
              
        let weightKg = toKg(cWeight)
        
        // Mifflin-St Jeor Equation
        // Men: (10 × weight in kg) + (6.25 × height in cm) - (5 × age in years) + 5
        let base: Double = (10 * weightKg) + (6.25 * cHeight) - (5 * Double(computedAge))
        let genderOffset: Double = (gender == .male) ? 5 : -161
        let bmr = base + genderOffset
        
        let tdee = bmr * activityLevel.multiplier
        
        let estimated = Int(tdee)
        maintenanceInput = String(estimated)
        if dailyGoalInput.isEmpty {
            dailyGoalInput = String(estimated)
        }
    }
    
    func calculateGoalFromDate() {
        guard !knowsDetails else { return }
        guard let maintenance = Int(maintenanceInput) else { return }
        guard let cWeight = currentWeight else { return }
        
        let currentKg = toKg(cWeight)
        
        if goalType == .maintenance {
            dailyGoalInput = String(maintenance)
            return
        }
        
        guard let tWeight = targetWeight else { return }
        let targetKg = toKg(tWeight)
        
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: targetDate)
        let days = Calendar.current.dateComponents([.day], from: today, to: target).day ?? 1
        
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
        let finalTarget = (goalType == .maintenance) ? finalCurrent : (targetWeight ?? finalCurrent)
        
        // 2. Normalize to storage units (Kg, Cm)
        let storedCurrentWeightKg = toKg(finalCurrent)
        let storedTargetWeightKg = toKg(finalTarget)
        let storedMaintenance = Int(maintenanceInput) ?? 2500
        let storedDailyGoal = Int(dailyGoalInput) ?? 2000
        let storedHeight = currentHeight ?? 175.0
        
        // 3. Create and Save UserProfile
        let profile = UserProfile()
        profile.unitSystem = unitSystem.rawValue
        profile.heightUnitPreference = heightUnit.rawValue // Save height preference
        profile.isDarkMode = isDarkMode
        profile.gender = gender.rawValue
        
        // New Fields
        profile.dateOfBirth = dateOfBirth
        profile.height = storedHeight
        profile.activityLevel = activityLevel.rawValue
        
        profile.goalType = goalType.rawValue
        profile.targetWeight = storedTargetWeightKg
        profile.maintenanceTolerance = maintenanceTolerance
        
        profile.isCalorieCountingEnabled = isCalorieCountingEnabled
        profile.enableCaloriesBurned = trackCaloriesBurned
        profile.dailyCalorieGoal = storedDailyGoal
        profile.maintenanceCalories = storedMaintenance
        profile.estimationMethod = 0
        
        modelContext.insert(profile)
        
        // 4. Seed Data
        DefaultExercises.seed(context: modelContext)
        let firstEntry = WeightEntry(date: Date(), weight: storedCurrentWeightKg, note: "")
        modelContext.insert(firstEntry)
              
        dataManager.startNewGoalPeriod(
            goalType: goalType.rawValue,
            startWeight: storedCurrentWeightKg,
            targetWeight: storedTargetWeightKg,
            dailyCalorieGoal: storedDailyGoal,
            maintenanceCalories: storedMaintenance
        )
        
        try? modelContext.save()
        
        withAnimation {
            isOnboardingCompleted = true
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
