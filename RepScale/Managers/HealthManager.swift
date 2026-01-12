import HealthKit
import SwiftUI

// Simple struct to hold display data
struct NutritionItem: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let unit: String
}

class HealthManager: ObservableObject {
    let healthStore = HKHealthStore()
    
    // Published properties to update the UI
    @Published var caloriesBurnedToday: Double = 0
    @Published var caloriesConsumedToday: Double = 0
    @Published var proteinToday: Double = 0
    @Published var carbsToday: Double = 0
    @Published var fatToday: Double = 0

    // MARK: - Nutrition Type Definitions
    
    // 1. BASIC TYPES: Requested immediately on Log Tab (Calories + Macros)
    private let basicDietaryTypes: [HKQuantityTypeIdentifier] = [
        .dietaryEnergyConsumed,
        .dietaryProtein,
        .dietaryCarbohydrates,
        .dietaryFatTotal
    ]
    
    // 2. EXTENDED TYPES: Requested only when "Show All" is tapped
    private let extendedDietaryTypes: [HKQuantityTypeIdentifier] = [
        .dietaryFatSaturated, .dietaryFatMonounsaturated, .dietaryFatPolyunsaturated,
        .dietaryCholesterol, .dietarySodium, .dietarySugar, .dietaryFiber,
        .dietaryVitaminA, .dietaryThiamin, .dietaryRiboflavin, .dietaryNiacin,
        .dietaryPantothenicAcid, .dietaryVitaminB6, .dietaryBiotin, .dietaryVitaminB12,
        .dietaryVitaminC, .dietaryVitaminD, .dietaryVitaminE, .dietaryVitaminK,
        .dietaryFolate, .dietaryCalcium, .dietaryChloride, .dietaryIron,
        .dietaryMagnesium, .dietaryPhosphorus, .dietaryPotassium, .dietaryZinc,
        .dietaryWater, .dietaryCaffeine
    ]
    
    // Combined helper for fetching data
    private var allDietaryTypes: [HKQuantityTypeIdentifier] {
        return basicDietaryTypes + extendedDietaryTypes
    }

    // MARK: - Authorization Methods

    /// Stage 1: Request Weight, Calories, and Macros ONLY.
    func requestBasicAuthorization() {
        // Core non-dietary types
        var typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!
        ]
        
