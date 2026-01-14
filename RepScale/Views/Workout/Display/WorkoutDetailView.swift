import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout
    var profile: UserProfile // Injected
    
    // Optional filter: If set, only exercises targeting this muscle will be shown
    var filterMuscle: String? = nil
    
    @State private var isEditing = false
    @Query private var exerciseDefs: [ExerciseDefinition]

    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }

    var cardBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.153, green: 0.153, blue: 0.165) : Color.white
    }

    var weightLabel: String { profile.unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    var distLabel: String { profile.unitSystem == UnitSystem.imperial.rawValue ? "mi" : "km" }

    // Helper to group exercises by name while keeping order
    var groupedExercises: [(name: String, sets: [ExerciseEntry])] {
        var groups: [(name: String, sets: [ExerciseEntry])] = []
        
        // FIX: Sort exercises by the persisted sortOrder before processing
        // This ensures the view respects the order you saved, instead of random database order.
        let sortedExercises = (workout.exercises ?? []).sorted { $0.sortOrder < $1.sortOrder }
        
        // Filter exercises first if a muscle filter is active
        let relevantExercises = sortedExercises.filter { entry in
            guard let targetMuscle = filterMuscle else { return true }
            
            // Find definition for this exercise to check muscle groups
            if let def = exerciseDefs.first(where: { $0.name == entry.name }) {
                return def.muscleGroups.contains(targetMuscle)
            }
            // If definition not found (custom exercise?), defaulting to show or hide?
            // Hiding is safer for "Show Back exercises"
            return false
        }
        
        for exercise in relevantExercises {
            if let last = groups.last, last.name == exercise.name {
                groups[groups.count - 1].sets.append(exercise)
            } else {
                groups.append((name: exercise.name, sets: [exercise]))
            }
        }
        return groups
    }

    var body: some View {
        List {
            Section("Summary") {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(workout.date, format: .dateTime.day().month().year())
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Category")
                    Spacer()
                    Text(workout.category)
                        .padding(4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
                HStack {
                    Text("Muscles")
                    Spacer()
                    if let filter = filterMuscle {
                        // Highlight the filtered muscle
                        Text(filter)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    } else {
                        Text(workout.muscleGroups.joined(separator: ", "))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listRowBackground(cardBackgroundColor)
            
            Section("Exercises\(filterMuscle != nil ? " (\(filterMuscle!))" : "")") {
                if groupedExercises.isEmpty {
                    Text("No \(filterMuscle ?? "") exercises found in this workout.")
                        .italic().foregroundColor(.secondary)
                } else {
                    ForEach(groupedExercises, id: \.name) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.vertical, 4)
                            
                            ForEach(Array(group.sets.enumerated()), id: \.element) { index, exercise in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Set \(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 40, alignment: .leading)
                                        
                                        Divider()
                                            .frame(height: 15)
                                        
                                        if exercise.isCardio {
                                            HStack(spacing: 8) {
                                                if let dist = exercise.distance, dist > 0 {
                                                    Text("\(dist.toUserDistance(system: profile.unitSystem), specifier: "%.2f") \(distLabel)")
                                                }
                                                if let time = exercise.duration, time > 0 {
                                                    Text("\(Int(time)) min")
                                                }
                                            }
                                            .font(.callout).monospacedDigit().foregroundColor(.blue)
                                        } else {
                                            let displayWeight = (exercise.weight ?? 0.0).toUserWeight(system: profile.unitSystem)
                                            
                                            // MODIFIED: Swapped order to display Weight first, then Reps
                                            Text("\(displayWeight, specifier: "%.1f") \(weightLabel) x \(exercise.reps ?? 0)")
                                                .monospacedDigit()
                                        }
                                        
                                        Spacer()
                                    }
                                    
                                    if !exercise.note.isEmpty {
                                        Text(exercise.note)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 50)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listRowBackground(cardBackgroundColor)
            
            if !workout.note.isEmpty {
                Section("Notes") {
                    Text(workout.note)
                }
                .listRowBackground(cardBackgroundColor)
            }
        }
        .scrollContentBackground(.hidden)
        .background(appBackgroundColor)
        .navigationTitle(workout.category)
        .toolbar {
            Button("Edit") {
                isEditing = true
            }
        }
        .sheet(isPresented: $isEditing) {
            AddWorkoutView(workoutToEdit: workout, profile: profile)
        }
    }
}
