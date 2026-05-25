import PhotosUI
import SwiftUI

struct PhotoPickerSection: View {
    @Binding var photoData: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingSourceDialog = false
    @State private var showingCamera = false

    var body: some View {
        Section("Photo") {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if CameraPicker.isAvailable {
                Button {
                    showingSourceDialog = true
                } label: {
                    Label(photoData == nil ? "Add Photo" : "Change Photo", systemImage: "camera")
                }
            } else {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(photoData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                }
            }

            if photoData != nil {
                Button("Remove Photo", role: .destructive) {
                    photoData = nil
                    pickerItem = nil
                }
            }
        }
        .confirmationDialog("Add Photo", isPresented: $showingSourceDialog, titleVisibility: .visible) {
            Button("Take Photo") { showingCamera = true }
            PhotosPicker("Choose from Library", selection: $pickerItem, matching: .images)
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(
                onCapture: { data in
                    photoData = data
                    showingCamera = false
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, newItem in
            Task { @MainActor in
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
    }
}
