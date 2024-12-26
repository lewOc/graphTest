import SwiftUI
import UIKit
import PhotosUI

// Add clothing type enum
enum ClothingType: String, CaseIterable {
    case tshirt = "T-Shirt"
    case trousers = "Trousers"
    case dress = "Dress"
    case accessory = "Accessory"
}

// Modify the SavedImagesModel to handle categories
class SavedImagesModel: ObservableObject {
    struct ClothingItem: Identifiable {
        let id = UUID()
        let image: UIImage
        let type: ClothingType
    }
    
    @Published var savedItems: [ClothingItem] = []
    
    func saveImage(_ image: UIImage, type: ClothingType) {
        savedItems.append(ClothingItem(image: image, type: type))
    }
    
    func itemsByType(_ type: ClothingType) -> [ClothingItem] {
        savedItems.filter { item in
            item.type == type
        }
    }
}

// Main App Structure
struct ContentView: View {
    @StateObject private var savedImagesModel = SavedImagesModel()
    
    var body: some View {
        TabView {
            EditorView()
                .environmentObject(savedImagesModel)
                .tabItem {
                    Label("Editor", systemImage: "pencil")
                }
            
            ResultsView()
                .environmentObject(savedImagesModel)
                .tabItem {
                    Label("Results", systemImage: "photo.on.rectangle")
                }
        }
    }
}

// Editor View (previously ContentView)
struct EditorView: View {
    @State private var selectedImages: [UIImage] = []
    @State private var currentImageIndex: Int = 0
    @State private var processedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showingSaveAlert = false
    @EnvironmentObject var savedImagesModel: SavedImagesModel
    @State private var showingCategoryPicker = false
    @State private var tempProcessedImage: UIImage?
    @State private var showingErrorAlert = false
    
