import SwiftUI
import UIKit

struct ImageMaskingView: View {
    let originalImage: UIImage
    @Binding var maskedImage: UIImage?
    @State private var showingCategoryPicker = false
    @StateObject private var wardrobeManager = WardrobeManager.shared
    @Environment(\.dismiss) private var dismiss
    let currentIndex: Int
    let totalCount: Int
    
    var body: some View {
        NavigationStack {
            VStack {
                if totalCount > 1 {
                    Text("Image \(currentIndex + 1) of \(totalCount)")
                        .foregroundStyle(.secondary)
                        .padding(.top)
                }
                
                SelectionView(
                    baseImage: originalImage,
                    processedImage: $maskedImage,
                    isDeleteAction: false
                ) { extractedImage, completion in
                    if let image = extractedImage {
                        maskedImage = image
                        showingCategoryPicker = true
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Select Category", isPresented: $showingCategoryPicker) {
            ForEach(ClothingItem.ClothingCategory.allCases, id: \.self) { category in
                Button(category.rawValue) {
                    saveItem(with: category)
                }
            }
            Button("Cancel", role: .cancel) {
                maskedImage = nil
            }
        } message: {
            Text("What type of clothing item is this?")
        }
    }
    
    private func saveItem(with category: ClothingItem.ClothingCategory) {
        guard let maskedImage = maskedImage else { return }
        
        // Immediately dismiss and move to next image
        dismiss()
        
        // Save in background
        Task {
            do {
                let _ = try await wardrobeManager.addItem(
                    image: maskedImage,
                    originalImage: originalImage,
                    category: category
                )
            } catch {
                print("Failed to save item: \(error)")
            }
        }
    }
}

struct SelectionView: UIViewRepresentable {
    let baseImage: UIImage
    @Binding var processedImage: UIImage?
    let isDeleteAction: Bool
    let onFinishDrawing: (UIImage?, @escaping (ClothingItem.ClothingCategory) -> Void) -> Void
    
    func makeUIView(context: Context) -> SelectionUIView {
        let view = SelectionUIView(image: baseImage)
        view.onFinishDrawing = { [weak view] image, completion in
            guard let view = view else { return }
            if let image = image {
                processedImage = image
            }
            onFinishDrawing(image, completion)
        }
        return view
    }
    
    func updateUIView(_ uiView: SelectionUIView, context: Context) {
        uiView.baseImage = baseImage
    }
}

class SelectionUIView: UIView {
    var baseImage: UIImage {
        didSet {
            // Resize image when it's set
            processedBaseImage = resizeImage(baseImage)
        }
    }
    private var processedBaseImage: UIImage // Store the resized image
    private var path = UIBezierPath()
    private var points: [CGPoint] = []
    private var isDrawing = false
    private var imageRect: CGRect = .zero
    private var pathHistory: [UIBezierPath] = []
    var onFinishDrawing: ((UIImage?, @escaping (ClothingItem.ClothingCategory) -> Void) -> Void)?
    
    // Add new properties for magnifier
    private var magnifierView: UIView?
    private var magnifierImageView: UIImageView?
    private let magnifierSize: CGFloat = 120
    private let magnificationScale: CGFloat = 2.0
    
    init(image: UIImage) {
        self.baseImage = image
        self.processedBaseImage = image
        super.init(frame: .zero)
        setupUI()
        setupMagnifier()
        backgroundColor = .systemBackground
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        let clearButton = UIButton(type: .system)
        clearButton.setTitle("Clear", for: .normal)
        clearButton.addTarget(self, action: #selector(clearMask), for: .touchUpInside)
        
        let extractButton = UIButton(type: .system)
        extractButton.setTitle("Extract", for: .normal)
        extractButton.addTarget(self, action: #selector(extractSelection), for: .touchUpInside)
        
        let stackView = UIStackView(arrangedSubviews: [clearButton, extractButton])
        stackView.spacing = 20
        stackView.distribution = .fillEqually
        
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.8)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let availableHeight = bounds.height - CGFloat(60)
        let availableWidth = bounds.width
        
        let imageSize = baseImage.size
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = availableWidth / availableHeight
        
        var drawWidth: CGFloat
        var drawHeight: CGFloat
        
        if imageAspect > viewAspect {
            drawWidth = availableWidth
            drawHeight = drawWidth / imageAspect
        } else {
            drawHeight = availableHeight
            drawWidth = drawHeight * imageAspect
        }
        
        let x = (availableWidth - drawWidth) / 2
        let y: CGFloat = 0
        
        imageRect = CGRect(x: x, y: y, width: drawWidth, height: drawHeight)
        setNeedsDisplay()
        
        // Update magnifier view when layout changes
        if let magnifierView = magnifierView {
            if magnifierView.superview == nil {
                window?.addSubview(magnifierView)
            }
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
        path.lineWidth = CGFloat(2.0)
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
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
    
    // Add this method to prevent scroll view interaction when drawing
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !isDrawing
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
    
    private func extractImage() {
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
            onFinishDrawing?(finalImage) { _ in }
        }
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
            onFinishDrawing?(finalImage) { _ in }
        }
    }
    
    @objc private func clearMask() {
        path = UIBezierPath()
        points = []
        pathHistory = []
        setNeedsDisplay()
    }
    
    // Add this method to resize large images
    private func resizeImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1200 // Maximum dimension we want to work with
        
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: min(size.width, maxDimension), 
                           height: min(size.width, maxDimension) / aspectRatio)
        } else {
            newSize = CGSize(width: min(size.height, maxDimension) * aspectRatio,
                           height: min(size.height, maxDimension))
        }
        
        // Only resize if the image is larger than our max dimension
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func setupMagnifier() {
        let magnifier = UIView(frame: CGRect(x: 0, y: 0, width: magnifierSize, height: magnifierSize))
        magnifier.backgroundColor = .white
        magnifier.layer.cornerRadius = magnifierSize / 2
        magnifier.layer.borderColor = UIColor.white.cgColor
        magnifier.layer.borderWidth = 3
        magnifier.layer.masksToBounds = true
        magnifier.isHidden = true
        
        let imageView = UIImageView(frame: magnifier.bounds)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        magnifier.addSubview(imageView)
        
        let shadowView = UIView(frame: magnifier.frame)
        shadowView.backgroundColor = .clear
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 2)
        shadowView.layer.shadowOpacity = 0.3
        shadowView.layer.shadowRadius = 4
        shadowView.addSubview(magnifier)
        
        addSubview(shadowView)
        
        self.magnifierView = magnifier
        self.magnifierImageView = imageView
    }
    
    deinit {
        magnifierView?.removeFromSuperview()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        processedBaseImage.draw(in: imageRect) // Use processed image for drawing
        
        UIColor.systemBlue.withAlphaComponent(0.3).setFill()
        UIColor.systemBlue.setStroke()
        
        for historicPath in pathHistory {
            historicPath.lineWidth = CGFloat(2)
            historicPath.stroke()
            historicPath.fill()
        }
        
        if isDrawing {
            path.lineWidth = CGFloat(2)
            path.stroke()
        }
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
} 