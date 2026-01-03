import SwiftUI
import SwiftData
import Charts

struct WorkoutDistributionCard: View {
    @Bindable var profile: UserProfile
    var workouts: [Workout]
    var index: Int
    var totalCount: Int
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    
    var workoutTimeRange: TimeRange {
        get { TimeRange(rawValue: profile.workoutTimeRange) ?? .thirtyDays }
        nonmutating set { profile.workoutTimeRange = newValue.rawValue }
    }
    
    var body: some View {
        let filteredWorkouts: [Workout]
        if let startDate = workoutTimeRange.startDate(from: Date()) {
            filteredWorkouts = workouts.filter { $0.date >= startDate }
        } else {
            filteredWorkouts = workouts
        }
        
        let counts = Dictionary(grouping: filteredWorkouts, by: { $0.category }).mapValues { $0.count }
        let data = counts.sorted(by: { $0.value > $1.value }).map { (cat: $0.key, count: $0.value) }

        return VStack(alignment: .leading) {
            HStack {
                Text("Workout Focus").font(.headline)
                Spacer()
                Menu {
                    ForEach(TimeRange.allCases) { range in
                        Button(action: { profile.workoutTimeRange = range.rawValue }) {
                            Label(range.rawValue, systemImage: workoutTimeRange == range ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) { Text(workoutTimeRange.rawValue); Image(systemName: "chevron.down") }
                        .font(.caption).fontWeight(.medium).foregroundColor(.blue)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.1), in: Capsule())
                }
                ReorderArrows(index: index, totalCount: totalCount, onUp: onMoveUp, onDown: onMoveDown)
            }
            .padding(.bottom, 4)
            
            if data.isEmpty {
                Text("No workouts logged in this period.").font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center).padding()
            } else {
                HStack(spacing: 20) {
                    Chart(data, id: \.cat) { item in
                        SectorMark(angle: .value("Count", item.count), innerRadius: .ratio(0.6), angularInset: 2)
                            .cornerRadius(5).foregroundStyle(byCategoryColor(item.cat))
                    }.frame(height: 150).frame(maxWidth: 150)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(data, id: \.cat) { item in
                            HStack {
                                Circle().fill(byCategoryColor(item.cat)).frame(width: 8, height: 8)
                                Text(item.cat).font(.caption).foregroundColor(.primary)
                                Spacer()
                                Text("\(item.count)").font(.caption).bold().foregroundColor(.secondary)
                            }
                        }
                    }.frame(maxWidth: .infinity)
                }
            }
        }.padding().background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private func byCategoryColor(_ cat: String) -> Color {
        switch cat.lowercased() {
        case "push": return .red; case "pull": return .blue; case "legs": return .green; case "cardio": return .orange
        case "full body": return .purple; case "upper": return .teal; case "lower": return .brown; default: return .gray
        }
    }
}

struct WeeklyGoalCard: View {
    @Bindable var profile: UserProfile
    var viewModel: DashboardViewModel
    var index: Int
    var totalCount: Int
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    
    @State private var showingGoalEdit = false
    
    var body: some View {
        let progress = viewModel.weeklyProgress ?? WeeklyProgress(completedCount: 0, totalGoal: 3, percentage: 0, activeWeekdays: [])
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: Date())
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Completed Workout Days")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingGoalEdit = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(.trailing, 8)
                
