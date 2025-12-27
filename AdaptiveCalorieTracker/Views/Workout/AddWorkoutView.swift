import SwiftUI
import SwiftData

struct AddWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Fetch templates for the "Load Template" sheet
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    
    // The workout we are editing (if any)
    let workoutToEdit: Workout?
    
    // The ViewModel responsible for this View's state
    @State private var viewModel: AddWorkoutViewModel
    
    init(workoutToEdit: Workout?) {
        self.workoutToEdit = workoutToEdit
        _viewModel = State(initialValue: AddWorkoutViewModel(workoutToEdit: workoutToEdit))
    }
    
    var body: some View {
        NavigationView {
            Form {
                sessionSection
                exercisesSection
                addExerciseSection
                notesSection
            }
            .navigationTitle(workoutToEdit == nil ? "Log Workout" : "Edit Workout")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // Templates Menu
                        Menu {
                            Button {
                                viewModel.showLoadTemplateSheet = true
                            } label: {
                                Label("Load Template", systemImage: "arrow.down.doc")
                            }
                            
                            Button {
                                viewModel.newTemplateName = ""
                                viewModel.showSaveTemplateAlert = true
                            } label: {
                                Label("Save as Template", systemImage: "arrow.up.doc")
                            }
                            .disabled(viewModel.exercises.isEmpty)
                        } label: {
                            Image(systemName: "doc.text")
                        }

                        // Save Button
                        Button("Save") {
                            viewModel.saveWorkout(context: modelContext, originalWorkout: workoutToEdit) {
                                dismiss()
                            }
                        }
                        .disabled(viewModel.selectedMuscles.isEmpty)
                        .bold()
                    }
                }
            }
            // Sheets & Alerts
            .sheet(isPresented: $viewModel.showAddExerciseSheet) {
                // Fix: Convert Set<MuscleGroup> -> Set<String> for the subview
                let muscleStrings = Set(viewModel.selectedMuscles.map { $0 })
                AddExerciseSheet(exercises: $viewModel.exercises, workoutMuscles: muscleStrings)
            }
            .sheet(isPresented: $viewModel.showLoadTemplateSheet) {
                LoadTemplateSheet(templates: templates) { selectedTemplate in
                    viewModel.loadTemplate(selectedTemplate)
                }
            }
            .alert("Save Template", isPresented: $viewModel.showSaveTemplateAlert) {
                TextField("Template Name (e.g. Chest Day)", text: $viewModel.newTemplateName)
                Button("Cancel", role: .cancel) { }
                Button("Save") { viewModel.saveAsTemplate(context: modelContext) }
            } message: {
                Text("Save the current exercises and settings as a template?")
            }
        }
    }
}

// MARK: - Sub-View Extensions to Fix Compiler Timeouts
extension AddWorkoutView {
    
    // 1. Session Details Section
    private var sessionSection: some View {
        Section("Session Details") {
            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
            
            Picker("Category", selection: $viewModel.category) {
                ForEach(WorkoutCategories.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            
            DisclosureGroup("Muscles Trained (\(viewModel.selectedMuscles.count))") {
                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    HStack {
                        Text(muscle.rawValue)
                        Spacer()
                        if viewModel.selectedMuscles.contains(muscle.rawValue) {
                            Image(systemName: "checkmark").foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if viewModel.selectedMuscles.contains(muscle.rawValue) {
                            viewModel.selectedMuscles.remove(muscle.rawValue)
                        } else {
                            viewModel.selectedMuscles.insert(muscle.rawValue)
                        }
                    }
                }
            }
        }
    }
    
    // 2. Exercises List Section (Complex Logic)
    @ViewBuilder
    private var exercisesSection: some View {
        if viewModel.exercises.isEmpty {
            Section {
                Text("No exercises added yet.")
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        } else {
            ForEach(viewModel.groupedExercises, id: \.name) { group in
                Section {
                    ForEach(Array(group.exercises.enumerated()), id: \.element) { index, ex in
                        EditExerciseRow(exercise: ex, index: index)
                            .swipeActions(edge: .leading) {
                                Button {
                                    viewModel.duplicateExercise(ex)
                                } label: {
                                    Label("Copy", systemImage: "plus.square.on.square")
                                }
                                .tint(.blue)
                            }
                    }
                    .onDelete { indexSet in
                        viewModel.deleteFromGroup(group: group, at: indexSet)
                    }
                    
                    Button(action: { viewModel.addSet(to: group.name) }) {
                        Label("Add Set", systemImage: "plus")
                            .font(.subheadline)
                    }
                    
                } header: {
                    HStack {
                        Text(group.name).font(.headline).foregroundColor(.primary)
                        Spacer()
                        Text("\(group.exercises.count) sets")
                            .font(.caption).foregroundColor(.secondary).textCase(nil)
                    }
                }
            }
        }
    }
    
    // 3. Add Exercise Button Section
    private var addExerciseSection: some View {
        Section {
            Button(action: { viewModel.showAddExerciseSheet = true }) {
                Label("Add New Exercise", systemImage: "dumbbell.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    // 4. Notes Section
    private var notesSection: some View {
        Section("Notes") {
            TextField("Workout notes...", text: $viewModel.note)
        }
    }
}

// MARK: - Subview for Editable Row
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

// MARK: - Add Exercise Sheet
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

// MARK: - Template Loader
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
