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
        let predicate = getTodayPredicate()

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
            let predicate = getTodayPredicate()
            
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
    
    private func getTodayPredicate() -> NSPredicate {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        return HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
    }
}