    private func handleExtractionResult(_ image: UIImage?, completion: @escaping (ClothingType) -> Void) {
        if image == nil && !showingErrorAlert {
            // Show error alert for no mask
            showingErrorAlert = true
        } else {
            // Handle normal extraction or deletion
            tempProcessedImage = image
            if image != nil {
                showingCategoryPicker = true
            } else {
                // Handle deletion
                withAnimation {
                    selectedImages.remove(at: currentImageIndex)
                    if selectedImages.isEmpty {
                        currentImageIndex = 0
                    } else if currentImageIndex >= selectedImages.count {
                        currentImageIndex = selectedImages.count - 1
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !selectedImages.isEmpty {
                    // Show progress indicator
                    HStack {
                        Text("Image \(currentImageIndex + 1) of \(selectedImages.count)")
                        Spacer()
                        if currentImageIndex > 0 {
                            Button("Previous") {
                                withAnimation {
                                    currentImageIndex -= 1
                                    processedImage = nil
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        if currentImageIndex < selectedImages.count - 1 {
                            Button("Next") {
                                withAnimation {
                                    currentImageIndex += 1
                                    processedImage = nil
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Wrap SelectionView in a container that handles the swipe
                    ZStack {
                        SelectionView(
                            baseImage: selectedImages[currentImageIndex],
                            processedImage: $processedImage,
                            isDeleteAction: false
                        ) { image, completion in
                            handleExtractionResult(image, completion: completion)
                        }
                        .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
                        .id(currentImageIndex)
                        
                        // Add invisible overlay for swipe gesture only
                        Color.clear
                            .contentShape(Rectangle()) // Make the entire area tappable
                            .allowsHitTesting(false) // Disable hit testing to prevent interference
                    }
                }
                
                if processedImage != nil {
                    Image(uiImage: processedImage!)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                }
                
                Button(selectedImages.isEmpty ? "Select Images" : "Add More Images") {
                    showImagePicker = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Clothing Selector")
            .sheet(isPresented: $showImagePicker) {
                MultiImagePicker(images: $selectedImages)
            }
            .alert("Success", isPresented: $showingSaveAlert) {
                Button("OK", role: .cancel) {
                    // Force view refresh after clicking OK
                    withAnimation {
                        // Clear any remaining processed images
                        processedImage = nil
                        tempProcessedImage = nil
                        
                        // Force view to update with current image
                        if !selectedImages.isEmpty {
                            let currentImage = selectedImages[currentImageIndex]
                            selectedImages[currentImageIndex] = currentImage
                        }
                    }
                }
            } message: {
                Text("Image saved to Results")
            }
            .alert("No Selection", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please draw a mask around the item you want to extract")
            }
            .confirmationDialog(
                "Select Clothing Type",
                isPresented: $showingCategoryPicker,
                titleVisibility: .visible
            ) {
                ForEach(ClothingType.allCases, id: \.self) { type in
                    Button(type.rawValue) {
                        if let image = tempProcessedImage {
                            // Save the image first
                            savedImagesModel.saveImage(image, type: type)
                            
                            // Immediately clear UI state
                            processedImage = nil
                            tempProcessedImage = nil
                            showingCategoryPicker = false
                            
                            // Force immediate view update and remove current image
                            DispatchQueue.main.async {
                                withAnimation {
                                    // Remove the current image
                                    selectedImages.remove(at: currentImageIndex)
                                    
                                    // Update index if needed
                                    if selectedImages.isEmpty {
                                        currentImageIndex = 0
                                    } else if currentImageIndex >= selectedImages.count {
                                        currentImageIndex = selectedImages.count - 1
                                    }
                                    
                                    // Show save confirmation
                                    showingSaveAlert = true
                                }
                            }
                        }
                    }
                }
                
                Button("Cancel", role: .cancel) {
                    tempProcessedImage = nil
                    processedImage = nil
                }
            }
        }
    }
}

// New Results View
struct ResultsView: View {
    @EnvironmentObject var savedImagesModel: SavedImagesModel
    
    let columns = [
        GridItem(.adaptive(minimum: 150))
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                if savedImagesModel.savedItems.isEmpty {
                    ContentUnavailableView(
                        "No Saved Images",
                        systemImage: "photo.on.rectangle",
                        description: Text("Extracted images will appear here")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(ClothingType.allCases, id: \.self) { category in
                            if !savedImagesModel.itemsByType(category).isEmpty {
                                Section {
                                    LazyVGrid(columns: columns, spacing: 20) {
                                        ForEach(savedImagesModel.itemsByType(category)) { item in
                                            Image(uiImage: item.image)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(height: 200)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .shadow(radius: 5)
                                        }
                                    }
                                } header: {
                                    Text(category.rawValue)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .padding(.leading)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Saved Results")
        }
    }
}

// Selection View that handles drawing
struct SelectionView: UIViewRepresentable {
    let baseImage: UIImage
    @Binding var processedImage: UIImage?
    let isDeleteAction: Bool
    var onFinishDrawing: ((UIImage?, @escaping (ClothingType) -> Void) -> Void)?
    
    func makeUIView(context: Context) -> SelectionUIView {
        let view = SelectionUIView(image: baseImage)
        view.onFinishDrawing = { image, completion in
            // Update the processedImage on the main thread
            DispatchQueue.main.async {
                // Only set processedImage if we actually have an image
                if image != nil {
                    self.processedImage = image
                }
                if let onFinishDrawing = self.onFinishDrawing {
                    onFinishDrawing(image, completion)
                }
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: SelectionUIView, context: Context) {
        uiView.baseImage = baseImage
    }
}

// Core drawing and selection functionality
class SelectionUIView: UIView {
    var baseImage: UIImage
    var path = UIBezierPath()
    var points: [CGPoint] = []
    var isDrawing = false
    var onFinishDrawing: ((UIImage?, @escaping (ClothingType) -> Void) -> Void)?
    private var imageRect: CGRect = .zero
    private var magnifierView: UIView?
    private var pathHistory: [UIBezierPath] = []
    private var currentScale: CGFloat = 1.0
    
    init(image: UIImage) {
        self.baseImage = image
        super.init(frame: .zero)
        backgroundColor = .clear
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Calculate image rect maintaining aspect ratio
        let aspectRatio = baseImage.size.width / baseImage.size.height
        let height = bounds.height - 60 // Account for buttons
        let width = height * aspectRatio
        
        imageRect = CGRect(
            x: (bounds.width - width) / 2,
            y: 0,
            width: width,
            height: height
        )
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        // Draw image in calculated rect
        baseImage.draw(in: imageRect)
        
        UIColor.blue.setStroke()
        path.lineWidth = 2
        path.stroke()
    }
    
    private func convertPointToImageSpace(_ point: CGPoint) -> CGPoint {
        let scale = baseImage.size.width / imageRect.width
        return CGPoint(
            x: (point.x - imageRect.minX) * scale,
            y: (point.y - imageRect.minY) * scale
        )
    }
    
    @objc private func extractSelection() {
        // Check if path is empty (no mask drawn)
        if path.isEmpty {
            // Notify SwiftUI view about the error with nil image
            onFinishDrawing?(nil) { _ in }
            return
        }
        
        // Create a context with the original image size
        UIGraphicsBeginImageContextWithOptions(baseImage.size, false, baseImage.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Scale and transform the path to match image coordinates
        let scale = baseImage.size.width / self.imageRect.width
        let transform = CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: -self.imageRect.minX, y: -self.imageRect.minY)
        
        guard let scaledPath = path.copy() as? UIBezierPath else { return }
        scaledPath.apply(transform)
        
        // Create path-shaped mask
        context.saveGState()
        
        // Clear the context and set up for transparency
        context.clear(CGRect(origin: .zero, size: baseImage.size))
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(origin: .zero, size: baseImage.size))
        
        // Create the mask shape
        scaledPath.addClip()
        
        // Draw only the image portion inside the path
        baseImage.draw(in: CGRect(origin: .zero, size: baseImage.size))
        
        // Get the masked image
        let maskedImage = UIGraphicsGetImageFromCurrentImageContext()
        context.restoreGState()
        UIGraphicsEndImageContext()
        
        // Calculate the minimum rectangle that contains the path
        let boundingBox = scaledPath.bounds
        
        // Create final image with exact path shape
        UIGraphicsBeginImageContextWithOptions(boundingBox.size, false, baseImage.scale)
        
        // Draw the masked image, offset by the bounding box origin to crop
        maskedImage?.draw(at: CGPoint(x: -boundingBox.minX, y: -boundingBox.minY))
        
        // Get the final image
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let finalImage = finalImage {
            onFinishDrawing?(finalImage) { selectedType in
                // This will be handled in the SwiftUI view
            }
        }
    }
    
    private func setupUI() {
        // Change Clear to Delete with bin icon
        let deleteButton = UIButton(type: .system)
        let binImage = UIImage(systemName: "trash.fill")
        deleteButton.setImage(binImage, for: .normal)
        deleteButton.addTarget(self, action: #selector(deleteCurrentImage), for: .touchUpInside)
        
        // Change Undo to Clear Mask
        let clearMaskButton = UIButton(type: .system)
        clearMaskButton.setTitle("Clear Mask", for: .normal)
        clearMaskButton.addTarget(self, action: #selector(clearMask), for: .touchUpInside)
        
        let extractButton = UIButton(type: .system)
        extractButton.setTitle("Extract", for: .normal)
        extractButton.addTarget(self, action: #selector(extractSelection), for: .touchUpInside)
        
        let stackView = UIStackView(arrangedSubviews: [deleteButton, clearMaskButton, extractButton])
        stackView.spacing = 20
        stackView.distribution = .fillEqually
        
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true
        
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.8)
        ])
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            currentScale = 1.0
        case .changed:
            let delta = gesture.scale - currentScale
            currentScale = gesture.scale
            
            // Update the view's transform
            let transform = CGAffineTransform(scaleX: currentScale, y: currentScale)
            self.transform = transform
            
        case .ended:
            // Reset scale but maintain position
            UIView.animate(withDuration: 0.3) {
                self.transform = .identity
            }
        default:
            break
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        
        guard imageRect.contains(point) else { return }
        
        // Show magnifier before starting to draw
        showMagnifier(at: point)
        
        isDrawing = true
        points = [point]
        path = UIBezierPath()
        path.move(to: point)
        setNeedsDisplay()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawing, let touch = touches.first else { return }
        let point = touch.location(in: self)
        
        // Update magnifier while drawing
        updateMagnifier(at: point)
        
        points.append(point)
        path.addLine(to: point)
        setNeedsDisplay()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Remove magnifier when done drawing
        magnifierView?.removeFromSuperview()
        magnifierView = nil
        
        guard isDrawing else { return }
        isDrawing = false
        
        if let firstPoint = points.first {
            path.addLine(to: firstPoint)
            path.close()
            pathHistory.append(path.copy() as! UIBezierPath)
            setNeedsDisplay()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Make sure to remove magnifier if touch is cancelled
        magnifierView?.removeFromSuperview()
        magnifierView = nil
        isDrawing = false
    }
    
    private func showMagnifier(at point: CGPoint) {
        magnifierView?.removeFromSuperview()
        
        let magnifier = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        magnifier.backgroundColor = .white
        magnifier.layer.cornerRadius = 40
        magnifier.layer.borderWidth = 1
        magnifier.layer.borderColor = UIColor.gray.cgColor
        magnifier.layer.shadowColor = UIColor.black.cgColor
        magnifier.layer.shadowOffset = CGSize(width: 0, height: 2)
        magnifier.layer.shadowRadius = 4
        magnifier.layer.shadowOpacity = 0.25
        magnifier.clipsToBounds = true
        
        let magnifiedImage = UIImageView(frame: magnifier.bounds)
        magnifiedImage.contentMode = .scaleAspectFill
        magnifier.addSubview(magnifiedImage)
        
        // Position magnifier above touch point
        magnifier.center = CGPoint(x: point.x, y: point.y - 100)
        
        addSubview(magnifier)
        magnifierView = magnifier
        updateMagnifier(at: point)
    }
    
    private func updateMagnifier(at point: CGPoint) {
        guard let magnifier = magnifierView,
              let imageView = magnifier.subviews.first as? UIImageView else { return }
        
        // Update position
        magnifier.center = CGPoint(x: point.x, y: point.y - 100)
        
        // Create magnified content
        let scale: CGFloat = 2.0
        let size = CGSize(width: magnifier.bounds.width * scale,
                         height: magnifier.bounds.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        if let context = UIGraphicsGetCurrentContext() {
            context.translateBy(x: size.width / 2 - point.x * scale,
                              y: size.height / 2 - point.y * scale)
            context.scaleBy(x: scale, y: scale)
            layer.render(in: context)
            
            imageView.image = UIGraphicsGetImageFromCurrentImageContext()
        }
    }
    
    @objc private func undoLastPath() {
        if !pathHistory.isEmpty {
            pathHistory.removeLast()
            path = pathHistory.last ?? UIBezierPath()
            setNeedsDisplay()
        }
    }
    
    private func addSelectionFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    @objc private func deleteCurrentImage() {
        // Use closure to communicate deletion with SwiftUI view
        onFinishDrawing?(nil) { _ in }
    }
    
    @objc private func clearMask() {
        path = UIBezierPath()
        points = []
        pathHistory = []
        setNeedsDisplay()
    }
}

// Add gesture recognizer delegate
extension SelectionUIView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                          shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow pinch gesture to work simultaneously with touch drawing
        return gestureRecognizer is UIPinchGestureRecognizer
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Only handle pinch gesture when not drawing
        if gestureRecognizer is UIPinchGestureRecognizer {
            return !isDrawing
        }
        return true
    }
}

// Helper extension to create a CGImage mask
extension CGImage {
    static func create(maskFrom image: UIImage) -> CGImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Create a data provider from the image data
        guard let dataProvider = cgImage.dataProvider else { return nil }
        
        // Create a mask from the data provider
        return CGImage(
            maskWidth: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: cgImage.bytesPerRow,
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false
        )
    }
}

// Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// New MultiImagePicker to handle multiple image selection
struct MultiImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // 0 means no limit
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiImagePicker
        
        init(_ parent: MultiImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss the picker
            parent.presentationMode.wrappedValue.dismiss()
            
            guard !results.isEmpty else { return }
            
            // Clear existing images
            DispatchQueue.main.async {
                self.parent.images.removeAll()
            }
            
            // Create a dictionary to maintain order
            var orderedImages: [Int: UIImage] = [:]
            let group = DispatchGroup()
            
            // Load each selected image
            for (index, result) in results.enumerated() {
                group.enter()
                
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                        defer { group.leave() }
                        
                        if let image = image as? UIImage {
                            orderedImages[index] = image
                        }
                    }
                } else {
                    group.leave()
                }
            }
            
            // When all images are loaded, update the binding in correct order
            group.notify(queue: .main) { [weak self] in
                let sortedImages = orderedImages.sorted { $0.key < $1.key }.map { $0.value }
                self?.parent.images = sortedImages
            }
        }
    }
}
