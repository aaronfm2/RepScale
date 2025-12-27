import SwiftUI
import SwiftData

struct AddWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    
    var workoutToEdit: Workout?
    
    @State private var date = Date()
    @State private var category = "Push"
    @State private var selectedMuscles: Set<String> = []
    @State private var note = ""
    
    @State private var tempExercises: [ExerciseEntry] = []
    @State private var showAddExerciseSheet = false
    
    @State private var showLoadTemplateSheet = false
    @State private var showSaveTemplateAlert = false
    @State private var newTemplateName = ""
    
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
                                
                                if ex.isCardio {
                                    HStack(spacing: 8) {
                                        if let dist = ex.distance, dist > 0 {
                                            Label("\(dist, specifier: "%.2f") km", systemImage: "location.fill")
                                        }
                                        if let time = ex.duration, time > 0 {
                                            Label("\(Int(time)) min", systemImage: "clock.fill")
                                        }
                                    }
                                    .font(.subheadline).foregroundColor(.blue)
                                } else {
                                    Text("\(ex.reps ?? 0) reps @ \(ex.weight ?? 0.0, specifier: "%.1f") kg")
                                        .font(.subheadline).foregroundColor(.secondary)
                                }
                                
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
                // Pass the workout's selected muscles to the sheet for filtering
                AddExerciseSheet(exercises: $tempExercises, workoutMuscles: selectedMuscles)
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
                    date = workout.date
                    category = workout.category
                    selectedMuscles = Set(workout.muscleGroups)
                    note = workout.note
                    tempExercises = workout.exercises
                }
            }
        }
    }
    
    // (Helper functions duplicateExercise, saveAsTemplate, loadTemplate, saveWorkout remain unchanged)
    func duplicateExercise(_ ex: ExerciseEntry) {
        let newEx = ExerciseEntry(name: ex.name, reps: ex.reps, weight: ex.weight, duration: ex.duration, distance: ex.distance, isCardio: ex.isCardio, note: ex.note)
        tempExercises.append(newEx)
    }
    
    func saveAsTemplate() {
        guard !newTemplateName.isEmpty else { return }
        let template = WorkoutTemplate(name: newTemplateName, category: category, muscleGroups: Array(selectedMuscles))
        let templateExercises = tempExercises.map { ex in
            TemplateExerciseEntry(name: ex.name, reps: ex.reps, weight: ex.weight, duration: ex.duration, distance: ex.distance, isCardio: ex.isCardio, note: ex.note)
        }
        template.exercises = templateExercises
        modelContext.insert(template)
    }
    
    func loadTemplate(_ template: WorkoutTemplate) {
        category = template.category
        selectedMuscles = Set(template.muscleGroups)
        let newExercises = template.exercises.map { tex in
            ExerciseEntry(name: tex.name, reps: tex.reps, weight: tex.weight, duration: tex.duration, distance: tex.distance, isCardio: tex.isCardio, note: tex.note)
        }
        tempExercises.append(contentsOf: newExercises)
        showLoadTemplateSheet = false
    }
    
    func saveWorkout() {
        if let workout = workoutToEdit {
            workout.date = Calendar.current.startOfDay(for: date)
            workout.category = category
            workout.muscleGroups = Array(selectedMuscles)
            workout.note = note
            workout.exercises = tempExercises
        } else {
            let workout = Workout(date: date, category: category, muscleGroups: Array(selectedMuscles), note: note)
            workout.exercises = tempExercises
            modelContext.insert(workout)
        }
        dismiss()
    }
}

// MARK: - Updated Add Exercise Sheet with Library Support

struct AddExerciseSheet: View {
    @Binding var exercises: [ExerciseEntry]
    var workoutMuscles: Set<String> // Passed in context
    
    @Environment(\.dismiss) var dismiss
    @Query(sort: \ExerciseDefinition.name) private var libraryExercises: [ExerciseDefinition]
    
    @State private var name = ""
    @State private var note = ""
    @State private var exerciseType: ExerciseType = .strength
    
    @State private var reps = ""
    @State private var weight = ""
    @State private var duration = ""
    @State private var distance = ""
    @State private var setCount = 1
    
    enum ExerciseType: String, CaseIterable {
        case strength = "Strength"
        case cardio = "Cardio"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    HStack {
                        TextField("Exercise Name (e.g. Bench Press)", text: $name)
                        
                        // --- NEW: Library Menu ---
                        if !libraryExercises.isEmpty {
                            Menu {
                                // Smart Grouping: Recommended (matches muscles) vs Others
                                let recommended = libraryExercises.filter { !Set($0.muscleGroups).isDisjoint(with: workoutMuscles) }
                                let others = libraryExercises.filter { Set($0.muscleGroups).isDisjoint(with: workoutMuscles) }
                                
                                if !recommended.isEmpty {
                                    Section("Recommended") {
                                        ForEach(recommended) { ex in
                                            Button(ex.name) { selectFromLibrary(ex) }
                                        }
                                    }
                                }
                                
                                if !others.isEmpty {
                                    Section("All Exercises") {
                                        ForEach(others) { ex in
                                            Button(ex.name) { selectFromLibrary(ex) }
                                        }
                                    }
                                }
                                
                            } label: {
                                Image(systemName: "book.circle")
                                    .font(.title2)
                            }
                        }
                    }
                    
                    Picker("Type", selection: $exerciseType) {
                        ForEach(ExerciseType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if exerciseType == .strength {
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
                    } else {
                        HStack {
                            Text("Duration (min)")
                            Spacer()
                            TextField("0", text: $duration).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Distance (km)")
                            Spacer()
                            TextField("0.0", text: $distance).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
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
                    Text("Adds multiple entries at once.")
                }
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveExercises()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    func selectFromLibrary(_ ex: ExerciseDefinition) {
        self.name = ex.name
        self.exerciseType = ex.isCardio ? .cardio : .strength
    }
    
    func saveExercises() {
        let isCardio = (exerciseType == .cardio)
        let rVal = Int(reps)
        let wVal = Double(weight)
        let durVal = Double(duration)
        let distVal = Double(distance)
        
        for _ in 0..<setCount {
            let newEx = ExerciseEntry(
                name: name,
                reps: rVal,
                weight: wVal,
                duration: durVal,
                distance: distVal,
                isCardio: isCardio,
                note: note
            )
            exercises.append(newEx)
        }
        dismiss()
    }
}

// Template Loader (Same as before)
struct LoadTemplateSheet: View {
    let templates: [WorkoutTemplate]
    let onSelect: (WorkoutTemplate) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
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
                    .onDelete { indexSet in
                        withAnimation {
                            for index in indexSet { modelContext.delete(templates[index]) }
                        }
                    }
                }
            }
            .navigationTitle("Load Template")
            .toolbar {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
