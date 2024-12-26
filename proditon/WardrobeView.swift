import SwiftUI
import PhotosUI

struct WardrobeView: View {
    // MARK: - Properties
    @StateObject private var wardrobeManager = WardrobeManager.shared
    @State private var showingOutfitTryOn = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var loadingMessage = "Processing images..."
    @State private var showMaskingView = false
    @State private var selectedImageForMasking: UIImage?
    @State private var maskedImage: UIImage?
    @State private var currentImageSelection: [PhotosPickerItem] = []
    @State private var pendingImages: [UIImage] = []
    @State private var currentImageIndex: Int = 0
    @State private var isEditing = false
    @State private var selectedItems: Set<String> = []
    @State private var showingDeleteConfirmation = false
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    tryOnButton
                    addItemButton
                    topsSection
                    bottomsSection
                    dressSection
                    accessoriesSection
                    shoesSection
                    outfitsSection
                }
            }
            .navigationTitle("Wardrobe")
            .toolbar {
                Menu {
                    Button(action: {
                        isEditing.toggle()
                        if !isEditing {
                            selectedItems.removeAll()
                        }
                    }) {
                        Label(isEditing ? "Done" : "Edit", systemImage: isEditing ? "checkmark" : "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .overlay {
                if isLoading {
                    LoadingView(message: loadingMessage)
                }
            }
            .sheet(isPresented: $showingOutfitTryOn) {
                OutfitTryOnView()
                    .onDisappear {
                        Task {
                            await wardrobeManager.loadItems()
                        }
                    }
            }
            .sheet(isPresented: $showMaskingView, onDismiss: {
                if !pendingImages.isEmpty {
                    currentImageIndex += 1
                    if currentImageIndex < pendingImages.count {
                        selectedImageForMasking = pendingImages[currentImageIndex]
                        showMaskingView = true
                    } else {
                        pendingImages = []
                        currentImageIndex = 0
                    }
                }
            }) {
                if let selectedImageForMasking {
                    ImageMaskingView(
                        originalImage: selectedImageForMasking,
                        maskedImage: $maskedImage,
                        currentIndex: currentImageIndex,
                        totalCount: pendingImages.count
                    )
                }
            }
            .alert("Delete Items", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteSelectedItems()
                }
            } message: {
                Text("Are you sure you want to delete the selected items?")
            }
            .overlay(alignment: .bottom) {
                if isEditing && !selectedItems.isEmpty {
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Text("Delete Selected (\(selectedItems.count))")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - View Components
    private var tryOnButton: some View {
        HStack(spacing: 10) {
            // Left Button - Try On Item
            Button(action: { 
                // Placeholder action for now
            }) {
                HStack {
                    Image(systemName: "tshirt")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Try On Item")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            // Right Button - Try On Outfit
            Button(action: { showingOutfitTryOn = true }) {
                HStack {
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Try On Outfit")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private var addItemButton: some View {
        PhotosPicker(selection: $currentImageSelection,
                    maxSelectionCount: 10,
                    matching: .images,
                    photoLibrary: .shared()) {
            HStack {
                Image(systemName: "hanger")
                    .font(.system(size: 16, weight: .semibold))
                Text("Add Items")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .onChange(of: currentImageSelection) { oldValue, newValue in
            handleMultipleImageSelection(newValue)
        }
    }
    
    private var topsSection: some View {
        WardrobeSectionView(
            title: "Tops",
            items: wardrobeManager.items.filter { $0.category == .top },
            isEditing: $isEditing,
            selectedItems: $selectedItems
        )
    }
    
    private var bottomsSection: some View {
        WardrobeSectionView(
            title: "Trousers",
            items: wardrobeManager.items.filter { $0.category == .bottom },
            isEditing: $isEditing,
            selectedItems: $selectedItems
        )
    }
    
    private var dressSection: some View {
        WardrobeSectionView(
            title: "Dresses",
            items: wardrobeManager.items.filter { $0.category == .dress },
            isEditing: $isEditing,
            selectedItems: $selectedItems
        )
    }
    
    private var accessoriesSection: some View {
        WardrobeSectionView(
            title: "Accessories",
            items: wardrobeManager.items.filter { $0.category == .accessory },
            isEditing: $isEditing,
            selectedItems: $selectedItems
        )
    }
    
    private var shoesSection: some View {
        WardrobeSectionView(
            title: "Shoes",
            items: wardrobeManager.items.filter { $0.category == .shoes },
            isEditing: $isEditing,
            selectedItems: $selectedItems
        )
    }
    
    private var outfitsSection: some View {
        VStack(alignment: .leading) {
            Text("Outfits")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(250))], spacing: 16) {
                    if wardrobeManager.outfits.isEmpty {
                        Text("No outfits created yet")
                            .foregroundStyle(.secondary)
                            .frame(width: 180, height: 250)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        ForEach(wardrobeManager.outfits) { outfit in
                            OutfitItemView(outfit: outfit)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func handleMultipleImageSelection(_ selections: [PhotosPickerItem]) {
        guard !selections.isEmpty else { return }
        
        Task {
            do {
                // Convert all selections to images
                var images: [UIImage] = []
                for selection in selections {
                    if let data = try await selection.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                
                await MainActor.run {
                    pendingImages = images
                    currentImageIndex = 0
                    if let firstImage = images.first {
                        selectedImageForMasking = firstImage
                        showMaskingView = true
                    }
                    currentImageSelection = [] // Reset selection
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load images: \(error.localizedDescription)"
                    showError = true
                    currentImageSelection = [] // Reset selection
                }
            }
        }
    }
    
    private func deleteSelectedItems() {
        for itemId in selectedItems {
            if let item = wardrobeManager.items.first(where: { $0.id == itemId }) {
                wardrobeManager.deleteItem(item)
            }
        }
        selectedItems.removeAll()
        isEditing = false
    }
    
    private var sections: [(String, [ClothingItem])] {
        [
            ("Tops", wardrobeManager.items.filter { $0.category == .top }),
            ("Bottoms", wardrobeManager.items.filter { $0.category == .bottom }),
            ("Dresses", wardrobeManager.items.filter { $0.category == .dress }),
            ("Accessories", wardrobeManager.items.filter { $0.category == .accessory }),
            ("Shoes", wardrobeManager.items.filter { $0.category == .shoes })
        ]
    }
}

// MARK: - Supporting Views
struct WardrobeSectionView: View {
    let title: String
    let items: [ClothingItem]
    @Binding var isEditing: Bool
    @Binding var selectedItems: Set<String>
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(200))], spacing: 16) {
                    if items.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(items) { item in
                            ClothingItemView(
                                item: item,
                                isEditing: isEditing,
                                isSelected: selectedItems.contains(item.id),
                                onSelect: { itemId in
                                    if selectedItems.contains(itemId) {
                                        selectedItems.remove(itemId)
                                    } else {
                                        selectedItems.insert(itemId)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var emptyStateView: some View {
        Text("No \(title.lowercased()) added yet")
            .foregroundStyle(.secondary)
            .frame(width: 150, height: 200)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ClothingItemView: View {
    let item: ClothingItem
    let isEditing: Bool
    let isSelected: Bool
    let onSelect: (String) -> Void
    @StateObject private var wardrobeManager = WardrobeManager.shared
    @State private var showingDetail = false
    
    var body: some View {
        VStack {
            ZStack(alignment: .topLeading) {
                if let relativePath = item.localImagePath,
                   let image = UIImage(contentsOfFile: wardrobeManager.getAbsolutePath(for: relativePath)) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 150, height: 200)
                        .overlay {
                            ProgressView()
                        }
                }
                
                if isEditing {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title2)
                        .padding(8)
                        .background(Circle().fill(.white))
                        .padding(4)
                }
            }
        }
        .onTapGesture {
            if isEditing {
                onSelect(item.id)
            } else {
                showingDetail = true
            }
        }
        .sheet(isPresented: $showingDetail) {
            ClothingItemDetailView(item: item)
        }
    }
}

#Preview {
    WardrobeView()
} 