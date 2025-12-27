import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \ExerciseDefinition.name) private var exercises: [ExerciseDefinition]
    
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationView {
            List {
                if exercises.isEmpty {
                    Text("No exercises in library. Tap + to create one.")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(exercises) { exercise in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(exercise.name).font(.headline)
                                Text(exercise.muscleGroups.joined(separator: ", "))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if exercise.isCardio {
                                Image(systemName: "heart.fill").foregroundColor(.red).font(.caption)
                            } else {
                                Image(systemName: "dumbbell.fill").foregroundColor(.blue).font(.caption)
                            }
                        }
                    }
                    .onDelete(perform: deleteExercises)
                }
            }
            .navigationTitle("Exercise Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddExerciseDefinitionSheet()
            }
        }
    }
    
    private func deleteExercises(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(exercises[index])
            }
        }
    }
}

struct AddExerciseDefinitionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var isCardio = false
    @State private var selectedMuscles: Set<String> = []
    
    let allMuscles = ["Chest", "Back", "Legs", "Shoulders", "Biceps", "Triceps", "Abs", "Cardio"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exercise Details") {
                    TextField("Name (e.g. Bench Press)", text: $name)
                    Toggle("Is Cardio?", isOn: $isCardio)
                }
                
                Section("Target Muscles") {
                    ForEach(allMuscles, id: \.self) { muscle in
                        HStack {
                            Text(muscle)
                            Spacer()
                            if selectedMuscles.contains(muscle) {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedMuscles.contains(muscle) {
                                selectedMuscles.remove(muscle)
                            } else {
                                selectedMuscles.insert(muscle)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newDef = ExerciseDefinition(name: name, muscleGroups: Array(selectedMuscles), isCardio: isCardio)
                        modelContext.insert(newDef)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
