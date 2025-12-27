import SwiftUI
import SwiftData

struct WorkoutTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    @State private var showingAddWorkout = false
    @State private var showingSettings = false
    @State private var showingLibrary = false // --- NEW STATE ---
    @State private var workoutToEdit: Workout? = nil
    
    @AppStorage("trackedMuscles") private var trackedMusclesString: String = "Chest,Back,Legs"
    
    var trackedMuscles: [String] {
        trackedMusclesString.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationView {
            List {
                // 1. Calendar View
                Section {
                    WorkoutCalendarView(workouts: workouts)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                
                // 2. Recovery Counters
                Section(header: Text("Recovery Tracker")) {
                    if trackedMuscles.isEmpty {
                        Text("Select muscles to track recovery time.")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 15) {
                            ForEach(trackedMuscles, id: \.self) { muscle in
                                RecoveryCard(muscle: muscle, days: daysSinceLastTrained(muscle))
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    
                    Button("Select Muscles") { showingSettings = true }
                        .font(.caption)
                }
                
                // 3. Recent Workouts
                Section(header: Text("Recent Workouts")) {
                    if workouts.isEmpty {
                        Text("No workouts yet. Tap + to add.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(workouts) { workout in
                            NavigationLink(destination: WorkoutDetailView(workout: workout)) {
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
            .navigationTitle("Workouts")
            .toolbar {
                // --- NEW: Library Button ---
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingLibrary = true }) {
                        Image(systemName: "dumbbell")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        workoutToEdit = nil
                        showingAddWorkout = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView(workoutToEdit: workoutToEdit)
            }
            .sheet(isPresented: $showingSettings) {
                MuscleSelectionView(selectedMusclesString: $trackedMusclesString)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(muscle).font(.headline)
            if let d = days {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(d)").font(.title).bold()
                        .foregroundColor(d > 4 ? .red : .green)
                    Text("days ago").font(.caption).foregroundColor(.secondary)
                }
            } else {
                Text("Not trained yet").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Subview: Simple Calendar Grid
struct WorkoutCalendarView: View {
    let workouts: [Workout]
    let days = ["S", "M", "T", "W", "T", "F", "S"]
    @State private var currentMonth = Date()
    
    // --- UPDATED STATE ---
    @State private var selectedWorkouts: [Workout] = []
    @State private var isNavigating = false
    
    var body: some View {
        VStack {
            // Month Header
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()
                Text(currentMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Spacer()
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }
            .padding(.bottom, 10)
            
            // Days Header
            HStack {
                ForEach(days, id: \.self) { day in
                    Text(day).font(.caption).bold().frame(maxWidth: .infinity)
                }
            }
            
            // Grid
            let daysInMonth = calendarDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        // --- UPDATED LOGIC: Find ALL workouts for this day ---
                        let dailyWorkouts = workouts.filter({ Calendar.current.isDate($0.date, inSameDayAs: date) })
                        let hasWorkout = !dailyWorkouts.isEmpty
                        
                        // Content for the day cell
                        VStack(spacing: 2) {
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.caption2)
                            
                            // Dot indicator
                            if hasWorkout {
                                HStack(spacing: 2) {
                                    // If multiple, show up to 2 dots, otherwise 1
                                    ForEach(dailyWorkouts.prefix(dailyWorkouts.count > 1 ? 2 : 1)) { w in
                                        Circle()
                                            .fill(categoryColor(w.category))
                                            .frame(width: 6, height: 6)
                                    }
                                }
                            } else {
                                Circle().fill(Color.clear).frame(width: 6, height: 6)
                            }
                        }
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(Calendar.current.isDateInToday(date) ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if hasWorkout {
                                selectedWorkouts = dailyWorkouts
                                isNavigating = true
                            }
                        }

                    } else {
                        Text("").frame(height: 40)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
        // --- UPDATED NAVIGATION ---
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
    
    // --- NEW: Computes where to go based on how many workouts are on that day ---
    @ViewBuilder
    var destinationView: some View {
        if selectedWorkouts.count == 1, let first = selectedWorkouts.first {
            WorkoutDetailView(workout: first)
        } else {
            DailyWorkoutListView(workouts: selectedWorkouts)
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
        
        let weekday = calendar.component(.weekday, from: firstDay) // 1 = Sun, 2 = Mon...
        
        var days: [Date?] = Array(repeating: nil, count: weekday - 1)
        
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }
}

// --- NEW VIEW: List for days with multiple workouts ---
struct DailyWorkoutListView: View {
    let workouts: [Workout]
    
    var body: some View {
        List(workouts) { workout in
            NavigationLink(destination: WorkoutDetailView(workout: workout)) {
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
    @Binding var selectedMusclesString: String
    @Environment(\.dismiss) var dismiss
    
    let allMuscles = ["Chest", "Back", "Legs", "Shoulders", "Biceps", "Triceps", "Abs", "Cardio"]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(allMuscles, id: \.self) { muscle in
                    HStack {
                        Text(muscle)
                        Spacer()
                        if selectedMusclesString.contains(muscle) {
                            Image(systemName: "checkmark").foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleMuscle(muscle)
                    }
                }
            }
            .navigationTitle("Track Muscles")
            .toolbar { Button("Done") { dismiss() } }
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
