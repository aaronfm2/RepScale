import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Navigation State
    @State private var currentStep = 0
    @FocusState private var isInputFocused: Bool
    
    // MARK: - Local Data Collection
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
    
    func toDisplay(_ kgValue: Double) -> Double {
        return unitSystem == .imperial ? kgValue * 2.20462 : kgValue
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            appBackgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Progress Bar
                if currentStep > 0 && currentStep < 4 {
                    ProgressView(value: Double(currentStep), total: 4)
                        .tint(.blue)
                        .padding(.horizontal)
                        .padding(.top, 10)
                }
                
                // Content
                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    biometricsStep.tag(1)
                    goalsStep.tag(2)
                    strategyStep.tag(3)
                    finalStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                
                // Bottom Navigation Bar
                if currentStep < 4 {
                    HStack {
                        if currentStep > 0 {
                            Button(action: {
                                hideKeyboard()
                                withAnimation { currentStep -= 1 }
                            }) {
                                Text("Back")
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Spacer()
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            hideKeyboard()
                            withAnimation {
                                if currentStep == 1 { estimateMaintenance() }
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
                    // Final Step Button
                    Button(action: {
                        hideKeyboard()
                        completeOnboarding()
                    }) {
                        Text("Start Your Journey")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
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
        .onTapGesture { hideKeyboard() }
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
    
    // MARK: - Step 0: Welcome
    var welcomeStep: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 200, height: 200)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                Text("Welcome to RepScale")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("Your personal companion for tracking weight,\nworkouts, and calories.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Step 1: Biometrics
    var biometricsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerText(title: "Tell us about yourself", subtitle: "We use this to estimate your baseline metabolism.")
                
                // Units
                HStack(spacing: 0) {
                    ForEach(UnitSystem.allCases, id: \.self) { system in
                        Button(action: { withAnimation { unitSystem = system } }) {
                            Text(system.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(unitSystem == system ? Color.blue : Color.clear)
                                .foregroundColor(unitSystem == system ? .white : .primary)
                                .contentShape(Rectangle()) // Make tappable
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                
                // Gender
                HStack(spacing: 16) {
                    selectionCard(title: "Male", icon: "figure.stand", isSelected: gender == .male) {
                        gender = .male
                    }
                    selectionCard(title: "Female", icon: "figure.stand.dress", isSelected: gender == .female) {
                        gender = .female
                    }
                }
                .padding(.horizontal)
                
                // Weight Input
                VStack(spacing: 10) {
                    Text("Current Weight")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        TextField("0", value: $currentWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .frame(width: 150)
                            .focused($isInputFocused)
                            .foregroundColor(.primary)
                        
                        Text(unitLabel)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.gray.opacity(0.1)))
                }
                
                Spacer(minLength: 50)
            }
            .padding(.top)
        }
    }
    
    // MARK: - Step 2: Goals
    var goalsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerText(title: "What is your goal?", subtitle: "Select a path to focus your training and nutrition.")
                
                // Goal Type Cards
                VStack(spacing: 12) {
                    selectionRow(title: "Cutting", subtitle: "Lose fat & preserve muscle", icon: "arrow.down.right.circle.fill", color: .green, isSelected: goalType == .cutting) {
                        goalType = .cutting
                    }
                    
                    selectionRow(title: "Bulking", subtitle: "Build muscle & strength", icon: "arrow.up.right.circle.fill", color: .orange, isSelected: goalType == .bulking) {
                        goalType = .bulking
                    }
                    
                    selectionRow(title: "Maintenance", subtitle: "Maintain current physique", icon: "equal.circle.fill", color: .blue, isSelected: goalType == .maintenance) {
                        goalType = .maintenance
                    }
                }
                .padding(.horizontal)
                
                Divider().padding(.horizontal)
                
                if goalType == .maintenance {
                    VStack(spacing: 10) {
                        Text("Maintenance Tolerance (+/-)")
                            .font(.headline).foregroundColor(.secondary)
                        
                        HStack(alignment: .firstTextBaseline) {
                            TextField("2.0", value: Binding(
                                get: { toDisplay(maintenanceTolerance) },
                                set: { maintenanceTolerance = toKg($0) }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .frame(width: 100)
                            .focused($isInputFocused)
                            
                            Text(unitLabel)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.1)))
                        
                        Text("Fluctuations within this range are considered normal.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    // Target Weight Input
                    VStack(spacing: 10) {
                        Text("Target Weight")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            TextField("0", value: $targetWeight, format: .number)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 60, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .frame(width: 150)
                                .focused($isInputFocused)
                            
                            Text(unitLabel)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.gray.opacity(0.1)))
                        
                        // Validation Text
                        if let t = targetWeight, let c = currentWeight {
                            if goalType == .cutting && t >= c {
                                Label("Target must be lower than current", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundColor(.red)
                            } else if goalType == .bulking && t <= c {
                                Label("Target must be higher than current", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Spacer(minLength: 50)
            }
            .padding(.top)
        }
    }

    // MARK: - Step 3: Strategy
    var strategyStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerText(title: "Tracking Strategy", subtitle: "Choose how you want to achieve your goals.")
                
                // Toggle Card
                VStack(spacing: 0) {
                    Toggle(isOn: $isCalorieCountingEnabled) {
                        VStack(alignment: .leading) {
                            Text("Count Calories")
                                .font(.headline)
                            Text("Track daily intake targets")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    if isCalorieCountingEnabled {
                        Divider().padding(.leading)
                        Toggle(isOn: $trackCaloriesBurned) {
                            VStack(alignment: .leading) {
                                Text("Track Calories Burned")
                                    .font(.headline)
                                Text("Adjust goal based on activity")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        
                        Divider().padding(.leading)
                        Toggle(isOn: $knowsDetails) {
                            VStack(alignment: .leading) {
                                Text("Manual Entry")
                                    .font(.headline)
                                Text("I know my specific macro targets")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }
                }
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                
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
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                    .onChange(of: targetDate) { _, _ in calculateGoalFromDate() }
                                    .onChange(of: maintenanceInput) { _, _ in calculateGoalFromDate() }
                            }
                            .padding(.horizontal)
                            
                            // Summary Card
                            VStack(spacing: 16) {
                                Text("Recommended Plan")
                                    .font(.headline)
                                
                                HStack(spacing: 30) {
                                    VStack {
                                        Text("Maintenance")
                                            .font(.caption).foregroundColor(.secondary)
                                        Text(maintenanceInput)
                                            .font(.title2).bold()
                                    }
                                    
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(.secondary)
                                    
                                    VStack {
                                        Text("Daily Goal")
                                            .font(.caption).foregroundColor(.secondary)
                                        Text(dailyGoalInput)
                                            .font(.title2).bold().foregroundColor(.blue)
                                    }
                                }
                                
                                if let goal = Int(dailyGoalInput), let maint = Int(maintenanceInput) {
                                    let diff = goal - maint
                                    Text(diff < 0 ? "\(abs(diff)) calorie deficit / day" : "+\(diff) calorie surplus / day")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(diff < 0 ? .green : .orange)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 12)
                                        .background((diff < 0 ? Color.green : Color.orange).opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                            .padding(.horizontal)
                            .onAppear { calculateGoalFromDate() }
                        }
                    }
                } else {
                    Text("We'll focus on tracking your workouts and weight trends instead.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Spacer(minLength: 50)
            }
            .padding(.top)
        }
    }
    
    // MARK: - Step 4: Final
    var finalStep: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 160, height: 160)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2), value: true)
            }
            
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.title).bold()
                Text("We've saved your starting weight and configured your profile.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            if isCalorieCountingEnabled {
                HStack(spacing: 40) {
                    VStack {
                        Text("\(dailyGoalInput)")
                            .font(.title).bold()
                        Text("Daily Goal")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    VStack {
                        Text("\(maintenanceInput)")
                            .font(.title).bold()
                        Text("Maintenance")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - UI Components
    
    private func headerText(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
    
    private func selectionCard(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation { action() } }) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(16)
            .foregroundColor(isSelected ? .blue : .primary)
            .contentShape(Rectangle()) // FIX: Makes the whole card clickable area
        }
        .buttonStyle(.plain) // FIX: Prevents style conflicts
    }
    
    private func selectionRow(title: String, subtitle: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation { action() } }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(isSelected ? color : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(color)
                }
            }
            .padding()
            .background(isSelected ? color.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle()) // FIX: Makes the empty space clickable
        }
        .buttonStyle(.plain) // FIX: Prevents style conflicts
    }
    
    private func inputField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .font(.title2).bold()
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
        }
    }
    
    // MARK: - Logic
    
    func estimateMaintenance() {
        guard let cWeight = currentWeight else { return }
        let weightKg = toKg(cWeight)
        let multiplier: Double = (gender == .male) ? 32.0 : 29.0
        let estimated = Int(weightKg * multiplier)
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
        
        let finalTarget: Double
        if goalType == .maintenance {
            finalTarget = finalCurrent
        } else {
            finalTarget = targetWeight ?? finalCurrent
        }
        
        let storedCurrentWeightKg = toKg(finalCurrent)
        let storedTargetWeightKg = toKg(finalTarget)
        
        let storedMaintenance = Int(maintenanceInput) ?? 2500
        let storedDailyGoal = Int(dailyGoalInput) ?? 2000
        
        let profile = UserProfile()
        profile.unitSystem = unitSystem.rawValue
        profile.isDarkMode = isDarkMode
        profile.gender = gender.rawValue
        
        profile.goalType = goalType.rawValue
        profile.targetWeight = storedTargetWeightKg
        profile.maintenanceTolerance = maintenanceTolerance
        
        profile.isCalorieCountingEnabled = isCalorieCountingEnabled
        profile.enableCaloriesBurned = trackCaloriesBurned
        profile.dailyCalorieGoal = storedDailyGoal
        profile.maintenanceCalories = storedMaintenance
        profile.estimationMethod = 0
        
        modelContext.insert(profile)
        
        // Seed Exercises
        DefaultExercises.seed(context: modelContext)
        
        // First Weight Entry
        let firstEntry = WeightEntry(date: Date(), weight: storedCurrentWeightKg, note: "")
        modelContext.insert(firstEntry)
                
        // Start Goal Period
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
