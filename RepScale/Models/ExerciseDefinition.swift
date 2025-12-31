import Foundation
import SwiftData

@Model
final class ExerciseDefinition {
    
    var name: String = ""
    var muscleGroups: [String] = [] // e.g. ["Chest", "Triceps"]
    var isCardio: Bool = false
    
    init(name: String, muscleGroups: [String] = [], isCardio: Bool = false) {
        self.name = name
        self.muscleGroups = muscleGroups
        self.isCardio = isCardio
    }
}
