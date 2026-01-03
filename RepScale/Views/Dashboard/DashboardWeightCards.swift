import SwiftUI
import SwiftData
import Charts

struct ProjectionComparisonCard: View {
    @Bindable var profile: UserProfile
    var viewModel: DashboardViewModel
    var weights: [WeightEntry]
    
    // Layout props
    var index: Int
    var totalCount: Int
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    
    // Internal State
    @State private var visibleMethods: Set<String> = []
    
    var weightLabel: String { profile.unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    
    var body: some View {
        let currentWeightKg = weights.first?.weight ?? 0
        let currentDisplay = currentWeightKg.toUserWeight(system: profile.unitSystem)
        let targetDisplay = profile.targetWeight.toUserWeight(system: profile.unitSystem)
        let toleranceDisplay = profile.maintenanceTolerance.toUserWeight(system: profile.unitSystem)
        
        // Filter projections
        let projections = viewModel.projectionPoints.filter { visibleMethods.contains($0.method) }
            .map { ProjectionPoint(date: $0.date, weight: $0.weight.toUserWeight(system: profile.unitSystem), method: $0.method) }
        
        let allValues = projections.map { $0.weight } + [currentDisplay, targetDisplay]
        let lowerBound = max(0, (allValues.min() ?? 0) - 5)
        let upperBound = (allValues.max() ?? 100) + 5
        
        let methodColors: [EstimationMethod: Color] = [.weightTrend30Day: .blue, .currentEatingHabits: .purple, .perfectGoalAdherence: .orange]
        var baseMapping: [String: Color] = [:]
        for method in EstimationMethod.allCases { baseMapping[method.displayName] = methodColors[method] }
        
        let activeKeys = EstimationMethod.allCases.map { $0.displayName }.filter { visibleMethods.contains($0) }
        let activeColors = activeKeys.compactMap { baseMapping[$0] }
        
        return VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Projections (\(weightLabel))").font(.headline)
                    Text("Estimated weight over next 60 days").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Menu {
                    Text("Visible Projections")
                    ForEach(EstimationMethod.allCases) { method in
                        if profile.isCalorieCountingEnabled || method == .weightTrend30Day {
                            Toggle(method.displayName, isOn: bindingForMethod(method.displayName))
                        }
                    }
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.title3).foregroundStyle(.primary)
                        .padding(8).background(Color.gray.opacity(0.1)).clipShape(Circle())
                }
                ReorderArrows(index: index, totalCount: totalCount, onUp: onMoveUp, onDown: onMoveDown)
            }
            .padding(.bottom, 8)
            
            if currentWeightKg > 0 {
                Chart {
                    RuleMark(y: .value("Target", targetDisplay)).foregroundStyle(.green).lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .annotation(position: .top, alignment: .leading) { Text("Target").font(.caption).foregroundColor(.green) }
                    if profile.goalType == GoalType.maintenance.rawValue {
                        RuleMark(y: .value("Upper", targetDisplay + toleranceDisplay)).foregroundStyle(.green.opacity(0.3))
                        RuleMark(y: .value("Lower", targetDisplay - toleranceDisplay)).foregroundStyle(.green.opacity(0.3))
                    }
                    ForEach(projections) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Weight", point.weight))
                            .foregroundStyle(by: .value("Method", point.method))
                            .interpolationMethod(.catmullRom).lineStyle(StrokeStyle(lineWidth: 3))
                    }
                }
                .chartForegroundStyleScale(domain: activeKeys, range: activeColors)
                .chartLegend(.hidden)
                .frame(height: 250)
                .chartYScale(domain: lowerBound...upperBound)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 14)) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month().day()) }
                }
                if !activeKeys.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Projection Method").font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(activeKeys, id: \.self) { key in
                                HStack(spacing: 6) {
                                    Circle().fill(baseMapping[key] ?? .gray).frame(width: 8, height: 8)
                                    Text(key).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }.padding(.top, 10)
                }
            } else {
                Text("Log weight to see projections").frame(maxWidth: .infinity, alignment: .center).padding().font(.caption).foregroundColor(.secondary)
            }
        }
        .padding().background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
        .onAppear {
            if visibleMethods.isEmpty {
                 // Initialize default visible method
                 if let method = EstimationMethod(rawValue: profile.estimationMethod) {
                     visibleMethods = [method.displayName]
                 } else {
                     visibleMethods = [EstimationMethod.weightTrend30Day.displayName]
                 }
             }
        }
    }
    
    private func bindingForMethod(_ method: String) -> Binding<Bool> {
        Binding(get: { visibleMethods.contains(method) }, set: { if $0 { visibleMethods.insert(method) } else { visibleMethods.remove(method) } })
    }
}

