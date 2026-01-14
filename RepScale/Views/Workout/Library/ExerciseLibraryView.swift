import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \ExerciseDefinition.name) private var exercises: [ExerciseDefinition]
    
    // UPDATED: Accept profile to access custom muscles
    var profile: UserProfile
    
    @State private var showingAddSheet = false
    @State private var exerciseToEdit: ExerciseDefinition?
    
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
                        .contentShape(Rectangle())
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
                // UPDATED: Pass profile
                ExerciseDefinitionSheet(profile: profile, exerciseToEdit: nil)
            }
            // Sheet for Editing (Existing)
            .sheet(item: $exerciseToEdit) { exercise in
                // UPDATED: Pass profile
                ExerciseDefinitionSheet(profile: profile, exerciseToEdit: exercise)
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
    
    // UPDATED: Accept profile
    var profile: UserProfile
    var exerciseToEdit: ExerciseDefinition?
    
    @State private var name = ""
    @State private var isCardio = false
    @State private var selectedMuscles: Set<String> = []
    
    // MARK: - FIX: Local Focus & Keyboard State
    @FocusState private var isInputFocused: Bool
    @State private var isKeyboardVisible = false
    
    // UPDATED: Combine Standard + Custom + Tracked muscles
    var availableMuscles: [String] {
        let standard = Set(MuscleGroup.allCases.map { $0.rawValue })
        let custom = Set(profile.customMuscles.components(separatedBy: ","))
        let tracked = Set(profile.trackedMuscles.components(separatedBy: ","))
        
        let all = standard.union(custom).union(tracked)
        return Array(all.filter { !$0.isEmpty }).sorted()
    }
    
    // UPDATED: Init now takes profile
    init(profile: UserProfile, exerciseToEdit: ExerciseDefinition? = nil) {
        self.profile = profile
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
            ZStack {
                Form {
                    Section("Exercise Details") {
                        TextField("Name (e.g. Bench Press)", text: $name)
                            .focused($isInputFocused)
                        Toggle("Is Cardio?", isOn: $isCardio)
                    }
                    
                    Section("Target Muscles") {
                        // UPDATED: Iterate over the combined list so Forearms shows up
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
                    
                    // Spacer for Keyboard
                    Section {
                        Color.clear.frame(height: 80)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // MARK: - Custom Keyboard Toolbar
                VStack {
                    Spacer()
                    if isKeyboardVisible {
                        VStack(spacing: 0) {
                            Divider()
                            HStack {
                                Spacer()
                                Button("Done") {
                                    hideKeyboard()
                                }
                                .bold()
                                .tint(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .background(.bar)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
            // MARK: - Keyboard Observers
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isKeyboardVisible = true
                    }
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isKeyboardVisible = false
                    }
                }
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
