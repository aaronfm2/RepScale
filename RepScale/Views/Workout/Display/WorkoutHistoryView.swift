import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    
    enum FilterType: String, CaseIterable {
        case category = "Category"
        case exercise = "Exercise"
    }
    
    @State private var filterType: FilterType = .category
    @Namespace private var animation
    
    // Defaults
    @State private var selectedCategory: String = "All"
    @State private var selectedExercise: String = "All"
    @State private var selectedReps: Int? = nil
    
    // CACHE: Stores unique exercise names to prevent expensive recalculation on main thread
    @State private var cachedUniqueExercises: [String] = []
    
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var cardBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.153, green: 0.153, blue: 0.165) : Color.white
    }
    
    var filteredWorkouts: [Workout] {
        switch filterType {
        case .category:
            if selectedCategory == "All" { return workouts }
            return workouts.filter { $0.category == selectedCategory }
            
        case .exercise:
            if selectedExercise == "All" { return workouts }
            
            return workouts.filter { w in
                w.exercises?.contains(where: { entry in
                    let nameMatch = entry.name == selectedExercise
                    let repMatch = checkRepMatch(reps: entry.reps)
                    return nameMatch && repMatch
                }) ?? false
            }
        }
    }
    
    func checkRepMatch(reps: Int?) -> Bool {
        guard let filter = selectedReps else { return true }
        let entryReps = reps ?? 0
        
        if filter == 20 {
            return entryReps >= 20
        } else {
            return entryReps == filter
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Filter Controls
            VStack(spacing: 16) {
                // Segmented Control
                HStack(spacing: 0) {
                    ForEach(FilterType.allCases, id: \.self) { type in
                        Button(action: {
                            withAnimation(.snappy) { filterType = type }
                        }) {
                            Text(type.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(filterType == type ? .white : .primary)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background {
                                    if filterType == type {
                                        Capsule()
                                            .fill(Color.blue)
                                            .matchedGeometryEffect(id: "activeTab", in: animation)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(Color(uiColor: .systemGray6))
                .clipShape(Capsule())
                .padding(.horizontal)
                
                // Primary Filter Row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        switch filterType {
                        case .category:
                            FilterChip(title: "All", isSelected: selectedCategory == "All") { selectedCategory = "All" }
                            ForEach(WorkoutCategories.allCases, id: \.self) { cat in
                                FilterChip(title: cat.rawValue, isSelected: selectedCategory == cat.rawValue) {
                                    selectedCategory = cat.rawValue
                                }
                            }
                            
                        case .exercise:
                            if cachedUniqueExercises.isEmpty {
                                Text("No exercises logged yet").font(.caption).foregroundColor(.secondary)
                            } else {
                                ForEach(cachedUniqueExercises, id: \.self) { ex in
                                    FilterChip(title: ex, isSelected: selectedExercise == ex) {
                                        selectedExercise = ex
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Secondary Filter Row (Reps)
                if filterType == .exercise && selectedExercise != "All" {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All Reps", isSelected: selectedReps == nil) { selectedReps = nil }
                            ForEach(1...20, id: \.self) { i in
                                let title = i == 20 ? "20+" : "\(i)"
                                FilterChip(title: title, isSelected: selectedReps == i) { selectedReps = i }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.vertical, 16)
            .background(cardBackgroundColor)
            
            // MARK: - Results List
            List {
                if filterType == .exercise && selectedExercise == "All" {
                    VStack(spacing: 12) {
                        Image(systemName: "dumbbell.fill").font(.largeTitle).foregroundColor(.secondary)
                        Text("Select an exercise").font(.headline)
                        Text("Choose an exercise from the top bar to view its history.").font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
                    .listRowBackground(Color.clear)
                }
                else if filteredWorkouts.isEmpty {
                    Text("No matching workouts found.")
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    if filterType == .exercise {
                        ForEach(filteredWorkouts) { workout in
                            let relevantEntries = (workout.exercises ?? []).filter { entry in
                                entry.name == selectedExercise && checkRepMatch(reps: entry.reps)
                            }
                            
                            if !relevantEntries.isEmpty {
                                Section(header:
                                    VStack(alignment: .trailing, spacing: 4) {
                                        HStack {
                                            Text(workout.date, format: .dateTime.weekday().day().month().year())
                                                .font(.headline).foregroundColor(.primary)
                                            Spacer()
                                            Text(workout.category)
                                                .font(.caption2).fontWeight(.bold)
                                                .padding(.horizontal, 8).padding(.vertical, 4)
                                                .background(Color.blue.opacity(0.1))
                                                .foregroundColor(.blue).cornerRadius(6)
                                        }
                                        if !workout.note.isEmpty {
                                            Text(workout.note).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.trailing)
                                        }
                                    }.padding(.bottom, 4)
                                ) {
                                    VStack(spacing: 0) {
                                        ForEach(relevantEntries) { entry in
                                            ExerciseHistoryRow(entry: entry, profile: profile)
                                                .padding(.vertical, 8)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        ForEach(filteredWorkouts) { workout in
                            NavigationLink(destination: destinationFor(workout)) {
                                WorkoutHistoryRow(workout: workout)
                            }
                        }
                        .onDelete(perform: deleteWorkout)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .background(appBackgroundColor)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        // Load exercises in background
        .onAppear { updateUniqueExercises() }
        .onChange(of: workouts) { updateUniqueExercises() }
    }
    
    @ViewBuilder
    func destinationFor(_ workout: Workout) -> some View {
        WorkoutDetailView(workout: workout, profile: profile)
    }
    
    private func updateUniqueExercises() {
        Task(priority: .background) {
            let names = Set(workouts.flatMap { $0.exercises ?? [] }.map { $0.name })
            let sorted = Array(names).sorted()
            await MainActor.run {
                self.cachedUniqueExercises = sorted
            }
        }
    }
    
    private func deleteWorkout(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let workoutToDelete = filteredWorkouts[index]
                modelContext.delete(workoutToDelete)
            }
        }
    }
}

// ... (Helper Views FilterChip, ExerciseHistoryRow, WorkoutHistoryRow remain unchanged) ...
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.subheadline).fontWeight(isSelected ? .bold : .regular)
                .padding(.vertical, 6).padding(.horizontal, 12)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.15))
                .foregroundColor(isSelected ? .white : .primary).cornerRadius(20)
        }.buttonStyle(.plain)
    }
}

struct ExerciseHistoryRow: View {
    let entry: ExerciseEntry
    let profile: UserProfile
    var body: some View {
        HStack {
            if entry.isCardio {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill").font(.caption).foregroundColor(.red)
                    if let dist = entry.distance, dist > 0 {
                        Text("\(dist.toUserDistance(system: profile.unitSystem), specifier: "%.2f") \(profile.unitSystem == UnitSystem.imperial.rawValue ? "mi" : "km")")
                    }
                    if let dur = entry.duration, dur > 0 { Text("\(Int(dur)) min") }
                }
            } else {
                HStack(spacing: 4) {
                    Text("\(entry.reps ?? 0)").bold()
                    Text("reps").foregroundColor(.secondary).font(.caption)
                    Text("x").foregroundColor(.secondary).font(.caption)
                    Text("\(entry.weight?.toUserWeight(system: profile.unitSystem) ?? 0, specifier: "%.1f")").bold()
                    Text(profile.unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg").foregroundColor(.secondary).font(.caption)
                }
            }
            Spacer()
            if !entry.note.isEmpty { Image(systemName: "note.text").foregroundColor(.secondary) }
        }.padding(.vertical, 2)
    }
}

struct WorkoutHistoryRow: View {
    let workout: Workout
    var body: some View {
        let exercises = workout.exercises ?? []
        let uniqueNames = exercises.map { $0.name }.reduce(into: [String]()) { (result, name) in
            if !result.contains(name) { result.append(name) }
        }
        let uniqueCount = uniqueNames.count
        let totalSets = exercises.count
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.date, format: .dateTime.day().month().year()).font(.body).bold()
                Text(workout.category).font(.caption).foregroundColor(.blue)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(uniqueCount) exercises, \(totalSets) sets").font(.caption).foregroundColor(.secondary)
                if !exercises.isEmpty {
                    Text(workout.muscleGroups.joined(separator: ", ")).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                } else {
                    Text("No exercises").font(.caption2).foregroundColor(.secondary)
                }
            }
        }.padding(.vertical, 4)
    }
}
