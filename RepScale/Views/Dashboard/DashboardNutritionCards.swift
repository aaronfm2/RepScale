import SwiftUI
import SwiftData
import Charts

// MARK: - Enums & Models

enum NutritionMetric: String, CaseIterable, Identifiable {
    case calories = "Calories"
    case protein = "Protein"
    case carbs = "Carbs"
    case fat = "Fat"
    
    var id: String { rawValue }
    
    var unit: String {
        switch self {
        case .calories: return "kcal"
        case .protein, .carbs, .fat: return "g"
        }
    }
    
    // Requested Palette: Red (Protein), Blue (Carbs), Yellow (Fat)
    var color: Color {
        switch self {
        case .calories:
            return .orange
        case .protein:
            return .red
        case .carbs:
            return .blue
        case .fat:
            return Color(red: 0.95, green: 0.75, blue: 0.1) // Golden Yellow
        }
    }
}

struct MonthlyNutritionData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct MacroData: Identifiable {
    let id = UUID()
    let name: String
    let value: Double // Average Grams
    let color: Color
    
    var percentage: Double // 0.0 - 1.0
}

// MARK: - Cards

struct NutritionHistoryCard: View {
    var profile: UserProfile
    var index: Int
    var totalCount: Int
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    
    @Query(sort: \DailyLog.date, order: .forward) private var logs: [DailyLog]
    @State private var selectedMetric: NutritionMetric = .calories
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nutrition History")
                        .font(.headline)
                    Text("Monthly Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ReorderArrows(index: index, totalCount: totalCount, onUp: onMoveUp, onDown: onMoveDown)
            }
            
            // Controls
            HStack(spacing: 12) {
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(NutritionMetric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                
                // Styled Year Filter
                Menu {
                    ForEach(availableYears, id: \.self) { year in
                        Button {
                            selectedYear = year
                        } label: {
                            Label(String(year).replacingOccurrences(of: ",", with: ""), systemImage: selectedYear == year ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(String(selectedYear).replacingOccurrences(of: ",", with: ""))
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
                    .foregroundStyle(.primary)
                }
            }
            
            // Chart
            let data = calculateMonthlyAverages(for: selectedYear)
            let ytdAverage = calculateYearlyAverage(for: selectedYear)
            
            if data.isEmpty {
                 ContentUnavailableView("No Data", systemImage: "chart.bar.xaxis", description: Text("Log your nutrition to see monthly trends."))
                    .frame(height: 200)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Month", item.date, unit: .month),
                        y: .value(selectedMetric.rawValue, item.value)
                    )
                    .foregroundStyle(selectedMetric.color.gradient)
                    .cornerRadius(4)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel { Text(date, format: .dateTime.month(.abbreviated)) }
                        }
                    }
                }
                .chartXScale(domain: dateRange(for: selectedYear))
                .frame(height: 220)
                
                // Footer Stats
                HStack(spacing: 20) {
                    if let lastWithData = data.last(where: { $0.value > 0 }) {
                        statView(title: "Current Average", value: lastWithData.value, unit: selectedMetric.unit, color: selectedMetric.color)
                    }
                    Spacer()
                    if ytdAverage > 0 {
                        statView(title: "Year to Date Avg", value: ytdAverage, unit: selectedMetric.unit, color: selectedMetric.color, alignment: .trailing)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
        .onAppear {
            if !availableYears.contains(selectedYear) {
                selectedYear = availableYears.last ?? Calendar.current.component(.year, from: Date())
            }
        }
    }
    
    private func statView(title: String, value: Double, unit: String, color: Color, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(Int(value)) \(unit)")
                .font(.subheadline).fontWeight(.bold).foregroundStyle(color)
        }
    }
    
    // Logic Helpers
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        guard let firstLog = logs.first, let lastLog = logs.last else { return [currentYear] }
        return Array(Calendar.current.component(.year, from: firstLog.date)...max(Calendar.current.component(.year, from: lastLog.date), currentYear))
    }
    
    private func dateRange(for year: Int) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let end = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? Date()
        return start...end
    }
    
    private func calculateMonthlyAverages(for year: Int) -> [MonthlyNutritionData] {
        let calendar = Calendar.current
        var results: [MonthlyNutritionData] = []
        
        for month in 1...12 {
            let components = DateComponents(year: year, month: month)
            guard let date = calendar.date(from: components) else { continue }
            
            let monthLogs = logs.filter {
                let c = calendar.dateComponents([.year, .month], from: $0.date)
                return c.year == year && c.month == month
            }
            
            if monthLogs.isEmpty {
                results.append(MonthlyNutritionData(date: date, value: 0))
                continue
            }
            
            let total = monthLogs.reduce(0.0) { sum, log in
                switch selectedMetric {
                case .calories: return sum + Double(log.caloriesConsumed)
                case .protein: return sum + Double(log.protein ?? 0)
                case .carbs: return sum + Double(log.carbs ?? 0)
                case .fat: return sum + Double(log.fat ?? 0)
                }
            }
            
            let count = monthLogs.filter {
                switch selectedMetric {
                case .calories: return $0.caloriesConsumed > 0
                case .protein: return ($0.protein ?? 0) > 0
                case .carbs: return ($0.carbs ?? 0) > 0
                case .fat: return ($0.fat ?? 0) > 0
                }
            }.count
            
            results.append(MonthlyNutritionData(date: date, value: count > 0 ? total / Double(count) : 0))
        }
        return results.sorted { $0.date < $1.date }
    }
    
    private func calculateYearlyAverage(for year: Int) -> Double {
        let calendar = Calendar.current
        let yearLogs = logs.filter { calendar.component(.year, from: $0.date) == year }
        
        let total = yearLogs.reduce(0.0) { sum, log in
            switch selectedMetric {
            case .calories: return sum + Double(log.caloriesConsumed)
            case .protein: return sum + Double(log.protein ?? 0)
            case .carbs: return sum + Double(log.carbs ?? 0)
            case .fat: return sum + Double(log.fat ?? 0)
            }
        }
        
        let count = yearLogs.filter {
            switch selectedMetric {
            case .calories: return $0.caloriesConsumed > 0
            case .protein: return ($0.protein ?? 0) > 0
            case .carbs: return ($0.carbs ?? 0) > 0
            case .fat: return ($0.fat ?? 0) > 0
            }
        }.count
        
        return count > 0 ? total / Double(count) : 0
    }
}

