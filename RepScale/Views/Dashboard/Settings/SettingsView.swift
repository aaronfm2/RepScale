import SwiftUI
import SwiftData

struct SettingsView: View {
    // --- CLOUD SYNC: Injected Profile ---
    @Bindable var profile: UserProfile
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    // --- Access HealthManager to trigger sync ---
    @EnvironmentObject var healthManager: HealthManager
    
    // Properties passed from Parent
    let estimatedMaintenance: Int?
    let currentWeight: Double?
    
    // Internal State
    @State private var showingReconfigureGoal = false
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    
    // Helper accessors for Profile
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
            Form {
                // MARK: - Section 1: General Preferences
                Section {
                    Picker(selection: $profile.unitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Text(system.rawValue).tag(system.rawValue)
                        }
                    } label: {
                        Label("Unit System", systemImage: "ruler")
                            .foregroundColor(.primary)
                    }
                    
                    Toggle(isOn: $profile.isDarkMode) {
                        Label("Dark Mode", systemImage: "moon")
                            .foregroundColor(.primary)
                    }
                    
                    // Note: Profile stores gender as String, so we tag with rawValue
                    Picker(selection: $profile.gender) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            Text(gender.rawValue).tag(gender.rawValue)
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
                    Toggle(isOn: $profile.isCalorieCountingEnabled) {
                        Label("Enable Calorie Counting", systemImage: "flame")
                            .foregroundColor(.primary)
                    }
                    
                    if profile.isCalorieCountingEnabled {
                        Toggle(isOn: $profile.enableCaloriesBurned) {
                            Label("Track Calories Burned", systemImage: "figure.run")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Toggle(isOn: $profile.enableHealthKitSync) {
                        Label("HealthKit Sync", systemImage: "heart.text.square")
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("Tracking")
                } footer: {
                    if profile.isCalorieCountingEnabled {
                        Text("Enable Apple Health to automatically import nutrition data from apps like MyFitnessPal, Cronometer, or Lose It!.")
                    }
                }
                
                // MARK: - Section 3: Goal Dashboard
                if profile.isCalorieCountingEnabled {
                    Section {
                        // Strategy Summary
                        LabeledContent {
                            Text(profile.goalType)
                                .fontWeight(.semibold)
                                .foregroundColor(goalColor)
                        } label: {
                            Label("Goal Type", systemImage: "target")
                                .foregroundColor(.primary)
                        }
                        
                        LabeledContent("Daily Target") {
                            Text("\(profile.dailyCalorieGoal) kcal")
                                .monospacedDigit()
                        }
                        
                        LabeledContent("Target Weight") {
                            Text("\(profile.targetWeight.toUserWeight(system: profile.unitSystem), specifier: "%.1f") \(weightLabel)")
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
                        Picker(selection: $profile.estimationMethod) {
                            ForEach(EstimationMethod.allCases) { method in
                                Text(method.displayName).tag(method.rawValue)
                            }
                        } label: {
                            Label("Prediction Logic", systemImage: "chart.xyaxis.line")
                                .foregroundColor(.primary)
                        }
                        
                        // Maintenance Tolerance
                        if profile.goalType == GoalType.maintenance.rawValue {
                            let toleranceBinding = Binding<Double>(
                                get: { profile.maintenanceTolerance.toUserWeight(system: profile.unitSystem) },
                                set: { profile.maintenanceTolerance = $0.toStoredWeight(system: profile.unitSystem) }
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
                
                // MARK: - Section 4: Data Management
                Section {
                    Button(action: exportData) {
                        if isExporting {
                            HStack {
                                Text("Generating CSV...")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Label("Export Data to CSV", systemImage: "square.and.arrow.up")
                                .foregroundColor(.primary)
                        }
                    }
                    .disabled(isExporting)
                } header: {
                    Text("Data Management")
                }
                
                // MARK: - Section 5: Community
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
                    
                    if let url = URL(string: "https://apps.apple.com/app/id6757196736?action=write-review") {
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
                // Ensure GoalConfigurationView is updated to accept 'profile'
                GoalConfigurationView(
                    profile: profile,
                    appEstimatedMaintenance: estimatedMaintenance,
                    latestWeightKg: currentWeight
                )
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    // MARK: - Export Logic
    
    private func exportData() {
        isExporting = true
        Task {
            if let url = await generateCSV() {
                await MainActor.run {
                    self.exportURL = url
                    self.isExporting = false
                    self.showingShareSheet = true
                }
            } else {
                await MainActor.run {
                    self.isExporting = false
                }
            }
        }
    }
    
    @MainActor
    private func generateCSV() -> URL? {
        // 1. Fetch all data
        let logDescriptor = FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\.date)])
        let weightDescriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)])
        let workoutDescriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date)])
        let goalDescriptor = FetchDescriptor<GoalPeriod>(sortBy: [SortDescriptor(\.startDate)])
        
        guard let logs = try? modelContext.fetch(logDescriptor),
              let weights = try? modelContext.fetch(weightDescriptor),
              let workouts = try? modelContext.fetch(workoutDescriptor),
              let goals = try? modelContext.fetch(goalDescriptor) else { return nil }
        
        // 2. Prepare Unique Sorted Dates (Normalize BEFORE Set)
        let rawDates = logs.map { $0.date } + weights.map { $0.date } + workouts.map { $0.date }
        let uniqueDates = Set(rawDates.map { Calendar.current.startOfDay(for: $0) })
        let sortedDates = uniqueDates.sorted()
        
        // 3. Pre-calculate Weight Dates for Streak Logic
        let weightDays = Set(weights.map { Calendar.current.startOfDay(for: $0.date) })
        
        // Helper for Streak
        func getStreak(endingOn date: Date) -> Int {
            guard weightDays.contains(date) else { return 0 }
            var streak = 0
            var d = date
            while weightDays.contains(d) {
                streak += 1
                guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: d) else { break }
                d = prev
            }
            return streak
        }
        
        // 4. Build CSV
        var csv = "Date,Goal Type,Current Weight,Current Weight Streak,Goal Weight,Daily weight log notes,Workout Category,Muscles Trained,Sets and Reps completed,Calories Consumed,Calories Burned,Protein,Carbs,Fats,Daily summary notes\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for date in sortedDates {
            let dateStr = dateFormatter.string(from: date)
            
            // Find records for this day
            let dayLog = logs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
            let dayWeight = weights.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
            let dayWorkouts = workouts.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            
            // Resolve Goal - FIX: Normalize goal dates to StartOfDay to ignore time mismatches
            let activeGoal = goals.first(where: {
                let goalStart = Calendar.current.startOfDay(for: $0.startDate)
                let goalEnd = $0.endDate.map { Calendar.current.startOfDay(for: $0) }
                return goalStart <= date && (goalEnd == nil || goalEnd! >= date)
            })
            
            let rowGoalType = dayLog?.goalType ?? activeGoal?.goalType ?? ""
            let rowGoalWeight = activeGoal != nil ? String(format: "%.1f", activeGoal!.targetWeight) : ""
            
            // Weight & Streak
            let rowWeight = dayWeight != nil ? String(format: "%.1f", dayWeight!.weight) : ""
            let rowStreak = getStreak(endingOn: date)
            let rowStreakStr = rowStreak > 0 ? "\(rowStreak)" : ""
            let rowWeightNote = clean(dayWeight?.note)
            
            // Workout Info
            let categories = Set(dayWorkouts.map { $0.category }).joined(separator: "; ")
            let muscles = Set(dayWorkouts.flatMap { $0.muscleGroups }).joined(separator: "; ")
            
            // Flatten Exercises
            var exerciseDetails: [String] = []
            for w in dayWorkouts {
                // Handle optional exercises relationship
                for ex in (w.exercises ?? []) {
                    var details = ex.name
                    if ex.isCardio {
                        var parts: [String] = []
                        if let dist = ex.distance, dist > 0 { parts.append("\(dist)km") }
                        if let dur = ex.duration, dur > 0 { parts.append("\(Int(dur))min") }
                        if !parts.isEmpty { details += " (" + parts.joined(separator: ", ") + ")" }
                    } else {
                        if let r = ex.reps, let wt = ex.weight {
                            details += " \(r)x\(wt)kg"
                        }
                    }
                    exerciseDetails.append(details)
                }
            }
            let rowSets = clean(exerciseDetails.joined(separator: "; "))
            
            // Nutrition
            let rowCalConsumed = dayLog != nil ? "\(dayLog!.caloriesConsumed)" : ""
            let rowCalBurned = dayLog != nil ? "\(dayLog!.caloriesBurned)" : ""
            let rowProt = dayLog?.protein != nil ? "\(dayLog!.protein!)" : ""
            let rowCarb = dayLog?.carbs != nil ? "\(dayLog!.carbs!)" : ""
            let rowFat = dayLog?.fat != nil ? "\(dayLog!.fat!)" : ""
            let rowLogNote = clean(dayLog?.note)
            
            let row = "\(dateStr),\(clean(rowGoalType)),\(rowWeight),\(rowStreakStr),\(rowGoalWeight),\(rowWeightNote),\(clean(categories)),\(clean(muscles)),\(rowSets),\(rowCalConsumed),\(rowCalBurned),\(rowProt),\(rowCarb),\(rowFat),\(rowLogNote)\n"
            csv.append(row)
        }
        
        // 5. Write to Temp File
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "RepScale_Export_\(dateFormatter.string(from: Date())).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to create CSV: \(error)")
            return nil
        }
    }
    
    private func clean(_ input: String?) -> String {
        guard let input = input, !input.isEmpty else { return "" }
        var cleaned = input.replacingOccurrences(of: "\"", with: "\"\"")
        if cleaned.contains(",") || cleaned.contains("\n") {
            cleaned = "\"\(cleaned)\""
        }
        return cleaned
    }
}

// MARK: - Share Sheet Wrapper
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
