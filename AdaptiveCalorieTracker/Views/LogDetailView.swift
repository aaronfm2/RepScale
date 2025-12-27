import SwiftUI
import SwiftData

struct LogDetailView: View {
    let log: DailyLog
    let workouts: [Workout]
    
    @AppStorage("enableCaloriesBurned") private var enableCaloriesBurned: Bool = true
    
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
                nutritionSection
                workoutsSection
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("Daily Summary")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Subviews
    
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
            Text("Nutrition").font(.headline)
            
            HStack(spacing: 20) {
                MacroCard(title: "Protein", value: log.protein, color: .red)
                MacroCard(title: "Carbs", value: log.carbs, color: .blue)
                MacroCard(title: "Fats", value: log.fat, color: .yellow)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Calories Consumed")
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
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
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
                    Text(w.category)
                        .font(.title3).bold()
                        .foregroundColor(.blue)
                    Text(w.muscleGroups.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "dumbbell.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue.opacity(0.2))
            }
            .padding(.bottom, 5)
            
            Divider()
            
            if w.exercises.isEmpty {
                Text("No exercises logged.")
                    .font(.caption).italic().foregroundColor(.secondary)
            } else {
                let grouped = groupExercises(w.exercises)
                ForEach(grouped, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.top, 4)
                        
                        ForEach(Array(group.sets.enumerated()), id: \.element) { index, exercise in
                            exerciseRow(for: exercise, setNumber: index + 1)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
            
            if !w.note.isEmpty {
                Divider()
                Text("Note: \(w.note)")
                    .font(.caption).italic().foregroundColor(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.05)))
        .padding(.horizontal)
    }
    
    private func exerciseRow(for exercise: ExerciseEntry, setNumber: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Set \(setNumber)")
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
                        .font(.callout).monospacedDigit()
                }
                
                Spacer()
            }
            
            // --- CHANGED: Display note text here ---
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

struct MacroCard: View {
    let title: String
    let value: Int?
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            if let v = value {
                Text("\(v)g")
                    .font(.headline)
            } else {
                Text("-")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
