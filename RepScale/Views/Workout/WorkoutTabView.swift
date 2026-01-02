import SwiftUI
import SwiftData

struct WorkoutTabView: View {
    // --- CLOUD SYNC: Injected Profile ---
    @Bindable var profile: UserProfile
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    @State private var showingAddWorkout = false
    @State private var showingSettings = false
    @State private var showingLibrary = false
    @State private var workoutToEdit: Workout? = nil
    
    // MARK: - Computed Properties
    
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
                        
                        // Workout History Button
                        NavigationLink(destination: WorkoutHistoryView(profile: profile)) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.blue)
                                Text("Workout History")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                            }
                            .padding()
                            .background(cardBackgroundColor)
                            .cornerRadius(12)
                        }
                        .padding(.top, 8)
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
                
                // 3. Recent Workouts
                Section(header: Text("Recent Workouts")) {
                    if workouts.isEmpty {
                        Text("No workouts yet. Tap + to add.")
                            .foregroundColor(.secondary)
                            .listRowBackground(cardBackgroundColor)
                    } else {
                        ForEach(workouts) { workout in
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
                // Pass the profile binding for muscles
                MuscleSelectionView(selectedMusclesString: $profile.trackedMuscles)
            }
            .sheet(isPresented: $showingLibrary) {
                ExerciseLibraryView()
            }
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

// Subview: Enhanced Calendar Grid
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
            // Month Header
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
            
            // Days Header
            HStack {
                ForEach(0..<7, id: \.self) { index in
                    Text(days[index])
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Grid
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

// List for days with multiple workouts
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

// UPDATED: MuscleSelectionView with Add Custom Muscle logic
struct MuscleSelectionView: View {
    @Binding var selectedMusclesString: String
    @Environment(\.dismiss) var dismiss
    
    // State for adding new muscles
    @State private var newMuscleName: String = ""
    
    // Derived lists
    var currentList: [String] {
        selectedMusclesString.components(separatedBy: ",").filter { !$0.isEmpty }
    }
    
    var customMuscles: [String] {
        let standard = Set(MuscleGroup.allCases.map { $0.rawValue })
        return currentList.filter { !standard.contains($0) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Section 1: Add New Muscle
                Section("Add Custom Muscle") {
                    HStack {
                        TextField("Muscle Name (e.g. Forearms)", text: $newMuscleName)
                            .textInputAutocapitalization(.words)
                        Button(action: addMuscle) {
                            Text("Add")
                                .fontWeight(.bold)
                        }
                        .disabled(newMuscleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
                // Section 2: Standard Muscles (Enum)
                Section("Standard Muscles") {
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        HStack {
                            Text(muscle.rawValue)
                            Spacer()
                            if selectedMusclesString.contains(muscle.rawValue) {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleMuscle(muscle.rawValue)
                        }
                    }
                }
                
                // Section 3: Custom Muscles (User added)
                if !customMuscles.isEmpty {
                    Section("Custom Muscles") {
                        ForEach(customMuscles, id: \.self) { muscle in
                            HStack {
                                Text(muscle)
                                Spacer()
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Toggling a custom muscle removes it (delete behavior)
                                toggleMuscle(muscle)
                            }
                        }
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
        
        // Prevent duplicates
        let current = selectedMusclesString.components(separatedBy: ",").filter { !$0.isEmpty }
        if !current.contains(trimmed) {
            var new = current
            new.append(trimmed)
            selectedMusclesString = new.joined(separator: ",")
            newMuscleName = "" // Reset field
        }
    }
    
    func toggleMuscle(_ muscle: String) {
        var current = selectedMusclesString.components(separatedBy: ",").filter { !$0.isEmpty }
        if current.contains(muscle) {
            current.removeAll { $0 == muscle }
        } else {
            current.append(muscle)
        }
        selectedMusclesString = current.joined(separator: ",")
    }
}
