import SwiftUI

struct OutfitDetailView: View {
    let outfit: Outfit
    @Environment(\.dismiss) private var dismiss
    @StateObject private var wardrobeManager = WardrobeManager.shared
    @State private var selectedAccessories: Set<ClothingItem> = []
    @State private var showingAccessoryPicker = false
    @State private var accessoryPlacements: [AccessoryPlacement] = []
    @State private var selectedAccessoryId: String? = nil
    @State private var showingAccessoryOptions = false
    @State private var outfitImageSize: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button(action: {
                    showingAccessoryPicker = true
                }) {
                    HStack {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Add Accessories")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                ZStack(alignment: .center) {
                    // Base outfit image
                    ScrollView {
                        if let relativePath = outfit.localImagePath,
                           let image = UIImage(contentsOfFile: wardrobeManager.getAbsolutePath(for: relativePath)) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding()
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .onAppear {
                                                outfitImageSize = geo.size
                                                print("Outfit image size: \(geo.size)")
                                            }
                                            .onChange(of: geo.size) {
                                                outfitImageSize = geo.size
                                                print("Outfit image size updated: \(geo.size)")
                                            }
                                    }
                                )
                        }
                    }
                    
                    // Draggable accessories
                    ForEach(accessoryPlacements) { placement in
                        if let item = wardrobeManager.items.first(where: { $0.id == placement.itemId }) {
                            DraggableAccessoryView(
                                item: item,
                                position: binding(for: placement.id).position,
                                scale: binding(for: placement.id).scale,
                                isSelected: Binding(
                                    get: { selectedAccessoryId == placement.id },
                                    set: { _ in }
                                )
                            )
                            .onTapGesture {
                                selectedAccessoryId = placement.id
                                showingAccessoryOptions = true
                            }
                        }
                    }
                }
                .clipped() // Add this to ensure accessories stay within bounds
            }
            .onAppear {
                // Load existing accessories
                accessoryPlacements = outfit.accessories
                selectedAccessories = Set(wardrobeManager.items.filter { item in
                    outfit.accessories.contains { $0.itemId == item.id }
                })
            }
            .confirmationDialog(
                "Accessory Options",
                isPresented: $showingAccessoryOptions,
                presenting: selectedAccessoryId
            ) { id in
                Button("Remove", role: .destructive) {
                    removeAccessory(id: id)
                }
                Button("Bring to Front") {
                    bringToFront(id: id)
                }
                Button("Send to Back") {
                    sendToBack(id: id)
                }
                Button("Reset Size") {
                    resetScale(id: id)
                }
                Button("Cancel", role: .cancel) {
                    selectedAccessoryId = nil
                }
            }
            .navigationTitle("Outfit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        // TODO: Add delete functionality
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        // Save positions before dismissing
                        saveAccessoryPlacements()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAccessoryPicker) {
                AccessorySelectionView(selectedAccessories: $selectedAccessories)
                    .onDisappear {
                        print("AccessorySelectionView disappeared")
                        print("Selected accessories count: \(selectedAccessories.count)")
                        updateAccessoryPlacements()
                    }
            }
        }
    }
    
    private func binding(for id: String) -> (position: Binding<CGPoint>, scale: Binding<CGFloat>) {
        let index = accessoryPlacements.firstIndex(where: { $0.id == id })!
        return (
            position: Binding(
                get: { accessoryPlacements[index].position },
                set: { accessoryPlacements[index].position = $0 }
            ),
            scale: Binding(
                get: { accessoryPlacements[index].scale },
                set: { accessoryPlacements[index].scale = $0 }
            )
        )
    }
    
    private func removeAccessory(id: String) {
        if let index = accessoryPlacements.firstIndex(where: { $0.id == id }),
           let item = wardrobeManager.items.first(where: { $0.id == accessoryPlacements[index].itemId }) {
            accessoryPlacements.remove(at: index)
            selectedAccessories.remove(item)
            saveAccessoryPlacements()
        }
    }
    
    private func bringToFront(id: String) {
        guard let index = accessoryPlacements.firstIndex(where: { $0.id == id }) else { return }
        let placement = accessoryPlacements.remove(at: index)
        accessoryPlacements.append(placement)
        saveAccessoryPlacements()
    }
    
    private func sendToBack(id: String) {
        guard let index = accessoryPlacements.firstIndex(where: { $0.id == id }) else { return }
        let placement = accessoryPlacements.remove(at: index)
        accessoryPlacements.insert(placement, at: 0)
        saveAccessoryPlacements()
    }
    
    private func resetScale(id: String) {
        if let index = accessoryPlacements.firstIndex(where: { $0.id == id }) {
            accessoryPlacements[index].scale = 1.0
            saveAccessoryPlacements()
        }
    }
    
    private func saveAccessoryPlacements() {
        // Ensure we're using the correct image size
        guard outfitImageSize.width > 100 && outfitImageSize.height > 100 else {
            print("Warning: Invalid outfit image size for saving: \(outfitImageSize)")
            return
        }
        
        print("Saving accessory placements with size: \(outfitImageSize)")
        print("Saving placements: \(accessoryPlacements)")
        
        Task {
            await wardrobeManager.updateOutfitAccessories(
                outfitId: outfit.id,
                accessories: accessoryPlacements
            )
        }
    }
    
    private func updateAccessoryPlacements() {
        // Wait for the outfit image size to be properly set
        guard outfitImageSize.width > 100 && outfitImageSize.height > 100 else {
            // Delay the update if the size isn't ready yet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                updateAccessoryPlacements()
            }
            return
        }
        
        print("Updating accessory placements with size: \(outfitImageSize)")
        print("Current placements count: \(accessoryPlacements.count)")
        print("Selected accessories count: \(selectedAccessories.count)")
        
        // Remove placements for unselected accessories
        accessoryPlacements.removeAll { placement in
            !selectedAccessories.contains(where: { $0.id == placement.itemId })
        }
        
        // Add new placements for newly selected accessories
        for accessory in selectedAccessories {
            if !accessoryPlacements.contains(where: { $0.itemId == accessory.id }) {
                print("Adding new placement for accessory: \(accessory.id)")
                print("Current outfit image size: \(outfitImageSize)")
                
                // Calculate center point based on outfit image size
                let centerPoint = CGPoint(
                    x: outfitImageSize.width / 2,
                    y: outfitImageSize.height / 2
                )
                
                print("Placing accessory at: \(centerPoint)")
                
                accessoryPlacements.append(
                    AccessoryPlacement(
                        itemId: accessory.id,
                        position: centerPoint,
                        scale: 1.0
                    )
                )
            }
        }
        
        print("Final placements count: \(accessoryPlacements.count)")
        saveAccessoryPlacements()
    }
} 