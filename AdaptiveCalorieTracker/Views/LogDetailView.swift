import SwiftUI
import SwiftData

struct LogDetailView: View {
    let log: DailyLog
    let workout: Workout? // Passed in from parent
    
    @AppStorage("enableCaloriesBurned") private var enableCaloriesBurned: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Date Header
                VStack(spacing: 5) {
                    Text(log.date, format: .dateTime.weekday(.wide).month().day())
                        .font(.title2).bold()
                    Text(log.date, format: .dateTime.year())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top)

                // 2. Nutrition / Macros Section
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
                        
                        // --- CONDITIONALLY SHOW BURNED ---
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

                // 3. Workout Section
                VStack(alignment: .leading, spacing: 15) {
                    Text("Workout").font(.headline).padding(.horizontal)
                    
                    if let w = workout {
                        VStack(alignment: .leading, spacing: 12) {
                            // Header: Category & Muscles
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
                            
                            // Exercise List
                            if w.exercises.isEmpty {
                                Text("No exercises logged.")
                                    .font(.caption).italic().foregroundColor(.secondary)
                            } else {
                                ForEach(w.exercises) { exercise in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(exercise.name).fontWeight(.medium)
                                            if !exercise.note.isEmpty {
                                                Text(exercise.note).font(.caption2).foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text("\(exercise.reps) x \(exercise.weight, specifier: "%.1f")kg")
                                            .font(.callout).monospacedDigit()
                                    }
                                    .padding(.vertical, 4)
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
                        
                    } else {
                        // Empty State
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
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("Daily Summary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Helper View for Macros
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
