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
    func addWeightEntry(date: Date, weight: Double, goalType: String) {
        // 1. Create and Insert the Weight Entry
        let entry = WeightEntry(date: date, weight: weight)
        modelContext.insert(entry)
        
        // 2. Sync to Daily Log
        syncWeightToLog(date: date, weight: weight, goalType: goalType)
    }
    
    /// Deletes a weight entry and repairs the DailyLog to reflect the change.
    func deleteWeightEntry(_ entry: WeightEntry) {
        let date = entry.date
        
        // 1. Delete the entry
        modelContext.delete(entry)
        
        // 2. Repair the DailyLog
        // We need to find if there are ANY other weights for this day.
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
                // Backfill goal type if missing
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
        
        // 1. Fetch all REMAINING weights for this day
        // Note: We cannot use #Predicate with complex date logic easily in SwiftData sometimes,
        // but fetching all and filtering is safe for small datasets.
        // A more performant way is to construct a range predicate if needed.
        let start = normalizedDate
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let remainingWeights = try modelContext.fetch(descriptor)
            
            // 2. Fetch the DailyLog
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
}
