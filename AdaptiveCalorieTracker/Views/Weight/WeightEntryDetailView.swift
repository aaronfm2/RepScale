import SwiftUI
import PhotosUI
import SwiftData

struct WeightEntryDetailView: View {
    @Bindable var entry: WeightEntry
    var profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    
    // --- Image Handling State ---
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var showImageOptions = false
    @State private var showPhotoLibrary = false // Controls the Photos Picker presentation
    
    // --- Viewer & Delete State ---
    @State private var selectedPhotoData: Data? // For full-screen viewer
    @State private var showDeleteConfirmation = false
    @State private var photoToDelete: ProgressPhoto?
    
    let tags = ["Full Body", "Upper Body", "Arms", "Chest", "Back", "Shoulders", "Legs"]
    var weightLabel: String { profile.unitSystem == UnitSystem.imperial.rawValue ? "lbs" : "kg" }

    var body: some View {
        Form {
            Section("Details") {
                DatePicker("Date", selection: $entry.date)
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("Weight", value: $entry.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text(weightLabel).foregroundColor(.secondary)
                }
                TextField("Note", text: $entry.note, axis: .vertical)
            }
            
            Section("Progress Photos") {
                Button {
                    showImageOptions = true
                } label: {
                    Label("Add Photos", systemImage: "photo.badge.plus")
                }
                
                if let photos = entry.photos, !photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(photos) { photo in
                                PhotoRowView(
                                    photo: photo,
                                    tags: tags,
                                    selectedPhotoData: $selectedPhotoData,
                                    onDelete: {
                                        photoToDelete = photo
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
        .navigationTitle("Edit Log")
        
        // --- 1. Selection Dialog ---
        .confirmationDialog("Add Photo", isPresented: $showImageOptions) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Library") { showPhotoLibrary = true } // Triggers the picker below
            Button("Cancel", role: .cancel) { }
        }
        
        // --- 2. Camera Sheet ---
        .sheet(isPresented: $showCamera) {
            CameraPicker(selectedImage: $capturedImage)
        }
        
        // --- 3. Photo Library Picker (Hidden Trigger) ---
        .photosPicker(
            isPresented: $showPhotoLibrary,
            selection: $selectedItems,
            matching: .images
        )
        
        // --- 4. Delete Confirmation ---
        .confirmationDialog(
            "Delete Photo?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let photo = photoToDelete {
                    deletePhoto(photo)
                }
                photoToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                photoToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this photo? This action cannot be undone.")
        }
        
        // --- 5. Full Screen Viewer ---
        .fullScreenCover(item: Binding(
            get: { selectedPhotoData.map { IdentifiableData(data: $0) } },
            set: { selectedPhotoData = $0?.data }
        )) { viewer in
            FullScreenImageViewer(imageData: viewer.data)
        }
        
        // --- 6. Logic Handlers ---
        // Handle Camera Image
        .onChange(of: capturedImage) { _, image in
            if let image = image {
                saveImage(image)
            }
        }
        // Handle Library Selection
        .onChange(of: selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        saveImage(image)
                    }
                }
                // Clear selection so we can pick again later
                selectedItems.removeAll()
            }
        }
    }
    
    private func saveImage(_ image: UIImage) {
        // Apply watermark
        let watermarkedImage = image.addWatermark(text: "RepScale.App")
        
        if let data = watermarkedImage.jpegData(compressionQuality: 0.8) {
            let newPhoto = ProgressPhoto(imageData: data)
            newPhoto.weightEntry = entry
            modelContext.insert(newPhoto)
        }
    }
    
    private func deletePhoto(_ photo: ProgressPhoto) {
        if let index = entry.photos?.firstIndex(where: { $0 === photo }) {
            entry.photos?.remove(at: index)
        }
        modelContext.delete(photo)
    }
} // End of WeightEntryDetailView

// --- Subviews & Extensions ---

struct PhotoRowView: View {
    @Bindable var photo: ProgressPhoto
    let tags: [String]
    @Binding var selectedPhotoData: Data?
    var onDelete: () -> Void

    var body: some View {
        VStack {
            if let uiImage = UIImage(data: photo.imageData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .cornerRadius(8)
                        .onTapGesture {
                            selectedPhotoData = photo.imageData
                        }
                    
                    // Delete Button
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black.opacity(0.7))
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(Color(white: 0.95).opacity(0.85))
                            )
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .offset(x: 6, y: -6)
                }
                .padding(.top, 6)
                .padding(.trailing, 6)
            }
            
            Picker("Tag", selection: $photo.bodyTag) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag).tag(tag)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}

extension UIImage {
    func addWatermark(text: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            draw(in: CGRect(origin: .zero, size: size))
            
            let fontSize = size.height * 0.04
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .strokeColor: UIColor.black.withAlphaComponent(0.6),
                .strokeWidth: -3.0
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let padding = size.height * 0.03
            let rect = CGRect(
                x: size.width - textSize.width - padding,
                y: size.height - textSize.height - padding,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: rect, withAttributes: attributes)
        }
    }
}
