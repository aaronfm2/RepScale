import SwiftUI
import SwiftData

struct WorkoutTabView: View {
    @Bindable var profile: UserProfile
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    @State private var showingAddWorkout = false
    @State private var showingSettings = false
    @State private var showingLibrary = false
    @State private var workoutToEdit: Workout? = nil
    
    // New state to control navigation programmatically for a cleaner UI
    @State private var isNavigatingHistory = false
    
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var cardBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.153, green: 0.153, blue: 0.165) : Color.white
    }
    
    var trackedMusclesList: [String] {
        profile.trackedMuscles.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                // 1. Calendar View
                Section {
                    WorkoutCalendarView(workouts: workouts, profile: profile)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                
                // 2. Recovery Tracker & History
                Section(header:
                    HStack {
                        Text("Recovery Tracker")
                        Spacer()
                        Button(action: { showingSettings = true }) {
                            HStack(spacing: 4) {
                                Text("Edit")
                                Image(systemName: "slider.horizontal.3")
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                        }
                    }
                ) {
                    if trackedMusclesList.isEmpty {
                        Text("Select muscles to track recovery time.")
                            .font(.caption).foregroundColor(.secondary)
                            .listRowBackground(cardBackgroundColor)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 15)], spacing: 15) {
                            ForEach(trackedMusclesList, id: \.self) { muscle in
                                RecoveryCard(muscle: muscle, days: daysSinceLastTrained(muscle), profile: profile)
                            }
                        }
                        .padding(.vertical, 5)
                        .listRowBackground(Color.clear)
                        
                        // --- IMPROVED BUTTON UI START ---
                        // We use a ZStack to hide the default NavigationLink chevron and render our own custom card.
                        ZStack {
                            NavigationLink(destination: WorkoutHistoryView(profile: profile), isActive: $isNavigatingHistory) {
                                EmptyView()
                            }
                            .opacity(0) // Completely hides the default row style
                            
                            Button(action: { isNavigatingHistory = true }) {
                                HStack(spacing: 12) {
                                    // Icon with background
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Text("View Workout History")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    // Custom chevron inside the card
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(cardBackgroundColor)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                            }
                            .buttonStyle(.plain) // Preserves the card tap animation
                        }
                        .padding(.top, 4)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets()) // Allows card to span correctly
                        // --- IMPROVED BUTTON UI END ---
                    }
                }
                
                // 3. Recent Workouts
                Section(header: Text("Recent Workouts")) {
                    if workouts.isEmpty {
                        Text("No workouts yet. Tap the top right + to add.")
                            .foregroundColor(.secondary)
                            .listRowBackground(cardBackgroundColor)
                    } else {
                        ForEach(workouts.prefix(5)) { workout in
                            NavigationLink(destination: WorkoutDetailView(workout: workout, profile: profile)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(workout.date, format: .dateTime.day().month())
                                            .font(.subheadline).bold()
                                        Text(workout.category)
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(workout.muscleGroups.joined(separator: ", "))
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            .listRowBackground(cardBackgroundColor)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteWorkout(workout)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    workoutToEdit = workout
                                    showingAddWorkout = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.yellow)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(appBackgroundColor)
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingLibrary = true }) {
                        Image(systemName: "dumbbell")
                    }
                    .spotlightTarget(.library)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        workoutToEdit = nil
                        showingAddWorkout = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .spotlightTarget(.addWorkout)
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView(workoutToEdit: workoutToEdit, profile: profile)
            }
            .sheet(isPresented: $showingSettings) {
                MuscleSelectionView(profile: profile)
            }
            .sheet(isPresented: $showingLibrary) {
                ExerciseLibraryView(profile: profile)
            }
            // Auto-clean duplicates when this view appears
            .onAppear {
                removeDuplicateExercises()
            }
        }
    }
    
    // MARK: - Duplicate Cleanup Logic
    private func removeDuplicateExercises() {
        do {
            let descriptor = FetchDescriptor<ExerciseDefinition>()
            let exercises = try modelContext.fetch(descriptor)
            
            // Group by name
            let grouped = Dictionary(grouping: exercises, by: { $0.name })
            
            for (_, duplicates) in grouped where duplicates.count > 1 {
                // Keep the one with the most information (prioritize muscle groups, then cardio flag)
                let sorted = duplicates.sorted { first, second in
                    if !first.muscleGroups.isEmpty && second.muscleGroups.isEmpty { return true }
                    if first.muscleGroups.isEmpty && !second.muscleGroups.isEmpty { return false }
                    if first.isCardio && !second.isCardio { return true }
                    return false
                }
                
                // Delete all except the first one (which is the "best" one based on sort)
                for exercise in sorted.dropFirst() {
                    modelContext.delete(exercise)
                }
            }
        } catch {
            print("Error cleaning up duplicate exercises: \(error)")
        }
    }
    
    private func deleteWorkout(_ workout: Workout) {
        withAnimation {
            modelContext.delete(workout)
        }
    }
    
    private func daysSinceLastTrained(_ muscle: String) -> Int? {
        if let lastWorkout = workouts.first(where: { $0.muscleGroups.contains(muscle) }) {
            let components = Calendar.current.dateComponents([.day], from: lastWorkout.date, to: Calendar.current.startOfDay(for: Date()))
            return components.day
        }
        return nil
    }
}

