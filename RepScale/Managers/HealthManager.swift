import HealthKit

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

    // Expanded list of all nutrition types to read
    private let allDietaryTypes: [HKQuantityTypeIdentifier] = [
        .dietaryEnergyConsumed,
        .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal,
        .dietaryFatSaturated, .dietaryFatMonounsaturated, .dietaryFatPolyunsaturated,
        .dietaryCholesterol, .dietarySodium, .dietarySugar, .dietaryFiber,
        .dietaryVitaminA, .dietaryThiamin, .dietaryRiboflavin, .dietaryNiacin,
        .dietaryPantothenicAcid, .dietaryVitaminB6, .dietaryBiotin, .dietaryVitaminB12,
        .dietaryVitaminC, .dietaryVitaminD, .dietaryVitaminE, .dietaryVitaminK,
        .dietaryFolate, .dietaryCalcium, .dietaryChloride, .dietaryIron,
        .dietaryMagnesium, .dietaryPhosphorus, .dietaryPotassium, .dietaryZinc,
        .dietaryWater, .dietaryCaffeine
    ]

    func requestAuthorization() {
        // Start with non-dietary types
        var typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!
        ]
        
        // Add all dietary types
        for id in allDietaryTypes {
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
    
    // MARK: - Detailed Data Fetching
    
    /// Fetches all defined nutrition types for a specific date
    func fetchDetailedNutrition(for date: Date) async -> [NutritionItem] {
        return await withTaskGroup(of: NutritionItem?.self) { group in
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
    
    // MARK: - Historical Data Sync (Keep existing for backward compatibility)
    
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
