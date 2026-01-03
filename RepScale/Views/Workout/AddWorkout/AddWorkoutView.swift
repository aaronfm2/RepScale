import SwiftUI
import SwiftData
import AudioToolbox

struct AddWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // 1. Detect Backgrounding for Autosave
    @Environment(\.scenePhase) var scenePhase
    
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    
    var profile: UserProfile
    let workoutToEdit: Workout?
    
    @State private var viewModel: AddWorkoutViewModel
    
    // 2. State to track the live workout for autosaves
    @State private var activeWorkout: Workout?
    
    init(workoutToEdit: Workout?, profile: UserProfile) {
        self.workoutToEdit = workoutToEdit
        self.profile = profile
        
        // Initialize View Model
        _viewModel = State(initialValue: AddWorkoutViewModel(workoutToEdit: workoutToEdit))
        
        // Initialize local state for autosave tracking
        _activeWorkout = State(initialValue: workoutToEdit)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                sessionSection
                exercisesSection
                addExerciseSection
                RestTimerSection()
                notesSection
                
                // Bottom Spacer for Keyboard
                Section {
                    Color.clear.frame(height: 400)
                }
                .listRowBackground(Color.clear)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(workoutToEdit == nil ? "Log Workout" : "Edit Workout")
            .toolbar {
                // MARK: - Navigation Bar Items
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
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

                        // Manual Save Button (Finalizes)
                        Button("Done") {
                            // Cancel any pending debounce tasks before final save
                            viewModel.forceImmediateSave(context: modelContext, originalWorkout: activeWorkout)
                            dismiss()
                        }
                        .disabled(viewModel.selectedMuscles.isEmpty)
                        .bold()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddExerciseSheet) {
                let muscleStrings = Set(viewModel.selectedMuscles)
                AddExerciseSheet(exercises: $viewModel.exercises, workoutMuscles: muscleStrings, profile: profile)
                    .onDisappear {
                        // Autosave when returning from adding an exercise
                        triggerDebouncedSave()
                    }
            }
            .sheet(isPresented: $viewModel.showLoadTemplateSheet) {
                LoadTemplateSheet(templates: templates) { selectedTemplate in
                    viewModel.loadTemplate(selectedTemplate)
                    triggerDebouncedSave()
                }
            }
            .alert("Save Template", isPresented: $viewModel.showSaveTemplateAlert) {
                TextField("Template Name (e.g. Chest Day)", text: $viewModel.newTemplateName)
                Button("Cancel", role: .cancel) { }
                Button("Save") { viewModel.saveAsTemplate(context: modelContext) }
            } message: {
                Text("Save the current exercises and settings as a template?")
            }
            
            // MARK: - AUTOSAVE TRIGGERS
            
            // 3. Save when app goes to background (Critical for data safety)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background || newPhase == .inactive {
                    // Force save immediately, bypassing the debounce timer
                    viewModel.forceImmediateSave(context: modelContext, originalWorkout: activeWorkout)
                }
            }
        }
        // MARK: - KEYBOARD TOOLBAR
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
    
    // MARK: - Autosave Helpers
    
    /// Triggers the ViewModel to wait 2 seconds, then save.
    /// Does not re-render the view.
    private func triggerDebouncedSave() {
        guard !viewModel.exercises.isEmpty else { return }
        
        // Pass the context and the current active workout to the VM
        viewModel.scheduleAutosave(context: modelContext, originalWorkout: activeWorkout)
        
        // Note: We don't need to manually update `activeWorkout` here immediately.
        // The save function in VM should ideally return the saved ID or object if needed,
        // but for autosave, relying on the ID persistence is usually sufficient.
        // If your saveWorkout returns a NEW object every time (creation), you might need to handle that logic
        // in the main actor closure in the VM.
    }
}

extension AddWorkoutView {
    
