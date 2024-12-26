import SwiftUI

struct OutfitItemView: View {
    let outfit: Outfit
    @StateObject private var wardrobeManager: WardrobeManager
    @State private var showingDetail = false
    
    // Constants for preview size
    private let previewWidth: CGFloat = 180
    private let previewHeight: CGFloat = 250
    
    init(outfit: Outfit) {
        self.outfit = outfit
        _wardrobeManager = StateObject(wrappedValue: WardrobeManager.shared)
    }
    
    private func scalePosition(_ position: CGPoint, from sourceSize: CGSize, to targetSize: CGSize) -> CGPoint {
        return CGPoint(
            x: (position.x / sourceSize.width) * targetSize.width,
            y: (position.y / sourceSize.height) * targetSize.height
        )
    }
    
    var body: some View {
        VStack {
            if let relativePath = outfit.localImagePath,
               let image = UIImage(contentsOfFile: wardrobeManager.getAbsolutePath(for: relativePath)) {
                ZStack(alignment: .center) { 
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: previewWidth, height: previewHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Add accessories overlay with improved positioning
                    ForEach(outfit.accessories) { placement in
                        if let item = wardrobeManager.items.first(where: { $0.id == placement.itemId }),
                           let relativePath = item.localImagePath,
                           let accessoryImage = UIImage(contentsOfFile: wardrobeManager.getAbsolutePath(for: relativePath)) {
                            Image(uiImage: accessoryImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40 * placement.scale)
                                .position(scalePosition(
                                    placement.position,
                                    from: outfitImageSize,
                                    to: CGSize(width: previewWidth, height: previewHeight)
                                ))
                        }
                    }
                }
                .frame(width: previewWidth, height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: previewWidth, height: previewHeight)
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Creating your outfit...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let top = wardrobeManager.items.first(where: { $0.id == outfit.topItemId }),
                               let bottom = wardrobeManager.items.first(where: { $0.id == outfit.bottomItemId }) {
                                Text("\(top.category.rawValue) + \(bottom.category.rawValue)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
            }
        }
        .onTapGesture {
            if !outfit.isProcessing {
                showingDetail = true
            }
        }
        .sheet(isPresented: $showingDetail) {
            OutfitDetailView(outfit: outfit)
        }
    }
    
    // Reference size from OutfitDetailView
    private var outfitImageSize: CGSize {
        CGSize(width: UIScreen.main.bounds.width - 32, height: UIScreen.main.bounds.height * 0.6)
    }
} 