                ReorderArrows(index: index, totalCount: totalCount, onUp: onMoveUp, onDown: onMoveDown)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Completed \(progress.completedCount) of \(progress.totalGoal) days this week")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(progress.percentage * 100))%")
                        .bold().foregroundColor(.secondary)
                }
                .font(.subheadline)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.2)).frame(height: 8)
                        Capsule().fill(Color.blue)
                            .frame(width: max(geo.size.width * progress.percentage, 0), height: 8)
                            .animation(.spring, value: progress.percentage)
                    }
                }
                .frame(height: 8)
            }
            
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let weekdayIndex = (i + 1) % 7 + 1
                    let isToday = (weekdayIndex == todayWeekday)
                    let hasWorkout = progress.activeWeekdays.contains(weekdayIndex)
                    
                    VStack {
                        ZStack {
                            Circle().fill(hasWorkout ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                            if isToday { Circle().stroke(Color.green, lineWidth: 2) }
                            Text(days[i]).font(.caption).fontWeight(.bold)
                                .foregroundColor(hasWorkout ? .blue : .secondary)
                        }
                        .frame(height: 35)
                        
                        if hasWorkout {
                            Circle().fill(Color.blue).frame(width: 4, height: 4)
                        } else {
                            Circle().fill(Color.clear).frame(width: 4, height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
        .sheet(isPresented: $showingGoalEdit) {
            WeeklyGoalEditSheet(goal: $profile.weeklyWorkoutGoal)
        }
    }
}

struct StrengthTrackerCard: View {
    @Bindable var profile: UserProfile
    var workouts: [Workout]
    var index: Int
    var totalCount: Int
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    
    var strengthTimeRange: TimeRange {
        get { TimeRange(rawValue: profile.strengthGraphTimeRange) ?? .ninetyDays }
        nonmutating set { profile.strengthGraphTimeRange = newValue.rawValue }
    }
    
    var body: some View {
        // 1. Data Preparation
        let allExercises = Array(Set(workouts.flatMap { $0.exercises ?? [] }.map { $0.name })).sorted()
        
        // Filter Workouts by Time Range
        let filteredWorkouts: [Workout]
        if let startDate = strengthTimeRange.startDate(from: Date()) {
            filteredWorkouts = workouts.filter { $0.date >= startDate }
        } else {
            filteredWorkouts = workouts
        }
        
        // 2. Extract Data Points: (Date, MaxWeight)
        var graphData: [(date: Date, weight: Double)] = []
        let groupedByDate = Dictionary(grouping: filteredWorkouts, by: { Calendar.current.startOfDay(for: $0.date) })
        
        for (date, daysWorkouts) in groupedByDate {
            var maxWeightForDay: Double = 0
            var found = false
            
            for workout in daysWorkouts {
                guard let exercises = workout.exercises else { continue }
                for entry in exercises where entry.name == profile.strengthGraphExercise {
                    let reps = entry.reps ?? 0
                    let matchesReps: Bool
                    if profile.strengthGraphReps == 21 {
                        matchesReps = reps >= 20
                    } else {
                        matchesReps = reps == profile.strengthGraphReps
                    }
                    
                    if matchesReps, let weight = entry.weight {
                        let converted = weight.toUserWeight(system: profile.unitSystem)
                        if converted > maxWeightForDay {
                            maxWeightForDay = converted
                            found = true
                        }
                    }
                }
            }
            if found {
                graphData.append((date: date, weight: maxWeightForDay))
            }
        }
        
        graphData.sort { $0.date < $1.date }
        
        let weightsList = graphData.map { $0.weight }
        let lowerBound = max(0, (weightsList.min() ?? 0) - 10)
        let upperBound = (weightsList.max() ?? 100) + 10
        
        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Strength Tracker").font(.headline)
                Spacer()
                ReorderArrows(index: index, totalCount: totalCount, onUp: onMoveUp, onDown: onMoveDown)
            }
            
            // Filters Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Exercise Selector
                    Menu {
                        if allExercises.isEmpty {
                            Text("No exercises logged")
                        } else {
                            ForEach(allExercises, id: \.self) { name in
                                Button(name) { profile.strengthGraphExercise = name }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(profile.strengthGraphExercise.isEmpty ? "Select Exercise" : profile.strengthGraphExercise)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                        }
                        .font(.caption).fontWeight(.medium)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                        .foregroundColor(.blue)
                    }
                    
                    // Reps Selector
                    Menu {
                        ForEach(1...20, id: \.self) { i in
                            Button("\(i) Reps") { profile.strengthGraphReps = i }
                        }
                        Button("20+ Reps") { profile.strengthGraphReps = 21 }
                    } label: {
                        HStack(spacing: 4) {
                            Text(profile.strengthGraphReps == 21 ? "20+ Reps" : "\(profile.strengthGraphReps) Reps")
                            Image(systemName: "chevron.down")
                        }
                        .font(.caption).fontWeight(.medium)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.green.opacity(0.1), in: Capsule())
                        .foregroundColor(.green)
                    }
                    
                    // Time Range Selector
                    Menu {
                        ForEach(TimeRange.allCases) { range in
                            Button(range.rawValue) { profile.strengthGraphTimeRange = range.rawValue }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(strengthTimeRange.rawValue)
                            Image(systemName: "chevron.down")
                        }
                        .font(.caption).fontWeight(.medium)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1), in: Capsule())
                        .foregroundColor(.orange)
                    }
                }
            }
            
            // Chart
            if graphData.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("No data found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Try adjusting the filters or log this exercise.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            } else {
                Chart {
                    ForEach(graphData, id: \.date) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Weight", item.weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        .symbol {
                            Circle().fill(.blue).frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                    }
                }
                .frame(height: 220)
                .chartYScale(domain: lowerBound...upperBound)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
}

// Re-include the edit sheet here if it was local to DashboardView
struct WeeklyGoalEditSheet: View {
    @Binding var goal: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Goal: \(goal) days", value: $goal, in: 1...7)
                } footer: {
                    Text("Set your target for the number of days you want to work out each week.")
                }
            }
            .navigationTitle("Weekly Goal")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
        .presentationDetents([.height(200)])
    }
}
