import SwiftUI
import SwiftData
import Charts

struct WeightStatsView: View {
    // --- CLOUD SYNC: Injected Profile ---
    var profile: UserProfile

    @Environment(\.dismiss) var dismiss
    
    // NEW: Needed for deleting duplicates
    @Environment(\.modelContext) private var modelContext
    
    // FETCH GOAL PERIODS
    @Query(sort: \GoalPeriod.startDate, order: .reverse) private var rawPeriods: [GoalPeriod]
    
    // FETCH WEIGHTS (Used to find the true "Start Date" of tracking)
    @Query(sort: \WeightEntry.date, order: .forward) private var allWeights: [WeightEntry]
    
    var appBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(uiColor: .systemGroupedBackground)
    }
    
    var cardBackgroundColor: Color {
        profile.isDarkMode ? Color(red: 0.153, green: 0.153, blue: 0.165) : Color.white
    }
    
    // MARK: - 1. Clean Data Logic
    // Filters out "transient" periods (start & end on same day) unless it's the active one.
    // Also ensures only the MOST RECENT active period is counted.
    // NEW: Filters out periods that ended BEFORE the first weight entry (glitch/stale data).
    // MARK: - 1. Clean Data Logic
        // Filters out "transient" periods (start & end on same day) unless it's the active one.
        // Also ensures only the MOST RECENT active period is counted.
        // NEW: Filters out periods that ended BEFORE the first weight entry (glitch/stale data).
        var cleanedPeriods: [GoalPeriod] {
            var hasActive = false
            
            // Identify the earliest weight entry to use as a cutoff
            let firstWeightDate = allWeights.first?.date
            
            return rawPeriods.filter { period in
                // 1. Handle Active Periods (endDate is nil)
                if period.endDate == nil {
                    // If we've already found the most recent active period, treat subsequent ones as stale/invalid
                    if hasActive {
                        return false
                    }
                    hasActive = true
                    return true
                }
                
                // 2. Handle Closed Periods
                if let end = period.endDate {
                    // A. Stale Data Check:
                    // If this period ended BEFORE or ON THE SAME DAY as the first weight entry, it's likely a glitch/onboarding artifact.
                    if let firstDate = firstWeightDate {
                        let endDay = Calendar.current.startOfDay(for: end)
                        let firstDay = Calendar.current.startOfDay(for: firstDate)
                        
                        if endDay <= firstDay {
                            return false
                        }
                    }
                    
                    // B. Transient Check:
                    // Filter out periods that start and end on the same day
                    return !Calendar.current.isDate(period.startDate, inSameDayAs: end)
                }
                
                return true
            }
        }

    // MARK: - 2. Stats Logic
    var stats: [(type: String, days: Int, color: Color)] {
        var counts = [
            GoalType.cutting.rawValue: 0,
            GoalType.bulking.rawValue: 0,
            GoalType.maintenance.rawValue: 0
        ]
        
        let today = Date()
        
        // Use cleanedPeriods here to ensure stats match the filtered list
        for p in cleanedPeriods {
            let start = Calendar.current.startOfDay(for: p.startDate)
            let end = Calendar.current.startOfDay(for: p.endDate ?? today)
            let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
            let duration = max(1, days)
            
            counts[p.goalType, default: 0] += duration
        }
        
        return [
            (GoalType.cutting.rawValue, counts[GoalType.cutting.rawValue] ?? 0, .green),
            (GoalType.bulking.rawValue, counts[GoalType.bulking.rawValue] ?? 0, .red),
            (GoalType.maintenance.rawValue, counts[GoalType.maintenance.rawValue] ?? 0, .blue)
        ].filter { $0.1 > 0 }
    }

    var totalTrackedDays: Int {
        stats.reduce(0) { $0 + $1.days }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                   
                    // 1. Chart Section (Pie Chart)
                    if !stats.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Time Distribution")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart(stats, id: \.type) { item in
                                SectorMark(
                                    angle: .value("Days", item.days),
                                    innerRadius: .ratio(0.618),
                                    angularInset: 1.5
                                )
                                .cornerRadius(5)
                                .foregroundStyle(item.color)
                                .annotation(position: .overlay) {
                                    // Only show label if the slice is big enough (>10%)
                                    if Double(item.days) / Double(totalTrackedDays) > 0.1 {
                                        Text("\(item.days)d")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .frame(height: 200)
                            .padding(.vertical)
                            
                            // Legend
                            HStack {
                                ForEach(stats, id: \.type) { item in
                                    HStack(spacing: 4) {
                                        Circle().fill(item.color).frame(width: 8, height: 8)
                                        Text(item.type).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackgroundColor))
                    } else {
                        Text("No goal history yet.")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                   
                    // 2. Breakdown Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatBox(title: "Cutting", value: "\(getDays(for: .cutting))d", color: .green, bg: cardBackgroundColor)
                        StatBox(title: "Bulking", value: "\(getDays(for: .bulking))d", color: .red, bg: cardBackgroundColor)
                        StatBox(title: "Maintenance", value: "\(getDays(for: .maintenance))d", color: .blue, bg: cardBackgroundColor)
                    }
                   
                    // 3. History List (Using Cleaned Periods)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Phase History")
                            .font(.headline)
                        
                        ForEach(cleanedPeriods) { period in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(period.goalType)
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(getColor(for: period.goalType))
                                   
                                    Text("\(period.startDate, format: .dateTime.day().month().year()) - \(period.endDate?.formatted(.dateTime.day().month().year()) ?? "Now")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    let days = calculateDuration(period)
                                    Text("\(days) days")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                   
                                    if period.endDate == nil {
                                        Text("Active")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).fill(cardBackgroundColor))
                        }
                    }
                }
                .padding()
            }
            .background(appBackgroundColor)
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                cleanUpDuplicates()
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Scans for GoalPeriods that start on the same day and removes duplicates.
    /// Prioritizes keeping the currently active period.
    private func cleanUpDuplicates() {
        do {
            // 1. Group periods by their Start Date (ignoring time)
            let periods = try modelContext.fetch(FetchDescriptor<GoalPeriod>())
            let grouped = Dictionary(grouping: periods) { period in
                Calendar.current.startOfDay(for: period.startDate)
            }
            
            for (_, group) in grouped {
                // If we have more than 1 entry for the exact same day
                if group.count > 1 {
                    // 2. Determine which one to keep
                    // Sort so that:
                    // - Active periods (endDate == nil) come first
                    // - If both closed, maybe the one created last (implied by ID) or effectively random
                    let sortedGroup = group.sorted { p1, p2 in
                        if p1.endDate == nil { return true }  // Keep p1 if active
                        if p2.endDate == nil { return false } // Keep p2 if active
                        return false
                    }
                    
                    if let keeper = sortedGroup.first {
                        // 3. Delete the losers
                        for duplicate in group where duplicate.id != keeper.id {
                            modelContext.delete(duplicate)
                        }
                    }
                }
            }
        } catch {
            print("Failed to clean up duplicate periods: \(error)")
        }
    }
    
    func getDays(for type: GoalType) -> Int {
        stats.first(where: { $0.type == type.rawValue })?.days ?? 0
    }
    
    func getColor(for type: String) -> Color {
        if type == GoalType.cutting.rawValue { return .green }
        if type == GoalType.bulking.rawValue { return .red }
        return .blue
    }
    
    func calculateDuration(_ period: GoalPeriod) -> Int {
        let start = Calendar.current.startOfDay(for: period.startDate)
        let end = Calendar.current.startOfDay(for: period.endDate ?? Date())
        return max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    let bg: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(bg))
    }
}