    private var sessionSection: some View {
        Section("Session Details") {
            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
            
            Picker("Category", selection: $viewModel.category) {
                ForEach(WorkoutCategories.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat.rawValue)
                }
            }
            
            NavigationLink {
                MuscleSelectionList(selectedMuscles: $viewModel.selectedMuscles, profile: profile)
            } label: {
                HStack {
                    Text("Target Muscles")
                    Spacer()
                    if viewModel.selectedMuscles.isEmpty {
                        Text("None")
                            .foregroundColor(.secondary)
                    } else {
                        Text(viewModel.selectedMuscles.sorted().joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        }
    }
    
    private var exercisesSection: some View {
        Group {
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
                        ForEach(Array(group.exercises.enumerated()), id: \.element.uuid) { index, ex in
                            EditExerciseRow(
                                exercise: ex,
                                index: index,
                                unitSystem: profile.unitSystem,
                                // PERFORMANCE FIX: Pass the trigger function, don't update State
                                onInputChanged: { triggerDebouncedSave() }
                            )
                            .swipeActions(edge: .leading) {
                                Button {
                                    viewModel.duplicateExercise(ex)
                                    triggerDebouncedSave()
                                } label: {
                                    Label("Copy", systemImage: "plus.square.on.square")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete { indexSet in
                            viewModel.deleteFromGroup(group: group, at: indexSet)
                            triggerDebouncedSave()
                        }
                        
                        Button(action: {
                            viewModel.addSet(to: group.name)
                            triggerDebouncedSave()
                        }) {
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
    }
    
    private var addExerciseSection: some View {
        Section {
            Button(action: { viewModel.showAddExerciseSheet = true }) {
                Label("Add New Exercise", systemImage: "dumbbell.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    private var notesSection: some View {
        Section("Notes") {
            TextField("Workout notes...", text: $viewModel.note)
                .onChange(of: viewModel.note) {
                    triggerDebouncedSave()
                }
        }
    }
}

// MARK: - Helper Views

struct RestTimerSection: View {
    @State private var timeRemaining: Int = 0
    @State private var timer: Timer? = nil
    @State private var isRunning = false
    
    let presets = [30, 60, 90, 120]
    
    var body: some View {
        Section("Rest Timer") {
            VStack(spacing: 15) {
                Text(formatTime(timeRemaining))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(timeRemaining > 0 ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                HStack(spacing: 20) {
                    if isRunning {
                        Button(action: pauseTimer) {
                            Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
                        }.tint(.orange)
                    } else {
                        Button(action: startTimer) {
                            Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }.tint(.green).disabled(timeRemaining == 0)
                    }
                    
                    Button(action: resetTimer) {
                        Label("Reset", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                    }.tint(.red)
                }
                .buttonStyle(.bordered)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(presets, id: \.self) { seconds in
                            Button("\(seconds)s") { setTime(seconds) }
                            .buttonStyle(.bordered).tint(.blue)
                        }
                        Button("+15s") { addTime(15) }.buttonStyle(.bordered)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .onDisappear {
            stopTimer()
        }
    }
    
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
            if timeRemaining > 0 { timeRemaining -= 1 }
            else { playAlertSound(); stopTimer() }
        }
    }
    
    func pauseTimer() { isRunning = false; timer?.invalidate(); timer = nil }
    func stopTimer() { isRunning = false; timer?.invalidate(); timer = nil }
    func resetTimer() { stopTimer(); timeRemaining = 0 }
    
    func playAlertSound() {
        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

struct EditExerciseRow: View {
    @Bindable var exercise: ExerciseEntry
    let index: Int
    let unitSystem: String
    // PERFORMANCE FIX: This callback no longer triggers a Parent State Update
    var onInputChanged: () -> Void
    
    var weightLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }
    var distLabel: String { unitSystem == UnitSystem.imperial.rawValue ? "mi" : "km" }
    
    var body: some View {
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
                Text("Set \(index + 1)").font(.caption).fontWeight(.bold).foregroundColor(.secondary).frame(width: 45, alignment: .leading)
                Divider()
                
                if exercise.isCardio {
                    HStack {
                        TextField("Dist", value: distBinding, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                            .onChange(of: exercise.distance) { onInputChanged() }
                        
                        Text(distLabel)
                        Spacer()
                        
                        TextField("Time", value: $exercise.duration, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .onChange(of: exercise.duration) { onInputChanged() }
                        
                        Text("min")
                    }.foregroundColor(.blue)
                } else {
                    HStack {
                        TextField("Reps", value: $exercise.reps, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                            .multilineTextAlignment(.trailing)
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                            .onChange(of: exercise.reps) { onInputChanged() }
                        
                        Text("reps").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text("x").foregroundColor(.secondary)
                        Spacer()
                        
                        TextField("Weight", value: weightBinding, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                            .onChange(of: exercise.weight) { onInputChanged() }
                        
                        Text(weightLabel).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            TextField("Add note...", text: $exercise.note)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 60)
                .onChange(of: exercise.note) { onInputChanged() }
        }
        .padding(.vertical, 2)
    }
}

struct AddExerciseSheet: View {
    @Binding var exercises: [ExerciseEntry]
    var workoutMuscles: Set<String>
    var profile: UserProfile
    
    @Environment(\.dismiss) var dismiss
    @Query(sort: \ExerciseDefinition.name) private var libraryExercises: [ExerciseDefinition]
    
    @State private var searchText = ""
    
    var filteredExercises: [ExerciseDefinition] {
        if searchText.isEmpty { return libraryExercises }
        return libraryExercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var recommendedExercises: [ExerciseDefinition] {
        libraryExercises.filter { ex in
            !Set(ex.muscleGroups).isDisjoint(with: workoutMuscles)
        }
    }
    
    var otherExercises: [ExerciseDefinition] {
        libraryExercises.filter { ex in
            Set(ex.muscleGroups).isDisjoint(with: workoutMuscles)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CustomExerciseForm(profile: profile, onSave: { newEx in
                            exercises.append(newEx)
                            dismiss()
                        })
                    } label: {
                        Label("Create New Exercise", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
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

struct ExerciseRow: View {
    let exercise: ExerciseDefinition
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(exercise.name).font(.headline).foregroundColor(.primary)
                    if !exercise.muscleGroups.isEmpty {
                        Text(exercise.muscleGroups.joined(separator: ", ")).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if exercise.isCardio {
                    Image(systemName: "heart.fill").foregroundColor(.red).font(.caption).padding(6).background(Color.red.opacity(0.1)).clipShape(Circle())
                } else {
                    Image(systemName: "dumbbell.fill").foregroundColor(.blue).font(.caption).padding(6).background(Color.blue.opacity(0.1)).clipShape(Circle())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CustomExerciseForm: View {
    @Environment(\.modelContext) private var modelContext
    var profile: UserProfile
    var onSave: (ExerciseEntry) -> Void
    
    @State private var name = ""
    @State private var isCardio = false
    @State private var note = ""
    
    @State private var saveToLibrary = false
    @State private var selectedMuscles: Set<String> = []
    
    var availableMuscles: [String] {
        let standard = Set(MuscleGroup.allCases.map { $0.rawValue })
        let custom = Set(profile.customMuscles.components(separatedBy: ","))
        let tracked = Set(profile.trackedMuscles.components(separatedBy: ","))
        
        let all = standard.union(custom).union(tracked)
        return Array(all.filter { !$0.isEmpty }).sorted()
    }
    
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
            
            if saveToLibrary {
                Section("Target Muscles (Required)") {
                    ForEach(availableMuscles, id: \.self) { muscle in
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
            
            Button("Add to Workout") {
                saveAndFinish()
            }
            .disabled(isInvalid)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Custom Exercise")
    }
    
    var isInvalid: Bool {
        if name.isEmpty { return true }
        if saveToLibrary && selectedMuscles.isEmpty { return true }
        return false
    }
    
    func saveAndFinish() {
        if saveToLibrary {
            let newDef = ExerciseDefinition(
                name: name,
                muscleGroups: Array(selectedMuscles),
                isCardio: isCardio
            )
            modelContext.insert(newDef)
        }
        
        let newEx = ExerciseEntry(
            name: name,
            isCardio: isCardio,
            note: note
        )
        onSave(newEx)
    }
}

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

struct MuscleSelectionList: View {
    @Binding var selectedMuscles: Set<String>
    var profile: UserProfile
    
    var availableMuscles: [String] {
        let standard = Set(MuscleGroup.allCases.map { $0.rawValue })
        let custom = Set(profile.customMuscles.components(separatedBy: ","))
        let tracked = Set(profile.trackedMuscles.components(separatedBy: ","))
        
        let all = standard.union(custom).union(tracked)
        return Array(all.filter { !$0.isEmpty }).sorted()
    }
    
    var body: some View {
        Form {
            Section {
                ForEach(availableMuscles, id: \.self) { muscle in
                    HStack {
                        Text(muscle)
                        Spacer()
                        if selectedMuscles.contains(muscle) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .fontWeight(.bold)
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
            } header: {
                Text("Select Muscles")
            } footer: {
                Text("These are auto-selected based on your Category, but you can customize them here.")
            }
        }
        .navigationTitle("Muscles")
        .navigationBarTitleDisplayMode(.inline)
    }
}
