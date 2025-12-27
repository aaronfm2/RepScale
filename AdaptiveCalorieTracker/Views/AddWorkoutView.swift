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
    
    // --- Helper for Grouping ---
    struct ExerciseGroup {
        let name: String
        var exercises: [ExerciseEntry]
    }
    
    var groupedExercises: [ExerciseGroup] {
        var groups: [ExerciseGroup] = []
        for exercise in tempExercises {
            if let index = groups.firstIndex(where: { $0.name == exercise.name }) {
                groups[index].exercises.append(exercise)
            } else {
                groups.append(ExerciseGroup(name: exercise.name, exercises: [exercise]))
            }
        }
        return groups
    }
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Session Details
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
                
                // MARK: - Exercises List (Editable)
                if tempExercises.isEmpty {
                    Section {
                        Text("No exercises added yet.")
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                } else {
                    ForEach(groupedExercises, id: \.name) { group in
                        Section {
                            ForEach(Array(group.exercises.enumerated()), id: \.element) { index, ex in
                                // Use Bindable to make the exercise editable in place
                                EditExerciseRow(exercise: ex, index: index)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        duplicateExercise(ex)
                                    } label: {
                                        Label("Copy", systemImage: "plus.square.on.square")
                                    }
                                    .tint(.blue)
                                }
                            }
                            .onDelete { indexSet in
                                deleteFromGroup(group: group, at: indexSet)
                            }
                            
                            Button(action: { addSet(to: group.name) }) {
                                Label("Add Set", systemImage: "plus")
                                    .font(.subheadline)
                            }
                            
                        } header: {
                            HStack {
                                Text(group.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(group.exercises.count) sets")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(nil)
                            }
                        }
                    }
                }
                
                // MARK: - Add New Exercise Button
                Section {
                    Button(action: { showAddExerciseSheet = true }) {
                        Label("Add New Exercise", systemImage: "dumbbell.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
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
    
    // MARK: - Logic Helpers (Unchanged)
    
    func deleteFromGroup(group: ExerciseGroup, at offsets: IndexSet) {
        let exercisesToDelete = offsets.map { group.exercises[$0] }
        tempExercises.removeAll { ex in
            exercisesToDelete.contains(where: { $0 === ex })
        }
    }
    
    func addSet(to groupName: String) {
        if let lastIndex = tempExercises.lastIndex(where: { $0.name == groupName }) {
            let ex = tempExercises[lastIndex]
            let newEx = ExerciseEntry(
                name: ex.name,
                reps: ex.reps,
                weight: ex.weight,
                duration: ex.duration,
                distance: ex.distance,
                isCardio: ex.isCardio,
                note: ""
            )
            if lastIndex + 1 < tempExercises.count {
                tempExercises.insert(newEx, at: lastIndex + 1)
            } else {
                tempExercises.append(newEx)
            }
        }
    }
    
    func duplicateExercise(_ ex: ExerciseEntry) {
        let newEx = ExerciseEntry(
            name: ex.name,
            reps: ex.reps,
            weight: ex.weight,
            duration: ex.duration,
            distance: ex.distance,
            isCardio: ex.isCardio,
            note: ex.note
        )
        if let index = tempExercises.firstIndex(of: ex) {
            if index + 1 < tempExercises.count {
                tempExercises.insert(newEx, at: index + 1)
            } else {
                tempExercises.append(newEx)
            }
        } else {
            tempExercises.append(newEx)
        }
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

// MARK: - Subview for Editable Row
// We extract this to use @Bindable safely on the Model class
struct EditExerciseRow: View {
    @Bindable var exercise: ExerciseEntry
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Set \(index + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 45, alignment: .leading)
                
                Divider()
                
                if exercise.isCardio {
                    HStack {
                        TextField("Dist", value: $exercise.distance, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("km")
                        Spacer()
                        TextField("Time", value: $exercise.duration, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                        Text("min")
                    }
                    .foregroundColor(.blue)
                } else {
                    HStack {
                        TextField("Reps", value: $exercise.reps, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                            .multilineTextAlignment(.trailing)
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                        
                        Text("reps").font(.caption).foregroundColor(.secondary)
                        
                        Spacer()
                        Text("x").foregroundColor(.secondary)
                        Spacer()
                        
                        TextField("Weight", value: $exercise.weight, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                        
                        Text("kg").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            
            // Optional Note Field
            TextField("Add note...", text: $exercise.note)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 60)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Updated Add Exercise Sheet with Library Support
// (Note: This struct remains largely unchanged, just ensuring context access)

struct AddExerciseSheet: View {
    @Binding var exercises: [ExerciseEntry]
    var workoutMuscles: Set<String>
    
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
                        
                        if !libraryExercises.isEmpty {
                            Menu {
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

// Template Loader (Unchanged)
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
