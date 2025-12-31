import Foundation
import SwiftUI

struct DashboardSettings {
    var dailyGoal: Int
    var targetWeight: Double
    var goalType: String
    var maintenanceCalories: Int
    var estimationMethod: Int
    var enableCaloriesBurned: Bool
    var isCalorieCountingEnabled: Bool
}

struct ProjectionPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
    let method: String // Storing displayName here for Chart compatibility
}

struct WeightChangeMetric: Identifiable {
    let id = UUID()
    let period: String
    let value: Double?
}

@Observable
class DashboardViewModel {
    var daysRemaining: Int?
    var estimatedMaintenance: Int?
    var projectionPoints: [ProjectionPoint] = []
    var weightChangeMetrics: [WeightChangeMetric] = []
    
    var logicDescription: String = ""
    var progressWarningMessage: String = ""
    
    func updateMetrics(logs: [DailyLog], weights: [WeightEntry], settings: DashboardSettings) {
        
        let rawMethod = settings.isCalorieCountingEnabled ? settings.estimationMethod : 0
        // Convert raw Int to Enum, default to trend if invalid
        let effectiveMethod = EstimationMethod(rawValue: rawMethod) ?? .weightTrend30Day
        
        updateLogicDescription(method: effectiveMethod)
        
        if settings.isCalorieCountingEnabled {
            self.estimatedMaintenance = calculateEstimatedMaintenance(logs: logs, weights: weights)
        } else {
            self.estimatedMaintenance = nil
        }
        
        self.daysRemaining = calculateDaysRemaining(
            weights: weights,
            logs: logs,
            settings: settings,
            forcedMethod: effectiveMethod
        )
        updateWarningMessage(settings: settings, hasDaysEstimate: daysRemaining != nil, effectiveMethod: effectiveMethod)
        
        self.projectionPoints = generateProjections(
            startWeight: weights.first?.weight ?? 0,
            weights: weights,
            logs: logs,
            settings: settings
        )
        
        calculateWeightChanges(weights: weights)
    }
    
    private func calculateWeightChanges(weights: [WeightEntry]) {
        guard let latestEntry = weights.first else {
            self.weightChangeMetrics = []
            return
        }
        
        let currentWeight = latestEntry.weight
        let today = Date()
        var metrics: [WeightChangeMetric] = []
        
        let periods = [7, 30, 90]
        
        for days in periods {
            if let targetDate = Calendar.current.date(byAdding: .day, value: -days, to: today) {
                if let pastEntry = weights.first(where: { $0.date <= targetDate }) {
                    let diff = currentWeight - pastEntry.weight
                    metrics.append(WeightChangeMetric(period: "\(days) Days", value: diff))
                }
                else if let oldestEntry = weights.last {
                    let diff = currentWeight - oldestEntry.weight
                    metrics.append(WeightChangeMetric(period: "\(days) Days", value: diff))
                } else {
                    metrics.append(WeightChangeMetric(period: "\(days) Days", value: nil))
                }
            }
        }
        
        if let firstEntry = weights.last {
            let diff = currentWeight - firstEntry.weight
            metrics.append(WeightChangeMetric(period: "All Time", value: diff))
        } else {
            metrics.append(WeightChangeMetric(period: "All Time", value: nil))
        }
        
        self.weightChangeMetrics = metrics
    }
    
    private func updateLogicDescription(method: EstimationMethod) {
        switch method {
        case .weightTrend30Day: logicDescription = "Based on 30-day Weight Trend"
        case .currentEatingHabits: logicDescription = "Based on 7-day Average Calorie Intake"
        case .perfectGoalAdherence: logicDescription = "Based on Fixed Daily Calorie Amount"
        }
    }
    
    private func updateWarningMessage(settings: DashboardSettings, hasDaysEstimate: Bool, effectiveMethod: EstimationMethod) {
        if hasDaysEstimate {
            progressWarningMessage = ""
            return
        }
        
        switch effectiveMethod {
        case .weightTrend30Day:
            progressWarningMessage = "Need more weight data over 30 days, or trend weight is moving away from goal."
        case .currentEatingHabits:
            progressWarningMessage = settings.goalType == GoalType.cutting.rawValue
                ? "Eat less than maintenance on average to see estimate"
                : "Eat more than maintenance on average to see estimate"
        case .perfectGoalAdherence:
            progressWarningMessage = settings.goalType == GoalType.cutting.rawValue
                ? "Your daily goal must be lower than your maintenance (\(settings.maintenanceCalories))"
                : "Your daily goal must be higher than your maintenance (\(settings.maintenanceCalories))"
        }
    }

    private func calculateEstimatedMaintenance(logs: [DailyLog], weights: [WeightEntry]) -> Int? {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let recentWeights = weights.filter { $0.date >= thirtyDaysAgo }.sorted { $0.date < $1.date }
        
        guard let first = recentWeights.first, let last = recentWeights.last, first.id != last.id else { return nil }
        
        let start = Calendar.current.startOfDay(for: first.date)
        let end = Calendar.current.startOfDay(for: last.date)
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        guard days > 0 else { return nil }
        
        let weightChange = last.weight - first.weight
        let today = Calendar.current.startOfDay(for: Date())
        
        let relevantLogs = logs.filter {
            $0.date >= first.date &&
            $0.date <= last.date &&
            $0.date < today &&
            $0.caloriesConsumed > 0
        }
        
        guard !relevantLogs.isEmpty else { return nil }
        
        let totalConsumed = relevantLogs.reduce(0) { $0 + $1.caloriesConsumed }
        let avgDailyIntake = Double(totalConsumed) / Double(relevantLogs.count)
        let dailyImbalance = (weightChange * 7700.0) / Double(days)
        
        return Int(avgDailyIntake - dailyImbalance)
    }

    private func calculateKgChangePerDay(method: EstimationMethod, weights: [WeightEntry], logs: [DailyLog], maintenanceCalories: Int, dailyGoal: Int) -> Double? {
        if method == .weightTrend30Day {
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
        
        if method == .currentEatingHabits {
            let today = Calendar.current.startOfDay(for: Date())
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
            let recentLogs = logs.filter { $0.date >= sevenDaysAgo && $0.date < today }
            
            if !recentLogs.isEmpty {
                let totalConsumed = recentLogs.reduce(0) { $0 + $1.caloriesConsumed }
                let avgConsumed = Double(totalConsumed) / Double(recentLogs.count)
                return (avgConsumed - Double(maintenanceCalories)) / 7700.0
            }
        }
        
        if method == .perfectGoalAdherence {
            return (Double(dailyGoal) - Double(maintenanceCalories)) / 7700.0
        }
        
        return nil
    }

    private func calculateDaysRemaining(weights: [WeightEntry], logs: [DailyLog], settings: DashboardSettings, forcedMethod: EstimationMethod) -> Int? {
        guard let currentWeight = weights.first?.weight else { return nil }
        
        guard let kgPerDay = calculateKgChangePerDay(
            method: forcedMethod,
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
        
        // Filter methods if calorie counting is disabled
        let methodsToUse: [EstimationMethod] = settings.isCalorieCountingEnabled
            ? EstimationMethod.allCases
            : [.weightTrend30Day]
        
        for method in methodsToUse {
            if let rate = calculateKgChangePerDay(
                method: method,
                weights: weights,
                logs: logs,
                maintenanceCalories: settings.maintenanceCalories,
                dailyGoal: settings.dailyGoal
            ) {
                // Use .displayName so the Chart sees the string it expects
                let label = method.displayName
                
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