struct MacrosDistributionCard: View {
    var profile: UserProfile
    var index: Int
    var totalCount: Int
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    
    @Query(sort: \DailyLog.date, order: .forward) private var logs: [DailyLog]
    
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Macro Distribution")
                        .font(.headline)
                    Text("Average Grams & Percentage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ReorderArrows(index: index, totalCount: totalCount, onUp: onMoveUp, onDown: onMoveDown)
            }
            
            // Clean Capsule Filters
            HStack(spacing: 12) {
                // Month Selector
                Menu {
                    ForEach(1...12, id: \.self) { month in
                        Button {
                            selectedMonth = month
                        } label: {
                            Label(Calendar.current.monthSymbols[month - 1], systemImage: selectedMonth == month ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Calendar.current.monthSymbols[selectedMonth - 1])
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
                    .foregroundStyle(.primary)
                }
                
                // Year Selector
                Menu {
                    ForEach(availableYears, id: \.self) { year in
                        Button {
                            selectedYear = year
                        } label: {
                            Label(String(year).replacingOccurrences(of: ",", with: ""), systemImage: selectedYear == year ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(String(selectedYear).replacingOccurrences(of: ",", with: ""))
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
                    .foregroundStyle(.primary)
                }
                
                Spacer()
            }
            
            // Content
            let data = calculateMacroDistribution()
            
            if data.total > 0 {
                HStack(spacing: 20) {
                    // Pie Chart
                    Chart(data.segments) { segment in
                        SectorMark(
                            angle: .value("Grams", segment.value),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .cornerRadius(4)
                        .foregroundStyle(segment.color)
                    }
                    .frame(height: 180)
                    .aspectRatio(1, contentMode: .fit)
                    
                    // Legend / Stats
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(data.segments) { segment in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(segment.color)
                                    .frame(width: 8, height: 8)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(segment.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 4) {
                                        Text("\(Int(segment.value))g")
                                            .fontWeight(.bold)
                                        Text("(\(Int(segment.percentage * 100))%)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView("No Data", systemImage: "chart.pie", description: Text("No macro data for this period."))
                    .frame(height: 180)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
        .onAppear {
            if !availableYears.contains(selectedYear) {
                selectedYear = availableYears.last ?? Calendar.current.component(.year, from: Date())
            }
        }
    }
    
    // MARK: - Calculation Helpers
    
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        guard let firstLog = logs.first, let lastLog = logs.last else { return [currentYear] }
        return Array(Calendar.current.component(.year, from: firstLog.date)...max(Calendar.current.component(.year, from: lastLog.date), currentYear))
    }
    
    private func calculateMacroDistribution() -> (segments: [MacroData], total: Double) {
        let calendar = Calendar.current
        
        let filteredLogs = logs.filter {
            let c = calendar.dateComponents([.year, .month], from: $0.date)
            return c.year == selectedYear && c.month == selectedMonth
        }
        
        guard !filteredLogs.isEmpty else { return ([], 0) }
        
        // Sum totals
        let totalProtein = filteredLogs.reduce(0.0) { $0 + Double($1.protein ?? 0) }
        let totalCarbs = filteredLogs.reduce(0.0) { $0 + Double($1.carbs ?? 0) }
        let totalFat = filteredLogs.reduce(0.0) { $0 + Double($1.fat ?? 0) }
        
        // Calculate Count of valid days for each metric to calculate true average
        let proteinCount = filteredLogs.filter { ($0.protein ?? 0) > 0 }.count
        let carbsCount = filteredLogs.filter { ($0.carbs ?? 0) > 0 }.count
        let fatCount = filteredLogs.filter { ($0.fat ?? 0) > 0 }.count
        
        let avgProtein = proteinCount > 0 ? totalProtein / Double(proteinCount) : 0
        let avgCarbs = carbsCount > 0 ? totalCarbs / Double(carbsCount) : 0
        let avgFat = fatCount > 0 ? totalFat / Double(fatCount) : 0
        
        let totalMass = avgProtein + avgCarbs + avgFat
        
        guard totalMass > 0 else { return ([], 0) }
        
        let segments = [
            MacroData(name: "Protein", value: avgProtein, color: NutritionMetric.protein.color, percentage: avgProtein / totalMass),
            MacroData(name: "Carbs", value: avgCarbs, color: NutritionMetric.carbs.color, percentage: avgCarbs / totalMass),
            MacroData(name: "Fat", value: avgFat, color: NutritionMetric.fat.color, percentage: avgFat / totalMass)
        ]
        
        return (segments, totalMass)
    }
}
