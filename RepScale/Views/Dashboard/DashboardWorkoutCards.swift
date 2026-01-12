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
        // 1. Data Preparation: Get all unique exercise names
        let allExercises = Array(Set(workouts.flatMap { $0.exercises ?? [] }.map { $0.name })).sorted()
        
        // NEW: Calculate available reps for the currently selected exercise (All Time)
        // This ensures the menu only shows rep counts you have actually performed.
        let availableReps: [Int] = {
            let targetExercise = profile.strengthGraphExercise
            guard !targetExercise.isEmpty else { return [] }
            
            let allEntries = workouts.flatMap { $0.exercises ?? [] }
            let relevantEntries = allEntries.filter { $0.name == targetExercise }
            let uniqueReps = Set(relevantEntries.compactMap { $0.reps }.filter { $0 > 0 })
            
            return Array(uniqueReps).sorted()
        }()
        
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
                    
                    // UPDATED: Strict match. We only graph the exact rep count selected.
                    // (Legacy support: If user previously had '21' selected for 20+, they will need to select a new valid rep count from the menu).
                    if reps == profile.strengthGraphReps, let weight = entry.weight {
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
                                Button(name) {
                                    profile.strengthGraphExercise = name
                                    // Optional: Reset reps to the most common or first available when switching exercise?
                                    // For now, we leave it; if the rep count doesn't exist for the new exercise, the graph will be empty until they pick one.
                                }
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
                    
                    // UPDATED: Reps Selector
                    Menu {
                        if availableReps.isEmpty {
                            Text("No history")
                        } else {
                            ForEach(availableReps, id: \.self) { i in
                                Button("\(i) Reps") { profile.strengthGraphReps = i }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(profile.strengthGraphReps) Reps")
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
                    
                    if availableReps.isEmpty {
                        Text("Log this exercise to see data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if !availableReps.contains(profile.strengthGraphReps) {
                        Text("You haven't performed sets of \(profile.strengthGraphReps) reps for this exercise.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Try adjusting the time filter.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
// MARK: - Volume Tracker Card
struct VolumeTrackerCard: View {
    @Bindable var profile: UserProfile
    var workouts: [Workout]
    var index: Int
    var totalCount: Int
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    
    // Local state for filters (Could be moved to UserProfile for persistence)
    @State private var timeRange: TimeRange = .allTime
    @State private var filterType: FilterType = .workout
    @State private var selectedCategory: WorkoutCategories = .push
    @State private var selectedExercise: String = ""
    @State private var metric: VolumeMetric = .totalReps
    
    enum FilterType: String, CaseIterable {
        case workout = "Workout"
        case exercise = "Exercise"
    }
    
    enum VolumeMetric: String, CaseIterable {
        case volumeLoad = "Volume Load" // Weight * Reps
        case totalReps = "Total Reps"
        case totalSets = "Total Sets"
    }
    
    var body: some View {
        let allExercises = Array(Set(workouts.flatMap { $0.exercises ?? [] }.map { $0.name })).sorted()
        
        // Ensure valid exercise selection
        let currentExercise = selectedExercise.isEmpty ? (allExercises.first ?? "None") : selectedExercise
        
        // 1. Filter Workouts by Time
        let filteredWorkouts: [Workout]
        if let startDate = timeRange.startDate(from: Date()) {
            filteredWorkouts = workouts.filter { $0.date >= startDate }
        } else {
            filteredWorkouts = workouts
        }
        
        // 2. Prepare Data Points
        var graphData: [(date: Date, value: Double)] = []
        let groupedByDate = Dictionary(grouping: filteredWorkouts, by: { Calendar.current.startOfDay(for: $0.date) })
        
        for (date, dayWorkouts) in groupedByDate {
            var dailyTotal: Double = 0
            
            for workout in dayWorkouts {
                // Filter Logic
                var relevantExercises: [ExerciseEntry] = []
                
                if filterType == .workout {
                    // Match Workout Category
                    if workout.category == selectedCategory.rawValue {
                        relevantExercises = workout.exercises ?? []
                    }
                } else {
                    // Match Specific Exercise
                    relevantExercises = (workout.exercises ?? []).filter { $0.name == currentExercise }
                }
                
                // Metric Logic
                for entry in relevantExercises {
                    switch metric {
                    case .volumeLoad:
                        let weight = (entry.weight ?? 0).toUserWeight(system: profile.unitSystem)
                        let reps = Double(entry.reps ?? 0)
                        dailyTotal += (weight * reps)
                    case .totalReps:
                        dailyTotal += Double(entry.reps ?? 0)
                    case .totalSets:
                        dailyTotal += 1
                    }
                }
            }
            
            if dailyTotal > 0 {
                graphData.append((date: date, value: dailyTotal))
            }
        }
        
        graphData.sort { $0.date < $1.date }
        
        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Volume Tracker").font(.headline)
                Spacer()
                ReorderArrows(index: index, totalCount: totalCount, onUp: onMoveUp, onDown: onMoveDown)
            }
            
            // Filters Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Metric Selector
                    Menu {
                        ForEach(VolumeMetric.allCases, id: \.self) { m in
                            Button(m.rawValue) { metric = m }
                        }
                    } label: {
                        Label(metric.rawValue, systemImage: "chart.bar.fill")
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.purple.opacity(0.1), in: Capsule())
                            .foregroundColor(.purple)
                    }
                    
                    // Filter Type Selector
                    Menu {
                        ForEach(FilterType.allCases, id: \.self) { type in
                            Button("By \(type.rawValue)") { filterType = type }
                        }
                    } label: {
                        Text(filterType.rawValue)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1), in: Capsule())
                            .foregroundColor(.primary)
                    }
                    
                    // Context Specific Selector (Category or Exercise)
                    if filterType == .workout {
                        Menu {
                            ForEach(WorkoutCategories.allCases, id: \.self) { cat in
                                Button(cat.rawValue) { selectedCategory = cat }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedCategory.rawValue)
                                Image(systemName: "chevron.down")
                            }
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1), in: Capsule())
                            .foregroundColor(.blue)
                        }
                    } else {
                        Menu {
                            if allExercises.isEmpty {
                                Text("No Exercises")
                            } else {
                                ForEach(allExercises, id: \.self) { name in
                                    Button(name) { selectedExercise = name }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(currentExercise)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                            }
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1), in: Capsule())
                            .foregroundColor(.blue)
                        }
                    }
                    
                    // Time Range
                    Menu {
                        ForEach(TimeRange.allCases) { range in
                            Button(range.rawValue) { timeRange = range }
                        }
                    } label: {
                        Text(timeRange.rawValue)
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
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("No volume data found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            } else {
                Chart {
                    ForEach(graphData, id: \.date) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Volume", item.value)
                        )
                        .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .bottom, endPoint: .top))
                    }
                }
                .frame(height: 200)
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
        .onAppear {
            if selectedExercise.isEmpty, let first = allExercises.first {
                selectedExercise = first
            }
        }
    }
}
// MARK: RepTrackerCard
struct RepTrackerCard: View {
    @Bindable var profile: UserProfile
    var workouts: [Workout]
    var index: Int
    var totalCount: Int
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    
    var weightLabel: String { profile.unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    
    var body: some View {
        // 1. Get all unique exercise names
        let allExercises = Set(workouts.flatMap { $0.exercises ?? [] }.map { $0.name }).sorted()
        
        // 2. Get unique weights for the *selected* exercise (for the filter dropdown)
        let exerciseWeights = getUniqueWeights(for: profile.repGraphExercise)
        
        // 3. Prepare data (filtered by exercise AND weight)
        let data = getRepHistory()
        let allReps = data.map { $0.reps }
        let maxReps = (allReps.max() ?? 10) + 5
        
        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Rep Strength Tracker").font(.headline)
                Spacer()
                ReorderArrows(index: index, totalCount: totalCount, onUp: onMoveUp, onDown: onMoveDown)
            }
            
            // Filters Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 1. EXERCISE FILTER (Left)
                    Menu {
                        Picker("Exercise", selection: $profile.repGraphExercise) {
                            Text("Select Exercise").tag("")
                            ForEach(allExercises, id: \.self) { exercise in
                                Text(exercise).tag(exercise)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(profile.repGraphExercise.isEmpty ? "Select Exercise" : profile.repGraphExercise)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                        }
                        .font(.caption).fontWeight(.medium).foregroundColor(.blue)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                    }
                    
                    // 2. WEIGHT FILTER (Right of Exercise)
                    // Only show if an exercise is selected
                    if !profile.repGraphExercise.isEmpty {
                        Menu {
                            Picker("Weight", selection: $profile.repGraphWeight) {
                                Text("All Weights").tag(-1.0)
                                ForEach(exerciseWeights, id: \.self) { weight in
                                    Text("\(formatWeight(weight)) \(weightLabel)").tag(weight)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                // Show "All" or the specific weight
                                if profile.repGraphWeight == -1.0 {
                                    Text("All Weights")
                                } else {
                                    Text(formatWeight(profile.repGraphWeight))
                                }
                                Image(systemName: "chevron.down")
                            }
                            .font(.caption).fontWeight(.medium).foregroundColor(.green)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.green.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }
            
            // Chart Content
            if profile.repGraphExercise.isEmpty {
                Text("Select an exercise to track reps").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 180)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
            } else if data.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("No data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            } else {
                Chart {
                    ForEach(data) { point in
                        BarMark(
                            x: .value("Date", point.date),
                            y: .value("Reps", point.reps)
                        )
                        .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .bottom, endPoint: .top))
                        .cornerRadius(4)
                    }
                    
                    if let avg = calculateAverage(data) {
                        RuleMark(y: .value("Average", avg))
                            .foregroundStyle(.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Avg: \(Int(avg))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                            }
                    }
                }
                .frame(height: 180)
                .chartYScale(domain: 0...maxReps)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
        // Reset weight filter if exercise changes
        .onChange(of: profile.repGraphExercise) { _, _ in
            profile.repGraphWeight = -1.0
        }
    }
    
    // MARK: - Helpers
    
    private func formatWeight(_ weight: Double) -> String {
        let converted = weight.toUserWeight(system: profile.unitSystem)
        return String(format: "%.1f", converted)
    }
    
    private func getUniqueWeights(for exerciseName: String) -> [Double] {
        guard !exerciseName.isEmpty else { return [] }
        
        let allWeights = workouts
            .flatMap { $0.exercises ?? [] }
            .filter { $0.name == exerciseName }
            .compactMap { $0.weight }
        
        return Set(allWeights).sorted()
    }
    
    private func getRepHistory() -> [RepDataPoint] {
        guard !profile.repGraphExercise.isEmpty else { return [] }
        
        // Filter workouts that contain the selected exercise
        let relevantWorkouts = workouts.filter { workout in
            workout.exercises?.contains(where: { $0.name == profile.repGraphExercise }) ?? false
        }.sorted(by: { $0.date < $1.date })
        
        return relevantWorkouts.compactMap { workout -> RepDataPoint? in
            // 1. Get sets for the exercise
            var matchingSets = workout.exercises?.filter { $0.name == profile.repGraphExercise } ?? []
            
            // 2. Apply Weight Filter if not "All" (-1.0)
            if profile.repGraphWeight != -1.0 {
                matchingSets = matchingSets.filter { entry in
                    guard let w = entry.weight else { return false }
                    return abs(w - profile.repGraphWeight) < 0.01
                }
            }
            
            guard !matchingSets.isEmpty else { return nil }
            
            // 3. Sum reps
            let totalReps = matchingSets.reduce(0) { $0 + ($1.reps ?? 0) }
            
            guard totalReps > 0 else { return nil }
            return RepDataPoint(date: workout.date, reps: Double(totalReps))
        }
    }
    
    private func calculateAverage(_ data: [RepDataPoint]) -> Double? {
        guard !data.isEmpty else { return nil }
        let total = data.reduce(0) { $0 + $1.reps }
        return total / Double(data.count)
    }
}

// Ensure this struct is present in the file
struct RepDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let reps: Double
}
