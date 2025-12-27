import Foundation
import SwiftUI

// Struct to package all the settings needed for calculation
struct DashboardSettings {
    var dailyGoal: Int
    var targetWeight: Double
    var goalType: String
    var maintenanceCalories: Int
    var estimationMethod: Int
    var enableCaloriesBurned: Bool
}

// Struct for the graph
struct ProjectionPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
    let method: String
}

@Observable
class DashboardViewModel {
    // MARK: - Output State (Read by the View)
    var daysRemaining: Int?
    var estimatedMaintenance: Int?
    var projectionPoints: [ProjectionPoint] = []
    
    // UI Helper Text
    var logicDescription: String = ""
    var progressWarningMessage: String = ""
    
    // MARK: - Primary Calculation Function
    func updateMetrics(logs: [DailyLog], weights: [WeightEntry], settings: DashboardSettings) {
        updateLogicDescription(method: settings.estimationMethod)
        
        // 1. Calculate Maintenance
        self.estimatedMaintenance = calculateEstimatedMaintenance(logs: logs, weights: weights)
        
        // 2. Calculate Days Remaining
        self.daysRemaining = calculateDaysRemaining(
            weights: weights,
            logs: logs,
            settings: settings
        )
        updateWarningMessage(settings: settings, hasDaysEstimate: daysRemaining != nil)
        
        // 3. Generate Projections
        self.projectionPoints = generateProjections(
            startWeight: weights.first?.weight ?? 0,
            weights: weights,
            logs: logs,
            settings: settings
        )
    }
    
    // MARK: - Internal Logic
    
    private func updateLogicDescription(method: Int) {
        switch method {
        case 0: logicDescription = "Based on 30-day weight trend"
        case 1: logicDescription = "Based on 7-day average intake"
        case 2: logicDescription = "Based on maintenance vs daily goal"
        default: logicDescription = ""
        }
    }
    
    private func updateWarningMessage(settings: DashboardSettings, hasDaysEstimate: Bool) {
        if hasDaysEstimate {
            progressWarningMessage = ""
            return
        }
        
        switch settings.estimationMethod {
        case 0: // Weight Trend
            progressWarningMessage = "Need more weight data over 30 days, or trend is moving away from goal."
        case 1: // Avg Intake
            progressWarningMessage = settings.goalType == GoalType.cutting.rawValue
                ? "Eat less than maintenance on average to see estimate"
                : "Eat more than maintenance on average to see estimate"
        case 2: // Fixed Target
            progressWarningMessage = settings.goalType == GoalType.cutting.rawValue
                ? "Your daily goal must be lower than your maintenance (\(settings.maintenanceCalories))"
                : "Your daily goal must be higher than your maintenance (\(settings.maintenanceCalories))"
        default:
            progressWarningMessage = ""
        }
    }

    private func calculateEstimatedMaintenance(logs: [DailyLog], weights: [WeightEntry]) -> Int? {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        
        // Sort Oldest -> Newest for calculation
        let recentWeights = weights.filter { $0.date >= thirtyDaysAgo }.sorted { $0.date < $1.date }
        
        guard let first = recentWeights.first, let last = recentWeights.last, first.id != last.id else {
            return nil
        }
        
        let start = Calendar.current.startOfDay(for: first.date)
        let end = Calendar.current.startOfDay(for: last.date)
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        
        guard days > 0 else { return nil }
        
        let weightChange = last.weight - first.weight
        let today = Calendar.current.startOfDay(for: Date())
        
        // Relevant logs strictly before today
        let relevantLogs = logs.filter { $0.date >= first.date && $0.date <= last.date && $0.date < today }
        guard !relevantLogs.isEmpty else { return nil }
        
        let totalConsumed = relevantLogs.reduce(0) { $0 + $1.caloriesConsumed }
        let avgDailyIntake = Double(totalConsumed) / Double(relevantLogs.count)
        
        // Energy Imbalance (7700 kcal approx 1kg fat)
        let dailyImbalance = (weightChange * 7700.0) / Double(days)
        
        return Int(avgDailyIntake - dailyImbalance)
    }

    private func calculateKgChangePerDay(method: Int, weights: [WeightEntry], logs: [DailyLog], maintenanceCalories: Int, dailyGoal: Int) -> Double? {
        // Method 0: Weight Trend (Last 30 Days)
        if method == 0 {
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            let recentWeights = weights.filter { $0.date >= thirtyDaysAgo }.sorted { $0.date < $1.date }
            
            guard let first = recentWeights.first, let last = recentWeights.last, first.id != last.id else { return nil }
            
            let start = Calendar.current.startOfDay(for: first.date)
            let end = Calendar.current.startOfDay(for: last.date)
            let timeSpan = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
            
            if timeSpan > 0 {
                let weightChange = last.weight - first.weight
                return weightChange / Double(timeSpan)
            }
        }
        
        // Method 1: Avg Intake (User Maintenance - 7 Day Avg)
        if method == 1 {
            let today = Calendar.current.startOfDay(for: Date())
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
            
            let recentLogs = logs.filter { $0.date >= sevenDaysAgo && $0.date < today }
            
            if !recentLogs.isEmpty {
                let totalConsumed = recentLogs.reduce(0) { $0 + $1.caloriesConsumed }
                let avgConsumed = Double(totalConsumed) / Double(recentLogs.count)
                
                return (avgConsumed - Double(maintenanceCalories)) / 7700.0
            }
        }
        
        // Method 2: Fixed Target
        if method == 2 {
            return (Double(dailyGoal) - Double(maintenanceCalories)) / 7700.0
        }
        
        return nil
    }

    private func calculateDaysRemaining(weights: [WeightEntry], logs: [DailyLog], settings: DashboardSettings) -> Int? {
        guard let currentWeight = weights.first?.weight else { return nil }
        
        guard let kgPerDay = calculateKgChangePerDay(
            method: settings.estimationMethod,
            weights: weights,
            logs: logs,
            maintenanceCalories: settings.maintenanceCalories,
            dailyGoal: settings.dailyGoal
        ) else { return nil }
        
        if settings.goalType == GoalType.cutting.rawValue && kgPerDay >= 0 { return nil }
        if settings.goalType == GoalType.bulking.rawValue && kgPerDay <= 0 { return nil }
        
        let weightDiff = settings.targetWeight - currentWeight
        let days = weightDiff / kgPerDay
        
        return days > 0 ? Int(days) : nil
    }
    
    private func generateProjections(startWeight: Double, weights: [WeightEntry], logs: [DailyLog], settings: DashboardSettings) -> [ProjectionPoint] {
        var points: [ProjectionPoint] = []
        let today = Date()
        let comparisonMethods = [(0, "Trend (30d)"), (1, "Avg Intake (7d)"), (2, "Fixed Goal")]
        
        for (methodId, label) in comparisonMethods {
            if let rate = calculateKgChangePerDay(
                method: methodId,
                weights: weights,
                logs: logs,
                maintenanceCalories: settings.maintenanceCalories,
                dailyGoal: settings.dailyGoal
            ) {
                points.append(ProjectionPoint(date: today, weight: startWeight, method: label))
                for i in 1...60 {
                    let nextDate = Calendar.current.date(byAdding: .day, value: i, to: today)!
                    let projectedWeight = startWeight + (rate * Double(i))
                    points.append(ProjectionPoint(date: nextDate, weight: projectedWeight, method: label))
                }
            }
        }
        return points
    }
}
