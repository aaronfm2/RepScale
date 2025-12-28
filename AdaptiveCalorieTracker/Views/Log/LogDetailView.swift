import SwiftUI
import SwiftData

struct LogDetailView: View {
    @Bindable var log: DailyLog
    let workouts: [Workout]
    
    @EnvironmentObject var healthManager: HealthManager
    @State private var isSyncing = false
    @AppStorage("enableCaloriesBurned") private var enableCaloriesBurned: Bool = true
    
    @AppStorage("isCalorieCountingEnabled") private var isCalorieCountingEnabled: Bool = true
    @State private var showingEditOverrides = false
    
    // MARK: - Dark Mode & Colors
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    var appBackgroundColor: Color {
        isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var cardBackgroundColor: Color {
        isDarkMode ? Color(red: 0.153, green: 0.153, blue: 0.165) : Color.white
    }
    
    func groupExercises(_ exercises: [ExerciseEntry]) -> [(name: String, sets: [ExerciseEntry])] {
        var groups: [(name: String, sets: [ExerciseEntry])] = []
        for exercise in exercises {
            if let last = groups.last, last.name == exercise.name {
                groups[groups.count - 1].sets.append(exercise)
            } else {
                groups.append((name: exercise.name, sets: [exercise]))
            }
        }
        return groups
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                dateHeader
                
                if isCalorieCountingEnabled {
                    if log.isOverridden {
                        manualOverrideBanner
                    }
                    nutritionSection
                }
                
                workoutsSection
            }
            .padding(.bottom, 30)
        }
        .background(appBackgroundColor) // Apply Main Background
        .navigationTitle("Daily Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if isCalorieCountingEnabled {
                        Button("Edit") { showingEditOverrides = true }
                    }
                    
                    Button(action: syncHealthData) {
                        if isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isSyncing)
                }
            }
        }
        .sheet(isPresented: $showingEditOverrides) {
            EditOverridesSheet(log: log)
        }
    }
    
    private func syncHealthData() {
        isSyncing = true
        Task {
            let data = await healthManager.fetchHistoricalHealthData(for: log.date)
            await MainActor.run {
                withAnimation {
                    if data.consumed > 0 { log.caloriesConsumed = Int(data.consumed) + log.manualCalories }
                    if enableCaloriesBurned { log.caloriesBurned = Int(data.burned) }
                    
                    if data.protein > 0 { log.protein = Int(data.protein) + log.manualProtein }
                    if data.carbs > 0 { log.carbs = Int(data.carbs) + log.manualCarbs }
                    if data.fat > 0 { log.fat = Int(data.fat) + log.manualFat }
                    
                    isSyncing = false
                }
            }
        }
    }

    private var manualOverrideBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Includes Manual Adjustments")
                .font(.headline)
                .foregroundColor(.purple)
            Text("Values below include data from HealthKit plus your manual additions.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider().padding(.vertical, 4)
            
            HStack {
                Text("Added:")
                if log.manualCalories != 0 { Text("\(log.manualCalories) kcal").bold() }
                if log.manualProtein != 0 { Text("\(log.manualProtein)g P") }
                if log.manualCarbs != 0 { Text("\(log.manualCarbs)g C") }
                if log.manualFat != 0 { Text("\(log.manualFat)g F") }
            }
            .font(.caption)
            .foregroundColor(.purple)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.1)))
        .padding(.horizontal)
    }
    
    private var dateHeader: some View {
        VStack(spacing: 5) {
            Text(log.date, format: .dateTime.weekday(.wide).month().day())
                .font(.title2).bold()
            Text(log.date, format: .dateTime.year())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top)
    }
    
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Nutrition Total").font(.headline)
            
            HStack(spacing: 20) {
                MacroCard(title: "Protein", value: log.protein, color: .red, backgroundColor: isDarkMode ? Color.gray.opacity(0.1) : Color(uiColor: .tertiarySystemGroupedBackground))
                MacroCard(title: "Carbs", value: log.carbs, color: .blue, backgroundColor: isDarkMode ? Color.gray.opacity(0.1) : Color(uiColor: .tertiarySystemGroupedBackground))
                MacroCard(title: "Fats", value: log.fat, color: .yellow, backgroundColor: isDarkMode ? Color.gray.opacity(0.1) : Color(uiColor: .tertiarySystemGroupedBackground))
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Consumed")
                        .font(.caption).foregroundColor(.secondary)
                    Text("\(log.caloriesConsumed)")
                        .font(.title3).bold()
                }
                Spacer()
                
                if enableCaloriesBurned {
                    VStack(alignment: .trailing) {
                        Text("Calories Burned")
                            .font(.caption).foregroundColor(.secondary)
                        Text("\(log.caloriesBurned)")
                            .font(.title3).bold()
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        // Apply Card Background
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackgroundColor))
        .padding(.horizontal)
    }
    
    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Workouts").font(.headline).padding(.horizontal)
            
            if workouts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "figure.run.circle")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No workout logged for this day.")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.05)))
                .padding(.horizontal)
            } else {
                ForEach(workouts) { w in
                    workoutCard(for: w)
                }
            }
        }
    }
    
    private func workoutCard(for w: Workout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(w.category).font(.title3).bold().foregroundColor(.blue)
                    Text(w.muscleGroups.joined(separator: ", ")).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "dumbbell.fill").font(.largeTitle).foregroundColor(.blue.opacity(0.2))
            }
            .padding(.bottom, 5)
            Divider()
            if w.exercises.isEmpty {
                Text("No exercises logged.").font(.caption).italic().foregroundColor(.secondary)
            } else {
                let grouped = groupExercises(w.exercises)
                ForEach(grouped, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.name).font(.headline).foregroundColor(.primary).padding(.top, 4)
                        ForEach(Array(group.sets.enumerated()), id: \.element) { index, exercise in
                            exerciseRow(for: exercise, setNumber: index + 1)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
            if !w.note.isEmpty {
                Divider()
                Text("Note: \(w.note)").font(.caption).italic().foregroundColor(.secondary)
            }
        }
        .padding()
        // Apply Card Background
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackgroundColor))
        .padding(.horizontal)
    }
    
    private func exerciseRow(for exercise: ExerciseEntry, setNumber: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Set \(setNumber)").font(.caption).foregroundColor(.secondary).frame(width: 40, alignment: .leading)
                Divider().frame(height: 15)
                if exercise.isCardio {
                    HStack(spacing: 8) {
                        if let dist = exercise.distance, dist > 0 { Text("\(dist, specifier: "%.2f") km") }
                        if let time = exercise.duration, time > 0 { Text("\(Int(time)) min") }
                    }
                    .font(.callout).monospacedDigit().foregroundColor(.blue)
                } else {
                    Text("\(exercise.reps ?? 0) x \(exercise.weight ?? 0.0, specifier: "%.1f") kg")
                        .font(.callout).monospacedDigit()
                }
                Spacer()
            }
            if !exercise.note.isEmpty {
                Text(exercise.note).font(.caption).foregroundColor(.secondary).padding(.leading, 50)
            }
        }
        .padding(.vertical, 2)
    }
}

