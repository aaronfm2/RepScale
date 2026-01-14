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
    @State private var selectedTimeFrame: Int = 60
    @State private var showingMaintenanceSheet = false
    
    var weightLabel: String { profile.unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    
    var body: some View {
        let currentWeightKg = weights.first?.weight ?? 0
        let currentDisplay = currentWeightKg.toUserWeight(system: profile.unitSystem)
        let targetDisplay = profile.targetWeight.toUserWeight(system: profile.unitSystem)
        let toleranceDisplay = profile.maintenanceTolerance.toUserWeight(system: profile.unitSystem)
        
        // Calculate cutoff date
        let cutoffDate = Calendar.current.date(byAdding: .day, value: selectedTimeFrame, to: Date())!
        
        // Filter projections based on date AND drop values <= 0 so the line stops
        let projections = viewModel.projectionPoints
            .filter { $0.date <= cutoffDate }
            .compactMap { point -> ProjectionPoint? in
                let converted = point.weight.toUserWeight(system: profile.unitSystem)
                // If weight is <= 0, return nil to exclude it from the chart entirely
                guard converted > 0 else { return nil }
                return ProjectionPoint(date: point.date, weight: converted, method: point.method)
            }
        
        let allValues = projections.map { $0.weight } + [currentDisplay, targetDisplay]
        let lowerBound = max(0, (allValues.min() ?? 0) - 5)
        let upperBound = (allValues.max() ?? 100) + 5
        
        let methodColors: [EstimationMethod: Color] = [
            .weightTrend30Day: .blue,
            .weightTrend7Day: .cyan,
            .currentEatingHabits: .purple,
            .perfectGoalAdherence: .orange
        ]
        
        var baseMapping: [String: Color] = [:]
        for method in EstimationMethod.allCases { baseMapping[method.displayName] = methodColors[method] }
        
        // Get methods that actually have data in the projection list
        let availableMethodNames = Set(projections.map { $0.method })
        let activeKeys = EstimationMethod.allCases.map { $0.displayName }.filter { availableMethodNames.contains($0) }
        let activeColors = activeKeys.compactMap { baseMapping[$0] }
        
        return VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Projections (\(weightLabel))").font(.headline)
                    Text("Estimated weight over next \(selectedTimeFrame) days").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                
                // Configurable Timeframe Filter (Capsule Style)
                Menu {
                    ForEach([30, 60, 90, 180, 365], id: \.self) { days in
                        Button(action: { selectedTimeFrame = days }) {
                            Label("\(days) Days", systemImage: selectedTimeFrame == days ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(selectedTimeFrame) Days")
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption).fontWeight(.medium).foregroundColor(.blue)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1), in: Capsule())
                }
                
                // Maintenance Configuration Button
                Button(action: { showingMaintenanceSheet = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
                        .padding(6).background(Color.secondary.opacity(0.1)).clipShape(Circle())
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingMaintenanceSheet) {
                    MaintenanceSelectionSheet(
                        profile: profile,
                        formulaValue: calculateFormulaMaintenance(currentWeight: currentWeightKg),
                        appEstimate: viewModel.estimatedMaintenance
                    )
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
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month().day()) }
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
    }
    
    // Helper to calculate Formula (Mifflin-St Jeor) locally
    private func calculateFormulaMaintenance(currentWeight: Double) -> Int {
        let age = Double(profile.age)
        let height = profile.height // cm
        let activity = ActivityLevel(rawValue: profile.activityLevel) ?? .Active
        let isMale = (profile.gender == Gender.male.rawValue)
        
        let base: Double = (10 * currentWeight) + (6.25 * height) - (5 * age)
        let genderOffset: Double = isMale ? 5 : -161
        let bmr = base + genderOffset
        
        return Int(bmr * activity.multiplier)
    }
}

// MARK: - Maintenance Selection Sheet

struct MaintenanceSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var profile: UserProfile
    
    let formulaValue: Int
    let appEstimate: Int?
    
    @State private var manualValue: Int
    @State private var isManual: Bool
    
    // Track focus & Keyboard State
    @FocusState private var isInputFocused: Bool
    @State private var isKeyboardVisible = false
    
    init(profile: UserProfile, formulaValue: Int, appEstimate: Int?) {
        self.profile = profile
        self.formulaValue = formulaValue
        self.appEstimate = appEstimate
        
        let current = profile.maintenanceCalories
        
        // Initial state logic
        _manualValue = State(initialValue: current)
        
        if current == formulaValue {
            _isManual = State(initialValue: false)
        } else if let app = appEstimate, current == app {
            _isManual = State(initialValue: false)
        } else {
            _isManual = State(initialValue: true)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    Section {
                        // Formula Option
                        Button {
                            apply(val: formulaValue, manual: false)
                        } label: {
                            row(title: "Formula Estimate",
                                subtitle: "Based on your height, weight, age and activity level using the Mifflin-St Jeor forumla",
                                value: formulaValue,
                                isSelected: !isManual && profile.maintenanceCalories == formulaValue)
                        }
                        .tint(.primary)
                        
                        // App Estimate Option
                        if let app = appEstimate {
                            Button {
                                apply(val: app, manual: false)
                            } label: {
                                row(title: "App Estimate",
                                    subtitle: "Derived from your 30-day log history",
                                    value: app,
                                    isSelected: !isManual && profile.maintenanceCalories == app)
                            }
                            .tint(.primary)
                        }
                        
                        // Manual Option
                        HStack {
                            // Tapping the Label/VStack selects Manual
                            VStack(alignment: .leading) {
                                Text("Manual")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text("Set your own fixed value")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle()) // Makes the whole text area tappable
                            .onTapGesture {
                                selectManual()
                            }
                            
                            Spacer()
                            
                            TextField("kcal", value: $manualValue, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .focused($isInputFocused)
                                .frame(width: 90)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                // Updates when value changes (typing)
                                .onChange(of: manualValue) { _, newVal in
                                    isManual = true
                                    profile.maintenanceCalories = newVal
                                }
                            
                            if isManual {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 2)
                        // Watch focus state: if user taps box, select manual immediately
                        .onChange(of: isInputFocused) { _, focused in
                            if focused {
                                selectManual()
                            }
                        }
                    } header: {
                        Text("Calorie Source")
                    }
                    
                    // Spacer for Keyboard
                    Section {
                        Color.clear.frame(height: 80)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // MARK: - Custom Keyboard Toolbar
                VStack {
                    Spacer()
                    if isKeyboardVisible {
                        VStack(spacing: 0) {
                            Divider()
                            HStack {
                                Spacer()
                                Button("Done") {
                                    hideKeyboard()
                                }
                                .bold()
                                .tint(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .background(.bar)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("Maintenance Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Main Sheet Done Button
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            // MARK: - Keyboard Observers
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isKeyboardVisible = true
                    }
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isKeyboardVisible = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .fraction(0.5)])
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func selectManual() {
        withAnimation {
            isManual = true
            profile.maintenanceCalories = manualValue
        }
    }
    
    private func row(title: String, subtitle: String, value: Int, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(value)")
                .fontWeight(.medium)
            Text("kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if isSelected {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                    .padding(.leading, 8)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func apply(val: Int, manual: Bool) {
        withAnimation {
            isInputFocused = false // dismiss keyboard if switching
            isManual = manual
            profile.maintenanceCalories = val
        }
    }
}

// MARK: - Other Cards

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
