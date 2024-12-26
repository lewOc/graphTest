import SwiftUI
import PhotosUI

struct ImageSelectionBox: View {
    let title: String
    let image: UIImage?
    @Binding var imageSelection: PhotosPickerItem?
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            PhotosPicker(selection: $imageSelection, matching: .images) {
                Group {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .overlay {
                                Image(systemName: "plus")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 150, height: 150)
            }
            .accessibilityLabel("Select \(title)")
        }
    }
} 