struct WeightChangeCard: View {
    @Bindable var profile: UserProfile
    var viewModel: DashboardViewModel
    var index: Int
    var totalCount: Int
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    
    var weightLabel: String { profile.unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weight Change").font(.headline)
                Spacer()
                ReorderArrows(index: index, totalCount: totalCount, onUp: onMoveUp, onDown: onMoveDown)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.weightChangeMetrics) { metric in
                    weightChangeCell(for: metric)
                }
            }
        }
        .padding().background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    private func weightChangeCell(for metric: WeightChangeMetric) -> some View {
        VStack(spacing: 6) {
            Text(metric.period).font(.caption).fontWeight(.medium).foregroundColor(.secondary)
            if let val = metric.value {
                let converted = val.toUserWeight(system: profile.unitSystem)
                HStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Text(val > 0 ? "+" : "")
                        Text("\(converted, specifier: "%.1f")")
                        Text(" \(weightLabel)")
                    }
                    .foregroundColor(.primary)
                    if val > 0 { Image(systemName: "arrow.up").foregroundColor(.green).font(.caption).bold() }
                    else if val < 0 { Image(systemName: "arrow.down").foregroundColor(.red).font(.caption).bold() }
                }
                .font(.title3).fontWeight(.bold)
            } else {
                Text("--").font(.title3).fontWeight(.bold).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
    }
}

struct WeightTrendCard: View {
    @Bindable var profile: UserProfile
    var weights: [WeightEntry]
    var index: Int
    var totalCount: Int
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    
    // Local Time Range computed property handling
    var weightHistoryTimeRange: TimeRange {
        get { TimeRange(rawValue: profile.weightHistoryTimeRange) ?? .thirtyDays }
        nonmutating set { profile.weightHistoryTimeRange = newValue.rawValue }
    }
    
    var weightLabel: String { profile.unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }

    var body: some View {
        let filteredWeights: [WeightEntry]
        if let startDate = weightHistoryTimeRange.startDate(from: Date()) {
            filteredWeights = weights.filter { $0.date >= startDate }
        } else {
            filteredWeights = weights
        }
        
        let history = filteredWeights.map { (date: $0.date, weight: $0.weight.toUserWeight(system: profile.unitSystem)) }
        let allWeights = history.map { $0.weight }
        let lowerBound = max(0, (allWeights.min() ?? 0) - 5)
        let upperBound = (allWeights.max() ?? 100) + 5
        
        return VStack(alignment: .leading) {
            HStack {
                Text("Weight History (\(weightLabel))").font(.headline)
                Spacer()
                Menu {
                    ForEach(TimeRange.allCases) { range in
                        Button(action: { profile.weightHistoryTimeRange = range.rawValue }) {
                            Label(range.rawValue, systemImage: weightHistoryTimeRange == range ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) { Text(weightHistoryTimeRange.rawValue); Image(systemName: "chevron.down") }
                        .font(.caption).fontWeight(.medium).foregroundColor(.blue)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.1), in: Capsule())
                }
                ReorderArrows(index: index, totalCount: totalCount, onUp: onMoveUp, onDown: onMoveDown)
            }
            .padding(.bottom, 4)
            
            if filteredWeights.isEmpty {
                Text("No weight data available for this period.").font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center).padding()
            } else {
                Chart {
                    ForEach(history.sorted(by: { $0.date < $1.date }), id: \.date) { item in
                        AreaMark(x: .value("Date", item.date), yStart: .value("Base", lowerBound), yEnd: .value("Weight", item.weight))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .blue.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Date", item.date), y: .value("Weight", item.weight))
                            .interpolationMethod(.catmullRom).foregroundStyle(.blue)
                            .symbol { Circle().fill(.blue).frame(width: 6, height: 6) }
                    }
                }
                .frame(height: 180).chartYScale(domain: lowerBound...upperBound).chartXScale(domain: .automatic(includesZero: false))
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month().day()) } }
                .clipped()
            }
        }.padding().background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
}
