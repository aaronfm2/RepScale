import HealthKit

class HealthManager: ObservableObject {
    let healthStore = HKHealthStore()
    
    // Published properties to update the UI
    @Published var caloriesBurnedToday: Double = 0
    @Published var caloriesConsumedToday: Double = 0
    @Published var proteinToday: Double = 0
    @Published var carbsToday: Double = 0
    @Published var fatToday: Double = 0

    func requestAuthorization() {
        // Define the types we want to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!
        ]

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
    
    // New function to fetch Nutrition (Calories + Macros)
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
    
    // MARK: - Historical Data Sync
    
    /// Asynchronously fetches all relevant health data for a specific date
    func fetchHistoricalHealthData(for date: Date) async -> (burned: Double, consumed: Double, protein: Double, carbs: Double, fat: Double) {
        return await withTaskGroup(of: (HKQuantityTypeIdentifier, Double).self) { group in
            // Define metrics to fetch
            let metrics: [(HKQuantityTypeIdentifier, HKUnit)] = [
                (.activeEnergyBurned, .kilocalorie()),
                (.dietaryEnergyConsumed, .kilocalorie()),
                (.dietaryProtein, .gram()),
                (.dietaryCarbohydrates, .gram()),
                (.dietaryFatTotal, .gram())
            ]
            
            // Add tasks to group
            for (id, unit) in metrics {
                group.addTask {
                    let val = await self.fetchSum(for: id, unit: unit, date: date)
                    return (id, val)
                }
            }
            
            // Collect results
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
    
    // Helper helper to wrap HKStatisticsQuery in async
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
}
