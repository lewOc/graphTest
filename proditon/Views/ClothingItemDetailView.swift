import SwiftUI

struct ClothingItemDetailView: View {
    let item: ClothingItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var wardrobeManager = WardrobeManager.shared
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if let relativePath = item.localImagePath,
                   let image = UIImage(contentsOfFile: wardrobeManager.getAbsolutePath(for: relativePath)) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
            .navigationTitle("\(item.category.rawValue) Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                wardrobeManager.deleteItem(item)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this item?")
        }
    }
}

#Preview {
    ClothingItemDetailView(item: ClothingItem(
        id: "preview",
        category: .top,
        imageUrl: "",
        localImagePath: nil,
        fullImagePath: nil,
        createdAt: Date()
    ))
} 