        // Add only basic dietary types
        for id in basicDietaryTypes {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                typesToRead.insert(type)
            }
        }

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                self.fetchAllHealthData()
            }
        }
    }
    
    /// Stage 2: Request everything else (Vitamins, Minerals, etc.)
    /// Call this when the user taps "Show All Nutrition Data"
    func requestExtendedAuthorization(completion: @escaping (Bool) -> Void = { _ in }) {
        var typesToRead: Set<HKObjectType> = []
        
        for id in extendedDietaryTypes {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                typesToRead.insert(type)
            }
        }

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            // Refresh data regardless of success to ensure UI updates if they allowed it
            self.fetchAllHealthData()
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    func fetchAllHealthData() {
        fetchTodayCaloriesBurned()
        fetchNutrition()
    }

    func fetchTodayCaloriesBurned() {
        let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let predicate = getPredicate(for: Date())

        let query = HKStatisticsQuery(quantityType: caloriesType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else { return }
            
            let value = sum.doubleValue(for: HKUnit.kilocalorie())
            DispatchQueue.main.async {
                self.caloriesBurnedToday = value
            }
        }
        healthStore.execute(query)
    }
    
    // Fetch basic Nutrition for Dashboard (Calories + Macros)
    func fetchNutrition() {
        // Only fetch the basic types for the main dashboard/log view
        let nutritionTypes: [HKQuantityTypeIdentifier: (Double) -> Void] = [
            .dietaryEnergyConsumed: { val in self.caloriesConsumedToday = val },
            .dietaryProtein: { val in self.proteinToday = val },
            .dietaryCarbohydrates: { val in self.carbsToday = val },
            .dietaryFatTotal: { val in self.fatToday = val }
        ]
        
        for (identifier, updateBlock) in nutritionTypes {
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            let predicate = getPredicate(for: Date())
            
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else { return }
                
                // Calories uses kcal, Macros use grams
                let unit = (identifier == .dietaryEnergyConsumed) ? HKUnit.kilocalorie() : HKUnit.gram()
                let value = sum.doubleValue(for: unit)
                
                DispatchQueue.main.async {
                    updateBlock(value)
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Smart History Sync (Collection Query)

    /// Efficiently fetches daily totals for the last `days` count.
    /// Returns a dictionary keyed by Date (start of day) containing the values.
    func fetchSmartHistory(days: Int) async -> [Date: (burned: Double, consumed: Double, protein: Double, carbs: Double, fat: Double, weight: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return [:] }
        
        // We will fetch these 6 metrics in parallel
        return await withTaskGroup(of: (HKQuantityTypeIdentifier, [Date: Double]).self) { group in
            
            // 1. Define the metrics we want to history-sync
            let metrics: [(HKQuantityTypeIdentifier, HKUnit, HKStatisticsOptions)] = [
                (.activeEnergyBurned, .kilocalorie(), .cumulativeSum),
                (.dietaryEnergyConsumed, .kilocalorie(), .cumulativeSum),
                (.dietaryProtein, .gram(), .cumulativeSum),
                (.dietaryCarbohydrates, .gram(), .cumulativeSum),
                (.dietaryFatTotal, .gram(), .cumulativeSum),
                (.bodyMass, .gramUnit(with: .kilo), .discreteAverage) // Weight is average, not sum
            ]
            
            // 2. Launch a query for each metric
            for (id, unit, option) in metrics {
                group.addTask {
                    return (id, await self.performCollectionQuery(for: id, unit: unit, option: option, startDate: startDate))
                }
            }
            
            // 3. Consolidate results into a single dictionary by Date
            var consolidated: [Date: (burned: Double, consumed: Double, protein: Double, carbs: Double, fat: Double, weight: Double)] = [:]
            
            for await (id, results) in group {
                for (date, value) in results {
                    // Initialize tuple if missing
                    if consolidated[date] == nil {
                        consolidated[date] = (0, 0, 0, 0, 0, 0)
                    }
                    
                    // Map the value to the correct tuple field
                    switch id {
                    case .activeEnergyBurned: consolidated[date]?.burned = value
                    case .dietaryEnergyConsumed: consolidated[date]?.consumed = value
                    case .dietaryProtein: consolidated[date]?.protein = value
                    case .dietaryCarbohydrates: consolidated[date]?.carbs = value
                    case .dietaryFatTotal: consolidated[date]?.fat = value
                    case .bodyMass: consolidated[date]?.weight = value
                    default: break
                    }
                }
            }
            
            return consolidated
        }
    }

    // Helper: Wraps HKStatisticsCollectionQuery in an async function
    private func performCollectionQuery(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, option: HKStatisticsOptions, startDate: Date) async -> [Date: Double] {
        return await withCheckedContinuation { continuation in
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
                continuation.resume(returning: [:])
                return
            }
            
            let anchor = Calendar.current.startOfDay(for: Date()) // Anchor at midnight
            let interval = DateComponents(day: 1) // Daily intervals
            
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: nil, // We filter by date in the enumeration below
                options: option,
                anchorDate: anchor,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, results, _ in
                var dailyValues: [Date: Double] = [:]
                
                guard let statsCollection = results else {
                    continuation.resume(returning: [:])
                    return
                }
                
                // Enumerate from startDate to Now
                statsCollection.enumerateStatistics(from: startDate, to: Date()) { statistics, _ in
                    var value: Double = 0
                    
                    if option == .discreteAverage {
                        value = statistics.averageQuantity()?.doubleValue(for: unit) ?? 0
                    } else {
                        value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    }
                    
                    if value > 0 {
                        let date = Calendar.current.startOfDay(for: statistics.startDate)
                        dailyValues[date] = value
                    }
                }
                
                continuation.resume(returning: dailyValues)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Detailed Data Fetching
    
    /// Fetches all defined nutrition types for a specific date
    func fetchDetailedNutrition(for date: Date) async -> [NutritionItem] {
        return await withTaskGroup(of: NutritionItem?.self) { group in
            // Iterate over ALL types (Basic + Extended)
            for identifier in allDietaryTypes {
                group.addTask {
                    let unit = self.getPreferredUnit(for: identifier)
                    let value = await self.fetchSum(for: identifier, unit: unit, date: date)
                    
                    // Only return items that have data (> 0)
                    if value > 0 {
                        return NutritionItem(
                            name: self.getDisplayName(for: identifier),
                            value: value,
                            unit: unit.unitString
                        )
                    }
                    return nil
                }
            }
            
            var items: [NutritionItem] = []
            for await item in group {
                if let item = item {
                    items.append(item)
                }
            }
            
            // Sort: Macros first, then alphabetical
            return items.sorted { $0.name < $1.name }
        }
    }
    
    // MARK: - Weight Fetching
        
    /// Fetches the average body mass for a specific date in kg
    func fetchBodyMass(for date: Date) async -> Double {
        return await withCheckedContinuation { continuation in
            guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
                continuation.resume(returning: 0)
                return
            }
            
            let predicate = getPredicate(for: date)
            // Using discreteAverage to get a representative weight for the day if multiple samples exist
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
                // Always fetch as kg to match internal storage
                let val = result?.averageQuantity()?.doubleValue(for: .gramUnit(with: .kilo)) ?? 0
                continuation.resume(returning: val)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Historical Data Sync (Keep for single-day loops if needed)
    
    func fetchHistoricalHealthData(for date: Date) async -> (burned: Double, consumed: Double, protein: Double, carbs: Double, fat: Double) {
        return await withTaskGroup(of: (HKQuantityTypeIdentifier, Double).self) { group in
            let metrics: [(HKQuantityTypeIdentifier, HKUnit)] = [
                (.activeEnergyBurned, .kilocalorie()),
                (.dietaryEnergyConsumed, .kilocalorie()),
                (.dietaryProtein, .gram()),
                (.dietaryCarbohydrates, .gram()),
                (.dietaryFatTotal, .gram())
            ]
            
            for (id, unit) in metrics {
                group.addTask {
                    let val = await self.fetchSum(for: id, unit: unit, date: date)
                    return (id, val)
                }
            }
            
            var results: [HKQuantityTypeIdentifier: Double] = [:]
            for await (id, value) in group {
                results[id] = value
            }
            
            return (
                burned: results[.activeEnergyBurned] ?? 0,
                consumed: results[.dietaryEnergyConsumed] ?? 0,
                protein: results[.dietaryProtein] ?? 0,
                carbs: results[.dietaryCarbohydrates] ?? 0,
                fat: results[.dietaryFatTotal] ?? 0
            )
        }
    }
    
    // MARK: - Helpers
    
    private func fetchSum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, date: Date) async -> Double {
        return await withCheckedContinuation { continuation in
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
                continuation.resume(returning: 0)
                return
            }
            
            let predicate = getPredicate(for: date)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let sum = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }
    
    private func getPredicate(for date: Date) -> NSPredicate {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
    }
    
    private func getPreferredUnit(for identifier: HKQuantityTypeIdentifier) -> HKUnit {
        switch identifier {
        case .dietaryEnergyConsumed: return .kilocalorie()
        case .dietaryCholesterol, .dietarySodium, .dietaryPotassium, .dietaryCaffeine: return .gramUnit(with: .milli) // mg
        case .dietaryVitaminA, .dietaryVitaminD, .dietaryVitaminB12, .dietaryFolate, .dietaryBiotin: return .gramUnit(with: .micro) // mcg
        case .dietaryWater: return .literUnit(with: .milli) // mL
        default: return .gram()
        }
    }
    
    private func getDisplayName(for identifier: HKQuantityTypeIdentifier) -> String {
        switch identifier {
        case .dietaryEnergyConsumed: return "Calories"
        case .dietaryProtein: return "Protein"
        case .dietaryCarbohydrates: return "Carbohydrates"
        case .dietaryFatTotal: return "Total Fat"
        case .dietaryFatSaturated: return "Saturated Fat"
        case .dietaryFatMonounsaturated: return "Monounsaturated Fat"
        case .dietaryFatPolyunsaturated: return "Polyunsaturated Fat"
        case .dietaryCholesterol: return "Cholesterol"
        case .dietarySodium: return "Sodium"
        case .dietarySugar: return "Sugar"
        case .dietaryFiber: return "Fiber"
        case .dietaryVitaminA: return "Vitamin A"
        case .dietaryThiamin: return "Thiamin (B1)"
        case .dietaryRiboflavin: return "Riboflavin (B2)"
        case .dietaryNiacin: return "Niacin (B3)"
        case .dietaryPantothenicAcid: return "Pantothenic Acid (B5)"
        case .dietaryVitaminB6: return "Vitamin B6"
        case .dietaryBiotin: return "Biotin"
        case .dietaryVitaminB12: return "Vitamin B12"
        case .dietaryVitaminC: return "Vitamin C"
        case .dietaryVitaminD: return "Vitamin D"
        case .dietaryVitaminE: return "Vitamin E"
        case .dietaryVitaminK: return "Vitamin K"
        case .dietaryFolate: return "Folate"
        case .dietaryCalcium: return "Calcium"
        case .dietaryChloride: return "Chloride"
        case .dietaryIron: return "Iron"
        case .dietaryMagnesium: return "Magnesium"
        case .dietaryPhosphorus: return "Phosphorus"
        case .dietaryPotassium: return "Potassium"
        case .dietaryZinc: return "Zinc"
        case .dietaryWater: return "Water"
        case .dietaryCaffeine: return "Caffeine"
        default: return identifier.rawValue.replacingOccurrences(of: "HKQuantityTypeIdentifierDietary", with: "")
        }
    }
}