// Edit Manual Overrides Sheet
struct EditOverridesSheet: View {
    @Bindable var log: DailyLog
    @Environment(\.dismiss) var dismiss
    
    @State private var editedCalories: Int = 0
    @State private var editedProtein: Int = 0
    @State private var editedCarbs: Int = 0
    @State private var editedFat: Int = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Manual Additions")) {
                    HStack {
                        Text("Calories (+)")
                        Spacer()
                        TextField("0", value: $editedCalories, format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Protein (+)")
                        Spacer()
                        TextField("0", value: $editedProtein, format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Carbs (+)")
                        Spacer()
                        TextField("0", value: $editedCarbs, format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Fat (+)")
                        Spacer()
                        TextField("0", value: $editedFat, format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                }
                Section(footer: Text("Adjusting these values updates the Total instantly. HealthKit data remains the baseline.")) { }
            }
            .navigationTitle("Edit Manual Entries")
            .toolbar {
                Button("Done") {
                    saveChanges()
                    dismiss()
                }
            }
            .onAppear {
                editedCalories = log.manualCalories
                editedProtein = log.manualProtein
                editedCarbs = log.manualCarbs
                editedFat = log.manualFat
            }
        }
    }
    
    private func saveChanges() {
        let calDiff = editedCalories - log.manualCalories
        let pDiff = editedProtein - log.manualProtein
        let cDiff = editedCarbs - log.manualCarbs
        let fDiff = editedFat - log.manualFat
        
        log.caloriesConsumed += calDiff
        if let currentP = log.protein { log.protein = currentP + pDiff } else { log.protein = pDiff }
        if let currentC = log.carbs { log.carbs = currentC + cDiff } else { log.carbs = cDiff }
        if let currentF = log.fat { log.fat = currentF + fDiff } else { log.fat = fDiff }
        
        log.manualCalories = editedCalories
        log.manualProtein = editedProtein
        log.manualCarbs = editedCarbs
        log.manualFat = editedFat
    }
}

struct MacroCard: View {
    let title: String
    let value: Int?
    let color: Color
    let backgroundColor: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.caption).fontWeight(.bold).foregroundColor(color)
            if let v = value {
                Text("\(v)g").font(.headline)
            } else {
                Text("-").font(.headline).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
