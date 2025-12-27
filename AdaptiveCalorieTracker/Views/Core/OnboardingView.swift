import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @Environment(\.modelContext) private var modelContext
    
    // ... [Keep existing state variables] ...
    @State private var currentStep = 0
    @AppStorage("unitSystem") private var unitSystem: String = UnitSystem.metric.rawValue
    
    // --- NEW: Calorie Counting Toggle ---
    @AppStorage("isCalorieCountingEnabled") private var isCalorieCountingEnabled: Bool = true
    
    // ... [Keep existing variables: gender, currentWeight, goalType etc] ...
    @State private var gender: Gender = .male
    @State private var currentWeight: Double? = nil
    @State private var targetWeight: Double? = nil
    @State private var goalType: GoalType = .cutting
    
    @State private var knowsDetails: Bool = false
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
    
    @State private var maintenanceInput: String = ""
    @State private var dailyGoalInput: String = ""
    @State private var trackCaloriesBurned: Bool = false
    
    // ... [Keep AppStorage keys] ...
    @AppStorage("dailyCalorieGoal") private var storedDailyGoal: Int = 2000
    @AppStorage("targetWeight") private var storedTargetWeight: Double = 70.0
    @AppStorage("goalType") private var storedGoalType: String = GoalType.cutting.rawValue
    @AppStorage("maintenanceCalories") private var storedMaintenance: Int = 2500
    @AppStorage("enableCaloriesBurned") private var storedEnableCaloriesBurned: Bool = true
    
    // ... [Keep Enums and Helpers] ...
    enum Gender: String, CaseIterable {
        case male = "Male"
        case female = "Female"
    }

    var unitLabel: String {
        return unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg"
    }
    
    func toKg(_ value: Double) -> Double {
        return unitSystem == UnitSystem.imperial.rawValue ? value / 2.20462 : value
    }

    var body: some View {
        // ... [Keep existing body structure] ...
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
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
                        Button("Back") { currentStep -= 1 }
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if currentStep < 4 {
                        Button("Next") {
                            withAnimation {
                                if currentStep == 1 { estimateMaintenance() }
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(cannotMoveForward)
                    } else {
                        Button("Get Started") {
                            completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
    }
    
    var cannotMoveForward: Bool {
        if currentStep == 1 { return currentWeight == nil }
        if currentStep == 2 { return targetWeight == nil }
        return false
    }
    
    // ... [Keep welcomeStep, biometricsStep, goalsStep] ...
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
                        Text(system.rawValue).tag(system.rawValue)
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
        .navigationTitle("About You")
    }
    
    var goalsStep: some View {
        Form {
            Section(header: Text("Your Goal")) {
                HStack {
                    Text("Target Weight (\(unitLabel))")
                    Spacer()
                    TextField("Required", value: $targetWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: targetWeight) { _, _ in determineGoalType() }
                }
                HStack {
                    Text("Goal Type")
                    Spacer()
                    Text(goalType.rawValue)
                        .fontWeight(.medium)
                        .foregroundColor(goalTypeColor)
                }
            }
            Section(footer: Text("We automatically calculate if you are cutting, bulking, or maintaining based on your target weight.")) {}
        }
        .navigationTitle("Goals")
        .onAppear { determineGoalType() }
    }

    // --- UPDATED: Strategy Step with Toggle ---
    var strategyStep: some View {
        Form {
            Section(header: Text("Preferences")) {
                // Toggle to disable/enable calorie counting
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
        .navigationTitle("Plan")
    }
    
    // --- UPDATED: Final Step ---
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
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
    
    // ... [Keep logic functions: determineGoalType, goalTypeColor, estimateMaintenance, calculateGoalFromDate, completeOnboarding] ...
    func determineGoalType() {
        guard let tWeight = targetWeight, let cWeight = currentWeight else {
            goalType = .maintenance
            return
        }
        if tWeight > cWeight {
            goalType = .bulking
        } else if tWeight < cWeight {
            goalType = .cutting
        } else {
            goalType = .maintenance
        }
    }
    
    var goalTypeColor: Color {
        switch goalType {
        case .cutting: return .green
        case .bulking: return .red
        case .maintenance: return .blue
        }
    }
    
    func estimateMaintenance() {
        guard let cWeight = currentWeight else { return }
        let weightKg = toKg(cWeight)
        let multiplier: Double = (gender == .male) ? 32.0 : 29.0
        let estimated = Int(weightKg * multiplier)
        maintenanceInput = String(estimated)
    }
    
    func calculateGoalFromDate() {
        guard !knowsDetails else { return }
        guard let maintenance = Int(maintenanceInput) else { return }
        guard let tWeight = targetWeight, let cWeight = currentWeight else { return }
        let currentKg = toKg(cWeight)
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
        guard let finalCurrent = currentWeight, let finalTarget = targetWeight else { return }
        let storedCurrentWeightKg = toKg(finalCurrent)
        let storedTargetWeightKg = toKg(finalTarget)
        
        storedGoalType = goalType.rawValue
        storedTargetWeight = storedTargetWeightKg
        storedEnableCaloriesBurned = trackCaloriesBurned
        
        // If enabled, save inputs, otherwise use defaults
        if isCalorieCountingEnabled {
            storedMaintenance = Int(maintenanceInput) ?? 2500
            storedDailyGoal = Int(dailyGoalInput) ?? 2000
        }
        
        let firstEntry = WeightEntry(date: Date(), weight: storedCurrentWeightKg)
        modelContext.insert(firstEntry)
        isCompleted = true
    }
}
