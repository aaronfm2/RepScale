import Foundation
import SwiftData
import SwiftUI

/// Centralized manager for SwiftData operations to ensure data consistency.
/// Usage: Initialize with a ModelContext, usually from a View or ViewModel.
@MainActor
class DataManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Weight Operations
    
    /// Adds a weight entry and ensures the DailyLog is synced correctly.
    func addWeightEntry(date: Date, weight: Double, goalType: String, note: String = "") {
        let entry = WeightEntry(date: date, weight: weight, note: note)
        modelContext.insert(entry)
        syncWeightToLog(date: date, weight: weight, goalType: goalType)
    }
    
    /// Updates an existing weight entry and re-syncs logs if date or weight changes.
    func updateWeightEntry(_ entry: WeightEntry, newDate: Date, newWeight: Double, newNote: String, goalType: String) {
        let oldDate = entry.date
        
        // 1. Update Properties
        entry.date = newDate
        entry.weight = newWeight
        entry.note = newNote
        
        // 2. Handle Log Sync
        if !Calendar.current.isDate(oldDate, inSameDayAs: newDate) {
            // Date changed: Repair the OLD day's log (it might need to revert to a previous weight)
            updateLogAfterWeightDeletion(date: oldDate)
            
            // Sync the NEW day's log
            syncWeightToLog(date: newDate, weight: newWeight, goalType: goalType)
        } else {
            // Same day: Just sync this day
            syncWeightToLog(date: newDate, weight: newWeight, goalType: goalType)
        }
    }
    
    /// Deletes a weight entry and repairs the DailyLog to reflect the change.
    func deleteWeightEntry(_ entry: WeightEntry) {
        let date = entry.date
        modelContext.delete(entry)
        updateLogAfterWeightDeletion(date: date)
    }
    
    // MARK: - Internal Sync Logic
    
    private func syncWeightToLog(date: Date, weight: Double, goalType: String) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == normalizedDate }
        )
        
        do {
            if let existingLog = try modelContext.fetch(descriptor).first {
                existingLog.weight = weight
                if existingLog.goalType == nil {
                    existingLog.goalType = goalType
                }
            } else {
                let newLog = DailyLog(date: normalizedDate, weight: weight, goalType: goalType)
                modelContext.insert(newLog)
            }
        } catch {
            print("DataManager: Failed to sync weight to daily log: \(error)")
        }
    }
    
    private func updateLogAfterWeightDeletion(date: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        
        // Fetch all REMAINING weights for this day
        let start = normalizedDate
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let remainingWeights = try modelContext.fetch(descriptor)
            
            // Fetch the DailyLog
            let logDescriptor = FetchDescriptor<DailyLog>(
                predicate: #Predicate { $0.date == normalizedDate }
            )
            
            if let log = try modelContext.fetch(logDescriptor).first {
                if let latest = remainingWeights.first {
                    // If there are still weights left, use the latest one
                    log.weight = latest.weight
                } else {
                    // No weights left for this day -> Clear the log's weight
                    log.weight = nil
                }
            }
        } catch {
            print("DataManager: Failed to update log after deletion: \(error)")
        }
    }
    
    // MARK: - Goal Period Management
        
    func startNewGoalPeriod(goalType: String, startWeight: Double, targetWeight: Double, dailyCalorieGoal: Int, maintenanceCalories: Int) {
        let now = Date()
        let descriptor = FetchDescriptor<GoalPeriod>(predicate: #Predicate { $0.endDate == nil })
        
        do {
            let activePeriods = try modelContext.fetch(descriptor)
            for period in activePeriods { period.endDate = now }
        } catch {
            print("DataManager: Failed to fetch active goal periods: \(error)")
        }
        
        let newPeriod = GoalPeriod(
            startDate: now,
            goalType: goalType,
            startWeight: startWeight,
            targetWeight: targetWeight,
            dailyCalorieGoal: dailyCalorieGoal,
            maintenanceCalories: maintenanceCalories
        )
        modelContext.insert(newPeriod)
    }
}
