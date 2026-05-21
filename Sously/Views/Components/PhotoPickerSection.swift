import PhotosUI
import SwiftUI

struct PhotoPickerSection: View {
    @Binding var photoData: Data?
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        Section("Photo") {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if photoData == nil {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Add Photo", systemImage: "photo")
                }
            } else {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Change Photo", systemImage: "photo")
                }
            }
            if photoData != nil {
                Button("Remove Photo", role: .destructive) {
                    photoData = nil
                    pickerItem = nil
                }
            }
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
