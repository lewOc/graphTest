import SwiftUI

struct AccessorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var wardrobeManager = WardrobeManager.shared
    @Binding var selectedAccessories: Set<ClothingItem>
    
    private var accessories: [ClothingItem] {
        wardrobeManager.items.filter { $0.category == .accessory }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(accessories) { item in
                        AccessoryItemView(item: item, isSelected: selectedAccessories.contains(item)) {
                            if selectedAccessories.contains(item) {
                                selectedAccessories.remove(item)
                            } else {
                                selectedAccessories.insert(item)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Select Accessories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AccessoryItemView: View {
    let item: ClothingItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                if let path = item.localImagePath,
                   let image = UIImage(contentsOfFile: WardrobeManager.shared.getAbsolutePath(for: path)) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                        )
                        .compositingGroup()
                        .blendMode(.normal)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .background(Circle().fill(.white))
                        .padding(8)
                }
            }
        }
    }
} 