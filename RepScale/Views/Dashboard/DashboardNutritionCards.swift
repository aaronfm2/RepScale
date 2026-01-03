import SwiftUI
import SwiftData
import Charts

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
    
    var color: Color {
        switch self {
        case .calories: return .orange
        case .protein: return .blue
        case .carbs: return .green
        case .fat: return .red
        }
    }
}

struct MonthlyNutritionData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

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
            // 1. Header Section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nutrition History")
                        .font(.headline)
                    Text("Monthly Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Reorder Buttons
                HStack(spacing: 4) {
                    if index > 0 {
                        Button(action: onMoveUp) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.secondary.opacity(0.3))
                        }
                    }
                    if index < totalCount - 1 {
                        Button(action: onMoveDown) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.secondary.opacity(0.3))
                        }
                    }
                }
            }
            
            // 2. Controls: Metric Picker and Year Picker
            HStack {
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(NutritionMetric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Year", selection: $selectedYear) {
                    ForEach(availableYears, id: \.self) { year in
                        Text(String(year).replacingOccurrences(of: ",", with: ""))
                            .tag(year)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
            
            // 3. Chart & Stats Section
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
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    // Show all 12 months on the axis
                    AxisMarks(values: .stride(by: .month)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.month(.abbreviated))
                            }
                        }
                    }
                }
                // Ensure chart domain covers Jan-Dec
                .chartXScale(domain: dateRange(for: selectedYear))
                .frame(height: 220)
                
                // 4. Footer Stats
                HStack(spacing: 20) {
                    // Current Average (Latest non-zero month)
                    if let lastWithData = data.last(where: { $0.value > 0 }) {
                        VStack(alignment: .leading) {
                            Text("Current Average")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(lastWithData.value)) \(selectedMetric.unit)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(selectedMetric.color)
                        }
                    }
                    
                    Spacer()
                    
                    // Year to Date Average
                    if ytdAverage > 0 {
                        VStack(alignment: .trailing) {
                            Text("Year to Date Avg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(ytdAverage)) \(selectedMetric.unit)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(selectedMetric.color)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        // --- CARD STYLING ---
        .padding() // 1. Add internal padding
        .background(Color(uiColor: .secondarySystemGroupedBackground)) // 2. Add the "Box" background
        .cornerRadius(16) // 3. Round the corners
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2) // 4. Subtle shadow (optional, matches original)
        // --------------------
        .onAppear {
            if !availableYears.contains(selectedYear) {
                selectedYear = availableYears.last ?? Calendar.current.component(.year, from: Date())
            }
        }
    }
    
    // MARK: - Helpers
    
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        guard let firstLog = logs.first, let lastLog = logs.last else {
            return [currentYear]
        }
        
        let startYear = Calendar.current.component(.year, from: firstLog.date)
        let endYear = Calendar.current.component(.year, from: lastLog.date)
        
        let minYear = min(startYear, endYear)
        let maxYear = max(startYear, endYear)
        let finalMax = max(maxYear, currentYear)
        
        return Array(minYear...finalMax)
    }
    
    private func dateRange(for year: Int) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let startComponents = DateComponents(year: year, month: 1, day: 1)
        let endComponents = DateComponents(year: year, month: 12, day: 31)
        
        let start = calendar.date(from: startComponents) ?? Date()
        let end = calendar.date(from: endComponents) ?? Date()
        
        return start...end
    }
    
    private func calculateMonthlyAverages(for year: Int) -> [MonthlyNutritionData] {
        let calendar = Calendar.current
        var results: [MonthlyNutritionData] = []
        
        for month in 1...12 {
            let components = DateComponents(year: year, month: month)
            guard let date = calendar.date(from: components) else { continue }
            
            let monthLogs = logs.filter { log in
                let logComponents = calendar.dateComponents([.year, .month], from: log.date)
                return logComponents.year == year && logComponents.month == month
            }
            
            if monthLogs.isEmpty {
                results.append(MonthlyNutritionData(date: date, value: 0))
                continue
            }
            
            let totalValue = sumValues(for: monthLogs)
            let validLogCount = countValidLogs(in: monthLogs)
            
            let average = validLogCount > 0 ? totalValue / Double(validLogCount) : 0
            results.append(MonthlyNutritionData(date: date, value: average))
        }
        
        return results.sorted { $0.date < $1.date }
    }
    
    private func calculateYearlyAverage(for year: Int) -> Double {
        let calendar = Calendar.current
        let yearLogs = logs.filter { log in
            let logYear = calendar.component(.year, from: log.date)
            return logYear == year
        }
        
        let totalValue = sumValues(for: yearLogs)
        let validLogCount = countValidLogs(in: yearLogs)
        
        return validLogCount > 0 ? totalValue / Double(validLogCount) : 0.0
    }
    
    private func sumValues(for logs: [DailyLog]) -> Double {
        logs.reduce(0) { sum, log in
            switch selectedMetric {
            case .calories: return sum + Double(log.caloriesConsumed)
            case .protein: return sum + Double(log.protein ?? 0)
            case .carbs: return sum + Double(log.carbs ?? 0)
            case .fat: return sum + Double(log.fat ?? 0)
            }
        }
    }
    
    private func countValidLogs(in logs: [DailyLog]) -> Int {
        logs.filter { log in
            switch selectedMetric {
            case .calories: return log.caloriesConsumed > 0
            case .protein: return (log.protein ?? 0) > 0
            case .carbs: return (log.carbs ?? 0) > 0
            case .fat: return (log.fat ?? 0) > 0
            }
        }.count
    }
}
