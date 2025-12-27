import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @State private var isEditing = false
    
    // Helper to group exercises by name while keeping order
    var groupedExercises: [(name: String, sets: [ExerciseEntry])] {
        var groups: [(name: String, sets: [ExerciseEntry])] = []
        for exercise in workout.exercises {
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
                    Text(workout.muscleGroups.joined(separator: ", "))
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Exercises") {
                if workout.exercises.isEmpty {
                    Text("No exercises logged").italic().foregroundColor(.secondary)
                } else {
                    // Iterate over the GROUPS
                    ForEach(groupedExercises, id: \.name) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            // Parent Header
                            Text(group.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.vertical, 4)
                            
                            // Child Rows (Sets)
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
                                                    Text("\(dist, specifier: "%.2f") km")
                                                }
                                                if let time = exercise.duration, time > 0 {
                                                    Text("\(Int(time)) min")
                                                }
                                            }
                                            .font(.callout).monospacedDigit().foregroundColor(.blue)
                                        } else {
                                            Text("\(exercise.reps ?? 0) x \(exercise.weight ?? 0.0, specifier: "%.1f") kg")
                                                .monospacedDigit()
                                        }
                                        
                                        Spacer()
                                    }
                                    
                                    // --- CHANGED: Display note text here ---
                                    if !exercise.note.isEmpty {
                                        Text(exercise.note)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 50) // Indent to align with details
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            if !workout.note.isEmpty {
                Section("Notes") {
                    Text(workout.note)
                }
            }
        }
        .navigationTitle(workout.category)
        .toolbar {
            Button("Edit") {
                isEditing = true
            }
        }
        .sheet(isPresented: $isEditing) {
            AddWorkoutView(workoutToEdit: workout)
        }
    }
}
