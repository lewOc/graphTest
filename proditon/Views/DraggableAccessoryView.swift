import SwiftUI

struct DraggableAccessoryView: View {
    let item: ClothingItem
    @Binding var position: CGPoint
    @Binding var scale: CGFloat
    let isSelected: Binding<Bool>
    
    @GestureState private var dragOffset = CGSize.zero
    @GestureState private var scaleAmount: CGFloat = 1.0
    
    private func loadImageWithTransparency(_ path: String) -> UIImage? {
        guard let image = UIImage(contentsOfFile: WardrobeManager.shared.getAbsolutePath(for: path)),
              let cgImage = image.cgImage else { return nil }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    var body: some View {
        if let path = item.localImagePath,
           let image = loadImageWithTransparency(path) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 100 * scale * scaleAmount)
                .position(CGPoint(
                    x: position.x + dragOffset.width,
                    y: position.y + dragOffset.height
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected.wrappedValue ? Color.blue : Color.clear, lineWidth: 2)
                )
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            position = CGPoint(
                                x: position.x + value.translation.width,
                                y: position.y + value.translation.height
                            )
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .updating($scaleAmount) { value, state, _ in
                            state = value
                        }
                        .onEnded { value in
                            scale *= value
                        }
                )
                .zIndex(100)
                .onAppear {
                    print("DraggableAccessoryView appeared for item: \(item.id)")
                    print("Position: \(position)")
                    print("Scale: \(scale)")
                }
        }
    }
} 