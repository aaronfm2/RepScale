import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \ExerciseDefinition.name) private var exercises: [ExerciseDefinition]
    
    @State private var showingAddSheet = false
    @State private var exerciseToEdit: ExerciseDefinition? // State to track which exercise is being edited
    
    var body: some View {
        NavigationStack {
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
                        .contentShape(Rectangle()) // Make the whole row tappable
                        .onTapGesture {
                            exerciseToEdit = exercise
                        }
                        .swipeActions(edge: .leading) {
                            Button("Edit") {
                                exerciseToEdit = exercise
                            }
                            .tint(.yellow)
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
            // Sheet for Adding (New)
            .sheet(isPresented: $showingAddSheet) {
                ExerciseDefinitionSheet(exerciseToEdit: nil)
            }
            // Sheet for Editing (Existing)
            .sheet(item: $exerciseToEdit) { exercise in
                ExerciseDefinitionSheet(exerciseToEdit: exercise)
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

// Renamed and updated to handle both Add and Edit modes
struct ExerciseDefinitionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var exerciseToEdit: ExerciseDefinition?
    
    @State private var name = ""
    @State private var isCardio = false
    @State private var selectedMuscles: Set<String> = []
    
    init(exerciseToEdit: ExerciseDefinition? = nil) {
        self.exerciseToEdit = exerciseToEdit
        
        // Pre-populate fields if editing
        if let ex = exerciseToEdit {
            _name = State(initialValue: ex.name)
            _isCardio = State(initialValue: ex.isCardio)
            _selectedMuscles = State(initialValue: Set(ex.muscleGroups))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Details") {
                    TextField("Name (e.g. Bench Press)", text: $name)
                    Toggle("Is Cardio?", isOn: $isCardio)
                }
                
                Section("Target Muscles") {
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        HStack {
                            Text(muscle.rawValue)
                            Spacer()
                            if selectedMuscles.contains(muscle.rawValue) {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedMuscles.contains(muscle.rawValue) {
                                selectedMuscles.remove(muscle.rawValue)
                            } else {
                                selectedMuscles.insert(muscle.rawValue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(exerciseToEdit == nil ? "New Exercise" : "Edit Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        if let ex = exerciseToEdit {
            // Update existing
            ex.name = name
            ex.isCardio = isCardio
            ex.muscleGroups = Array(selectedMuscles)
        } else {
            // Create new
            let newDef = ExerciseDefinition(name: name, muscleGroups: Array(selectedMuscles), isCardio: isCardio)
            modelContext.insert(newDef)
        }
        dismiss()
    }
}