// Subview: Recovery Card
struct RecoveryCard: View {
    let muscle: String
    let days: Int?
    var profile: UserProfile
    
    var cardBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.153, green: 0.153, blue: 0.165) : Color.white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(muscle)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            if let d = days {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(d)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(d > 4 ? .red : .green)
                    Text("days")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                Text("ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .offset(y: -4)
            } else {
                Text("Not trained")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Text("yet")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 100)
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}

struct WorkoutCalendarView: View {
    let workouts: [Workout]
    let profile: UserProfile
    
    let days = ["S", "M", "T", "W", "T", "F", "S"]
    @State private var currentMonth = Date()
    @State private var selectedWorkouts: [Workout] = []
    @State private var isNavigating = false
    
    var cardBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.153, green: 0.153, blue: 0.165) : Color.white
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()
                Text(currentMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            HStack {
                ForEach(0..<7, id: \.self) { index in
                    Text(days[index])
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            let daysInMonth = calendarDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth.indices, id: \.self) { index in
                    if let date = daysInMonth[index] {
                        let dailyWorkouts = workouts.filter({ Calendar.current.isDate($0.date, inSameDayAs: date) })
                        let hasWorkout = !dailyWorkouts.isEmpty
                        let isToday = Calendar.current.isDateInToday(date)
                        
                        Button {
                            if hasWorkout {
                                selectedWorkouts = dailyWorkouts
                                isNavigating = true
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                                    .foregroundColor(isToday ? .white : .primary)
                                    .frame(width: 28, height: 28)
                                    .background(isToday ? Circle().fill(Color.blue) : Circle().fill(Color.clear))
                                
                                HStack(spacing: 3) {
                                    if hasWorkout {
                                        ForEach(dailyWorkouts.prefix(3)) { w in
                                            Circle()
                                                .fill(categoryColor(w.category))
                                                .frame(width: 4, height: 4)
                                        }
                                    } else {
                                        Circle().fill(Color.clear).frame(width: 4, height: 4)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(
                                hasWorkout && !isToday ? Color.blue.opacity(0.05) : Color.clear
                            )
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasWorkout)

                    } else {
                        Text("").frame(height: 40)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardBackgroundColor))
        .background(
            NavigationLink(
                destination: destinationView,
                isActive: $isNavigating
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
    
    @ViewBuilder
    var destinationView: some View {
        if selectedWorkouts.count == 1, let first = selectedWorkouts.first {
            WorkoutDetailView(workout: first, profile: profile)
        } else {
            DailyWorkoutListView(workouts: selectedWorkouts, profile: profile)
        }
    }
    
    func categoryColor(_ cat: String) -> Color {
        switch cat.lowercased() {
        case "push": return .red
        case "pull": return .blue
        case "legs": return .green
        default: return .orange
        }
    }
    
    func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    func calendarDays() -> [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else { return [] }
        
        let weekday = calendar.component(.weekday, from: firstDay)
        var days: [Date?] = Array(repeating: nil, count: weekday - 1)
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }
}

struct DailyWorkoutListView: View {
    let workouts: [Workout]
    let profile: UserProfile
    
    var body: some View {
        List(workouts) { workout in
            NavigationLink(destination: WorkoutDetailView(workout: workout, profile: profile)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(workout.category)
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text(workout.muscleGroups.joined(separator: ", "))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("Workouts")
    }
}

struct MuscleSelectionView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) var dismiss
    
    @State private var newMuscleName: String = ""
    
    var activeMuscles: Set<String> {
        Set(profile.trackedMuscles.components(separatedBy: ",").filter { !$0.isEmpty })
    }
    
    // FIX: Include tracked muscles that aren't yet in customMuscles (auto-migration)
    var customMusclesList: [String] {
        let savedCustom = profile.customMuscles.components(separatedBy: ",")
        let active = profile.trackedMuscles.components(separatedBy: ",")
        let standard = Set(MuscleGroup.allCases.map { $0.rawValue })
        
        let combined = Set(savedCustom + active).subtracting(standard)
        return Array(combined).filter { !$0.isEmpty }.sorted()
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Add Custom Muscle") {
                    HStack {
                        TextField("Muscle Name (e.g. Forearms)", text: $newMuscleName)
                            .textInputAutocapitalization(.words)
                        Button(action: addMuscle) {
                            Text("Add").fontWeight(.bold)
                        }
                        .disabled(newMuscleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
                Section("Standard Muscles") {
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        HStack {
                            Text(muscle.rawValue)
                            Spacer()
                            if activeMuscles.contains(muscle.rawValue) {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleTracking(muscle.rawValue)
                        }
                    }
                }
                
                if !customMusclesList.isEmpty {
                    Section("Custom Muscles") {
                        ForEach(customMusclesList, id: \.self) { muscle in
                            HStack {
                                Text(muscle)
                                Spacer()
                                if activeMuscles.contains(muscle) {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleTracking(muscle)
                            }
                        }
                        .onDelete(perform: deleteCustomMuscle)
                    }
                }
            }
            .navigationTitle("Track Muscles")
            .toolbar { Button("Done") { dismiss() } }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    func addMuscle() {
        let trimmed = newMuscleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Save to custom muscles list
        var custom = profile.customMuscles.components(separatedBy: ",").filter { !$0.isEmpty }
        if !custom.contains(trimmed) && MuscleGroup(rawValue: trimmed) == nil {
            custom.append(trimmed)
            profile.customMuscles = custom.joined(separator: ",")
            
            // Auto-track it
            toggleTracking(trimmed, forceOn: true)
            newMuscleName = ""
        }
    }
    
    func toggleTracking(_ muscle: String, forceOn: Bool = false) {
        var active = profile.trackedMuscles.components(separatedBy: ",").filter { !$0.isEmpty }
        
        // FIX: Before untracking, ensure it's saved in custom list so it doesn't disappear
        if MuscleGroup(rawValue: muscle) == nil {
            var custom = profile.customMuscles.components(separatedBy: ",").filter { !$0.isEmpty }
            if !custom.contains(muscle) {
                custom.append(muscle)
                profile.customMuscles = custom.joined(separator: ",")
            }
        }
        
        if forceOn {
            if !active.contains(muscle) { active.append(muscle) }
        } else {
            if active.contains(muscle) {
                active.removeAll { $0 == muscle }
            } else {
                active.append(muscle)
            }
        }
        
        profile.trackedMuscles = active.joined(separator: ",")
    }
    
    func deleteCustomMuscle(at offsets: IndexSet) {
        var custom = customMusclesList
        let removedItems = offsets.map { custom[$0] }
        
        // Remove from definitions
        var definitions = profile.customMuscles.components(separatedBy: ",").filter { !$0.isEmpty }
        definitions.removeAll { removedItems.contains($0) }
        profile.customMuscles = definitions.joined(separator: ",")
        
        // Remove from active tracking
        var active = profile.trackedMuscles.components(separatedBy: ",").filter { !$0.isEmpty }
        active.removeAll { removedItems.contains($0) }
        profile.trackedMuscles = active.joined(separator: ",")
    }
}
