import SwiftUI

struct FullScreenImageViewer: View {
    let imageData: Data
    @Environment(\.dismiss) var dismiss
    
    // Alert state
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
            }
            .toolbar {
                // Move Close to leading for better UX
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
                
                // Add Save button to trailing
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        savePhoto()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.white)
                    }
                }
            }
            .alert("Save Photo", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func savePhoto() {
        guard let uiImage = UIImage(data: imageData) else { return }
        let imageSaver = ImageSaver()
        imageSaver.successHandler = {
            alertMessage = "Photo saved to your Camera Roll."
            showingAlert = true
        }
        imageSaver.errorHandler = { error in
            alertMessage = "Error saving photo: \(error.localizedDescription)"
            showingAlert = true
        }
        imageSaver.writeToPhotoAlbum(image: uiImage)
    }
}

// --- Helper Classes ---

// Helper to bridge to Objective-C selector API for saving images
class ImageSaver: NSObject {
    var successHandler: (() -> Void)?
    var errorHandler: ((Error) -> Void)?
    
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }
    
    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            errorHandler?(error)
        } else {
            successHandler?()
        }
    }
}

// Helper wrapper to make Data identifiable for sheets
struct IdentifiableData: Identifiable {
    let id = UUID()
    let data: Data
}
