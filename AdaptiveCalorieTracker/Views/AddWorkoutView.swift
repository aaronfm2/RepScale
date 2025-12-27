import SwiftUI
import SwiftData

struct AddWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Fetch available templates
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    
    // Optional workout to edit
    var workoutToEdit: Workout?
    
    @State private var date = Date()
    @State private var category = "Push"
    @State private var selectedMuscles: Set<String> = []
    @State private var note = ""
    
    // Temporary storage for exercises being added
    @State private var tempExercises: [ExerciseEntry] = []
    @State private var showAddExerciseSheet = false
    
    // Template States
    @State private var showLoadTemplateSheet = false
    @State private var showSaveTemplateAlert = false
    @State private var newTemplateName = ""
    
    // Predefined options
    let categories = ["Push", "Pull", "Legs", "Upper", "Lower", "Full Body", "Cardio", "Chest", "Arms", "Back", "Shoulders", "Abs"]
    let muscles = ["Chest", "Back", "Legs", "Shoulders", "Biceps", "Triceps", "Abs", "Cardio"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Session Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    
                    // Muscle Multi-Select
                    DisclosureGroup("Muscles Trained (\(selectedMuscles.count))") {
                        ForEach(muscles, id: \.self) { muscle in
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
                
                Section {
                    if tempExercises.isEmpty {
                        Text("No exercises added yet.")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(tempExercises.enumerated()), id: \.offset) { index, ex in
                            VStack(alignment: .leading) {
                                Text(ex.name).font(.headline)
                                Text("\(ex.reps) reps @ \(ex.weight, specifier: "%.1f") kg")
                                    .font(.subheadline).foregroundColor(.secondary)
                                if !ex.note.isEmpty {
                                    Text(ex.note).font(.caption).italic()
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    duplicateExercise(ex)
                                } label: {
                                    Label("Duplicate Set", systemImage: "plus.square.on.square")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete { indexSet in
                            tempExercises.remove(atOffsets: indexSet)
                        }
                    }
                    
                    Button(action: { showAddExerciseSheet = true }) {
                        Label("Add Exercise", systemImage: "dumbbell.fill")
                    }
                } header: {
                    HStack {
                        Text("Exercises")
                        Spacer()
                        Text("Swipe right to duplicate set")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .textCase(nil)
                    }
                }
                
                Section("Notes") {
                    TextField("Workout notes...", text: $note)
                }
            }
            .navigationTitle(workoutToEdit == nil ? "Log Workout" : "Edit Workout")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // Template Menu
                        Menu {
                            Button {
                                showLoadTemplateSheet = true
                            } label: {
                                Label("Load Template", systemImage: "arrow.down.doc")
                            }
                            
                            Button {
                                newTemplateName = ""
                                showSaveTemplateAlert = true
                            } label: {
                                Label("Save as Template", systemImage: "arrow.up.doc")
                            }
                            .disabled(tempExercises.isEmpty)
                        } label: {
                            Image(systemName: "doc.text")
                        }

                        Button("Save") { saveWorkout() }
                            .disabled(selectedMuscles.isEmpty)
                            .bold()
                    }
                }
            }
            .sheet(isPresented: $showAddExerciseSheet) {
                AddExerciseSheet(exercises: $tempExercises)
            }
            .sheet(isPresented: $showLoadTemplateSheet) {
                LoadTemplateSheet(templates: templates) { selectedTemplate in
                    loadTemplate(selectedTemplate)
                }
            }
            .alert("Save Template", isPresented: $showSaveTemplateAlert) {
                TextField("Template Name (e.g. Chest Day)", text: $newTemplateName)
                Button("Cancel", role: .cancel) { }
                Button("Save") { saveAsTemplate() }
            } message: {
                Text("Save the current exercises and settings as a template?")
            }
            .onAppear {
                if let workout = workoutToEdit {
                    // Populate fields if editing
                    date = workout.date
                    category = workout.category
                    selectedMuscles = Set(workout.muscleGroups)
                    note = workout.note
                    // We copy the exercises so we can edit them freely
                    // In a real app, you might want deep copies
                    tempExercises = workout.exercises
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func duplicateExercise(_ ex: ExerciseEntry) {
        let newEx = ExerciseEntry(name: ex.name, reps: ex.reps, weight: ex.weight, note: ex.note)
        tempExercises.append(newEx)
    }
    
    func saveAsTemplate() {
        guard !newTemplateName.isEmpty else { return }
        let template = WorkoutTemplate(name: newTemplateName, category: category, muscleGroups: Array(selectedMuscles))
        
        // Map current exercises to template exercises
        let templateExercises = tempExercises.map { ex in
            TemplateExerciseEntry(name: ex.name, reps: ex.reps, weight: ex.weight, note: ex.note)
        }
        template.exercises = templateExercises
        
        modelContext.insert(template)
    }
    
    func loadTemplate(_ template: WorkoutTemplate) {
        // Update Metadata
        category = template.category
        selectedMuscles = Set(template.muscleGroups)
        
        // Convert Template Exercises to Actual Exercises
        // We Append them (or should we replace? Appending is safer)
        let newExercises = template.exercises.map { tex in
            ExerciseEntry(name: tex.name, reps: tex.reps, weight: tex.weight, note: tex.note)
        }
        tempExercises.append(contentsOf: newExercises)
        
        showLoadTemplateSheet = false
    }
    
    func saveWorkout() {
        if let workout = workoutToEdit {
            // Update Existing
            workout.date = Calendar.current.startOfDay(for: date)
            workout.category = category
            workout.muscleGroups = Array(selectedMuscles)
            workout.note = note
            workout.exercises = tempExercises
        } else {
            // Create New
            let workout = Workout(date: date, category: category, muscleGroups: Array(selectedMuscles), note: note)
            workout.exercises = tempExercises
            modelContext.insert(workout)
        }
        dismiss()
    }
}

// MARK: - Subviews

struct AddExerciseSheet: View {
    @Binding var exercises: [ExerciseEntry]
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var note = ""
    @State private var setCount = 1 // New: Add multiple sets at once
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Exercise Name (e.g. Bench Press)", text: $name)
                    
                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("0", text: $reps).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("0.0", text: $weight).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    
                    TextField("Note (Optional)", text: $note)
                }
                
                Section {
                    Stepper(value: $setCount, in: 1...10) {
                        HStack {
                            Text("Add")
                            Text("\(setCount) sets").bold().foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("Quick Add")
                } footer: {
                    Text("Adds \(setCount) entries with the same weight and reps.")
                }
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let r = Int(reps), let w = Double(weight), !name.isEmpty {
                            for _ in 0..<setCount {
                                let newEx = ExerciseEntry(name: name, reps: r, weight: w, note: note)
                                exercises.append(newEx)
                            }
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || reps.isEmpty || weight.isEmpty)
                }
            }
        }
    }
}

struct LoadTemplateSheet: View {
    let templates: [WorkoutTemplate]
    let onSelect: (WorkoutTemplate) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext // To delete templates
    
    var body: some View {
        NavigationView {
            List {
                if templates.isEmpty {
                    Text("No templates saved yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(templates) { template in
                        Button {
                            onSelect(template)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(template.name).font(.headline)
                                    Text(template.category)
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(template.exercises.count) exercises")
                                    .font(.caption).foregroundColor(.secondary)
                                Image(systemName: "plus.circle")
                            }
                        }
                    }
                    .onDelete(perform: deleteTemplate)
                }
            }
            .navigationTitle("Load Template")
            .toolbar {
                Button("Cancel") { dismiss() }
            }
        }
    }
    
    func deleteTemplate(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(templates[index])
            }
        }
    }
}
