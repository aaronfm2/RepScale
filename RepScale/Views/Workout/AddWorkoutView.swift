import SwiftUI
import SwiftData
import AudioToolbox

struct AddWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Fetch templates for the "Load Template" sheet
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    
    // --- CLOUD SYNC: Injected Profile ---
    var profile: UserProfile
    
    // The workout we are editing (if any)
    let workoutToEdit: Workout?
    
    // The ViewModel responsible for this View's state
    @State private var viewModel: AddWorkoutViewModel
    
    init(workoutToEdit: Workout?, profile: UserProfile) {
        self.workoutToEdit = workoutToEdit
        self.profile = profile
        _viewModel = State(initialValue: AddWorkoutViewModel(workoutToEdit: workoutToEdit))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                sessionSection
                exercisesSection
                addExerciseSection
                
                // Rest Timer Section
                RestTimerSection()
                
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
                ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
            }
            // Sheets & Alerts
            .sheet(isPresented: $viewModel.showAddExerciseSheet) {
                // Pass selected muscles to the sheet for filtering
                let muscleStrings = Set(viewModel.selectedMuscles)
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

// MARK: - Sub-View Extensions
extension AddWorkoutView {
    
    // 1. Session Details Section
    private var sessionSection: some View {
        Section("Session Details") {
            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
            
            Picker("Category", selection: $viewModel.category) {
                ForEach(WorkoutCategories.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat.rawValue)
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
    
    // 2. Exercises List Section
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
                        // --- UPDATED: Pass profile.unitSystem ---
                        EditExerciseRow(exercise: ex, index: index, unitSystem: profile.unitSystem)
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

// MARK: - Rest Timer Component
struct RestTimerSection: View {
    @State private var timeRemaining: Int = 0
    @State private var timer: Timer? = nil
    @State private var isRunning = false
    
    // Presets in seconds
    let presets = [30, 60, 90, 120]
    
    var body: some View {
        Section("Rest Timer") {
            VStack(spacing: 15) {
                // Time Display
                Text(formatTime(timeRemaining))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(timeRemaining > 0 ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                // Controls
                HStack(spacing: 20) {
                    if isRunning {
                        Button(action: pauseTimer) {
                            Label("Pause", systemImage: "pause.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.orange)
                    } else {
                        Button(action: startTimer) {
                            Label("Start", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.green)
                        .disabled(timeRemaining == 0)
                    }
                    
                    Button(action: resetTimer) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.red)
                }
                .buttonStyle(.bordered)
                
                // Presets
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(presets, id: \.self) { seconds in
                            Button("\(seconds)s") {
                                setTime(seconds)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                        
                        Button("+15s") {
                            addTime(15)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Timer Logic
    
    func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func setTime(_ seconds: Int) {
        stopTimer()
        timeRemaining = seconds
        startTimer()
    }
    
    func addTime(_ seconds: Int) {
        timeRemaining += seconds
    }
    
    func startTimer() {
        guard !isRunning && timeRemaining > 0 else { return }
        isRunning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                // Timer Finished
                playAlertSound() // 2. Trigger sound here
                stopTimer()
            }
        }
    }
    
    func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func resetTimer() {
        stopTimer()
        timeRemaining = 0
    }
    
    // 3. Helper to play sound
    func playAlertSound() {
        // 1005 is the standard "alert" sound on iOS.
        // kSystemSoundID_Vibrate (4095) can be used for vibration.
        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

// MARK: - Subview for Editable Row
struct EditExerciseRow: View {
    @Bindable var exercise: ExerciseEntry
    let index: Int
    
    // --- NEW: Unit System injected from parent ---
    let unitSystem: String
    
    // Computed labels
    var weightLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    var distLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "mi" : "km" }
    
    var body: some View {
        // --- Custom Bindings for Conversion ---
        let weightBinding = Binding<Double?>(
            get: { exercise.weight?.toUserWeight(system: unitSystem) },
            set: { exercise.weight = $0?.toStoredWeight(system: unitSystem) }
        )
        
        let distBinding = Binding<Double?>(
            get: { exercise.distance?.toUserDistance(system: unitSystem) },
            set: { exercise.distance = $0?.toStoredDistance(system: unitSystem) }
        )
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Set \(index + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 45, alignment: .leading)
                
                Divider()
                
                if exercise.isCardio {
                    HStack {
                        // Use distBinding and distLabel
                        TextField("Dist", value: distBinding, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text(distLabel)
                        
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
                        
                        // Use weightBinding and weightLabel
                        TextField("Weight", value: weightBinding, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                        
                        Text(weightLabel).font(.caption).foregroundColor(.secondary)
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
    
    @State private var searchText = ""
    
    // Logic to filter exercises
    var filteredExercises: [ExerciseDefinition] {
        if searchText.isEmpty { return libraryExercises }
        return libraryExercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // Exercises that match the workout's target muscles
    var recommendedExercises: [ExerciseDefinition] {
        libraryExercises.filter { ex in
            !Set(ex.muscleGroups).isDisjoint(with: workoutMuscles)
        }
    }
    
    // All other exercises
    var otherExercises: [ExerciseDefinition] {
        libraryExercises.filter { ex in
            Set(ex.muscleGroups).isDisjoint(with: workoutMuscles)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // 1. Custom Exercise Option
                Section {
                    NavigationLink {
                        CustomExerciseForm(onSave: { newEx in
                            exercises.append(newEx)
                            dismiss()
                        })
                    } label: {
                        Label("Create New Exercise", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                // 2. Search Results or Smart Categories
                if !searchText.isEmpty {
                    ForEach(filteredExercises) { ex in
                        ExerciseRow(exercise: ex) { addExercise(ex) }
                    }
                } else {
                    if !recommendedExercises.isEmpty {
                        Section("Recommended (Matches Category)") {
                            ForEach(recommendedExercises) { ex in
                                ExerciseRow(exercise: ex) { addExercise(ex) }
                            }
                        }
                    }
                    
                    if !otherExercises.isEmpty {
                        Section("Library") {
                            ForEach(otherExercises) { ex in
                                ExerciseRow(exercise: ex) { addExercise(ex) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Exercise")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    func addExercise(_ ex: ExerciseDefinition) {
        let newEx = ExerciseEntry(
            name: ex.name,
            reps: nil,
            weight: nil,
            duration: nil,
            distance: nil,
            isCardio: ex.isCardio,
            note: ""
        )
        exercises.append(newEx)
        dismiss()
    }
}

// MARK: - Helper Views

struct ExerciseRow: View {
    let exercise: ExerciseDefinition
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if !exercise.muscleGroups.isEmpty {
                        Text(exercise.muscleGroups.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                
                // Visual Indicator
                if exercise.isCardio {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                } else {
                    Image(systemName: "dumbbell.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .padding(6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .contentShape(Rectangle()) // Ensures the whole row is tappable
        }
        .buttonStyle(.plain)
    }
}

struct CustomExerciseForm: View {
    @Environment(\.modelContext) private var modelContext
    var onSave: (ExerciseEntry) -> Void
    
    @State private var name = ""
    @State private var isCardio = false
    @State private var note = ""
    
    // Library Saving State
    @State private var saveToLibrary = false
    @State private var selectedMuscles: Set<String> = []
    
    var body: some View {
        Form {
            Section("New Exercise Details") {
                TextField("Name (e.g. Burpees)", text: $name)
                Toggle("Cardio Exercise?", isOn: $isCardio)
                TextField("Default Note (Optional)", text: $note)
            }
            
            Section {
                Toggle("Save to Exercise Library", isOn: $saveToLibrary)
            } footer: {
                Text("Save this exercise to your library for future use.")
            }
            
            // Conditional Section: Only show if saving to library
            if saveToLibrary {
                Section("Target Muscles (Required)") {
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
            
            Button("Add to Workout") {
                saveAndFinish()
            }
            .disabled(isInvalid)
        }
        .navigationTitle("Custom Exercise")
    }
    
    var isInvalid: Bool {
        if name.isEmpty { return true }
        if saveToLibrary && selectedMuscles.isEmpty { return true }
        return false
    }
    
    func saveAndFinish() {
        // 1. Save to Library if requested
        if saveToLibrary {
            let newDef = ExerciseDefinition(
                name: name,
                muscleGroups: Array(selectedMuscles),
                isCardio: isCardio
            )
            modelContext.insert(newDef)
        }
        
        // 2. Add to current workout
        let newEx = ExerciseEntry(
            name: name,
            isCardio: isCardio,
            note: note
        )
        onSave(newEx)
    }
}

// MARK: - Template Loader
struct LoadTemplateSheet: View {
    let templates: [WorkoutTemplate]
    let onSelect: (WorkoutTemplate) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        NavigationStack {
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
                                // FIX: Safely unwrap optional exercises count
                                Text("\((template.exercises ?? []).count) exercises")
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
