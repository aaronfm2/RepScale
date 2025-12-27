import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @Environment(\.modelContext) private var modelContext
    
    // --- Step Control ---
    @State private var currentStep = 0
    
    // --- User Inputs ---
    @State private var gender: Gender = .male
    @State private var currentWeight: Double = 70.0
    @State private var targetWeight: Double = 65.0
    @State private var goalType: GoalType = .cutting
    
    // Branching Logic
    @State private var knowsDetails: Bool = false
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
    
    // Manual/Calculated Inputs
    @State private var maintenanceInput: String = ""
    @State private var dailyGoalInput: String = ""
    @State private var trackCaloriesBurned: Bool = true
    
    // --- AppStorage Keys ---
    @AppStorage("dailyCalorieGoal") private var storedDailyGoal: Int = 2000
    @AppStorage("targetWeight") private var storedTargetWeight: Double = 70.0
    @AppStorage("goalType") private var storedGoalType: String = GoalType.cutting.rawValue
    @AppStorage("maintenanceCalories") private var storedMaintenance: Int = 2500
    @AppStorage("enableCaloriesBurned") private var storedEnableCaloriesBurned: Bool = true
    
    enum Gender: String, CaseIterable {
        case male = "Male"
        case female = "Female"
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            VStack {
                // Progress Bar
                ProgressView(value: Double(currentStep), total: 4)
                    .padding()
                
                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    biometricsStep.tag(1)
                    goalsStep.tag(2)
                    strategyStep.tag(3) // The new branching step
                    finalStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Navigation Buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") { currentStep -= 1 }
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if currentStep < 4 {
                        Button("Next") {
                            withAnimation {
                                // Perform logic when moving away from steps
                                if currentStep == 1 { estimateMaintenance() }
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
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
            Section(header: Text("Biometrics")) {
                Picker("Gender", selection: $gender) {
                    ForEach(Gender.allCases, id: \.self) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                .pickerStyle(.segmented)
                
                HStack {
                    Text("Current Weight (kg)")
                    Spacer()
                    TextField("0.0", value: $currentWeight, format: .number)
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
                Picker("Goal Type", selection: $goalType) {
                    ForEach(GoalType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                HStack {
                    Text("Target Weight (kg)")
                    Spacer()
                    TextField("0.0", value: $targetWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .navigationTitle("Goals")
    }
    
    var strategyStep: some View {
        Form {
            Section(header: Text("Strategy")) {
                Toggle("I already know my calorie targets", isOn: $knowsDetails)
            }
            
            if knowsDetails {
                // Option A: User knows their numbers
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
                // Option B: Calculate based on Date
                Section(header: Text("Timeframe")) {
                    DatePicker("Achieve Goal By", selection: $targetDate, in: Date()..., displayedComponents: .date)
                        .onChange(of: targetDate) { _, _ in calculateGoalFromDate() }
                        .onChange(of: maintenanceInput) { _, _ in calculateGoalFromDate() } // Recalculate if maintenance changes
                }
                
                Section(header: Text("Calculations")) {
                    HStack {
                        Text("Est. Maintenance")
                        Spacer()
                        // Allow them to tweak the estimate if they want, even in auto mode
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
                    // Ensure calculation runs when view appears
                    calculateGoalFromDate()
                }
            }
            
            Section(header: Text("Preferences")) {
                Toggle("Track Calories Burned?", isOn: $trackCaloriesBurned)
            }
        }
        .navigationTitle("Plan")
    }
    
    var finalStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("You're All Set!")
                .font(.title).bold()
            
            Text("We've saved your starting weight and configured your daily calorie goal.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
            
            VStack(spacing: 10) {
                Text("Daily Goal: \(dailyGoalInput) kcal").bold()
                Text("Maintenance: \(maintenanceInput) kcal").foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Logic
    
    /// 1. Estimate Maintenance based on weight/gender
    func estimateMaintenance() {
        // Only override if empty or user hasn't typed a custom value yet (simple heuristic)
        // Multiplier: Male ~32, Female ~29
        let multiplier: Double = (gender == .male) ? 32.0 : 29.0
        let estimated = Int(currentWeight * multiplier)
        maintenanceInput = String(estimated)
    }
    
    /// 2. Calculate Daily Goal based on Date
    func calculateGoalFromDate() {
        guard !knowsDetails else { return }
        guard let maintenance = Int(maintenanceInput) else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: targetDate)
        
        // Days difference
        let components = Calendar.current.dateComponents([.day], from: today, to: target)
        let days = components.day ?? 1
        
        // Avoid division by zero or negative days
        guard days > 0 else {
            dailyGoalInput = String(maintenance)
            return
        }
        
        // Total change needed (kg)
        let weightDiff = targetWeight - currentWeight
        
        // Total Calories (7700 kcal per kg)
        let totalCaloriesNeeded = weightDiff * 7700.0
        
        // Daily Adjustment
        let dailyAdjustment = Int(totalCaloriesNeeded / Double(days))
        
        // Result
        let calculatedGoal = maintenance + dailyAdjustment
        dailyGoalInput = String(calculatedGoal)
    }
    
    func completeOnboarding() {
        // Save Settings
        storedGoalType = goalType.rawValue
        storedTargetWeight = targetWeight
        storedEnableCaloriesBurned = trackCaloriesBurned
        
        storedMaintenance = Int(maintenanceInput) ?? 2500
        storedDailyGoal = Int(dailyGoalInput) ?? 2000
        
        // Save Starting Weight
        let firstEntry = WeightEntry(date: Date(), weight: currentWeight)
        modelContext.insert(firstEntry)
        
        // Finish
        isCompleted = true
    }
}
