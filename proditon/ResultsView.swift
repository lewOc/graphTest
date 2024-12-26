import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var resultsManager: ResultsManager
    @State private var selectedResult: TryOnResult?
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(resultsManager.results) { result in
                        GridItemView(result: result)
                            .id("\(result.id)-\(result.status)-\(result.imageUrl)")
                            .onTapGesture {
                                selectedResult = result
                            }
                    }
                }
                .padding(1)
            }
            .refreshable {
                await resultsManager.refreshResults()
            }
            .navigationTitle("Results")
            .navigationDestination(item: $selectedResult) { result in
                FullScreenResultView(initialResult: result)
            }
        }
    }
}

struct GridItemView: View {
    let result: TryOnResult
    @EnvironmentObject private var resultsManager: ResultsManager
    
    var body: some View {
        Group {
            switch result.status {
            case .processing:
                ProgressView()
                    .frame(minWidth: 100, minHeight: 100)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
            case .completed:
                if let localPath = result.localImagePath,
                   let image = UIImage(contentsOfFile: localPath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .onAppear {
                            print("📱 Loading from local path: \(localPath)")
                        }
                } else if !result.imageUrl.isEmpty {
                    AsyncImage(url: URL(string: result.imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .onAppear {
                                    print("⚠️ No local path found, falling back to CDN: \(result.imageUrl)")
                                    print("🔄 Loading image: \(result.imageUrl)")
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .onAppear {
                                    print("✅ Loaded image from CDN: \(result.imageUrl)")
                                }
                        case .failure(let error):
                            Image(systemName: "photo")
                                .foregroundStyle(.gray)
                                .onAppear {
                                    print("❌ Failed to load from CDN: \(error.localizedDescription)")
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .transition(.opacity)
                } else {
                    ProgressView()
                        .frame(minWidth: 100, minHeight: 100)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 30))
                    .foregroundStyle(.red)
                    .frame(minWidth: 100, minHeight: 100)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(minWidth: 100, minHeight: 100)
        .clipped()
        .id("\(result.id)-\(result.imageUrl)") // Force refresh when either id or url changes
    }
}

struct FullScreenResultView: View {
    @EnvironmentObject private var resultsManager: ResultsManager
    @Environment(\.dismiss) private var dismiss
    let initialResult: TryOnResult
    @State private var currentIndex: Int = 0
    @State private var isUIHidden = false
    private let thumbnailHeight: CGFloat = 40
    private let thumbnailWidth: CGFloat = 55
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(resultsManager.results.enumerated()), id: \.element.id) { index, result in
                    AsyncImage(url: URL(string: result.imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundStyle(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .tag(index)
                }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isUIHidden.toggle()
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Thumbnail scroller
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 2) {
                                ForEach(Array(resultsManager.results.enumerated()), id: \.element.id) { index, result in
                                    AsyncImage(url: URL(string: result.imageUrl)) { phase in
                                        switch phase {
                                        case .empty, .failure:
                                            Rectangle()
                                                .fill(.gray.opacity(0.3))
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                                    .scaleEffect(currentIndex == index ? 1.1 : 1.0)
                                    .id(index)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            currentIndex = index
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                        .onChange(of: currentIndex) { newIndex in
                            withAnimation {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                    
                    // Updated Controls
                    HStack {
                        Button(action: deleteCurrentImage) {
                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .foregroundStyle(.primary)
                                .frame(width: 70, height: 30)
                                .background(.gray.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        Button(action: saveToPhotos) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18))
                                .foregroundStyle(.primary)
                                .frame(width: 70, height: 30)
                                .background(.gray.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // Placeholder action for hanger button
                        }) {
                            Image(systemName: "hanger")
                                .font(.system(size: 18))
                                .foregroundStyle(.primary)
                                .frame(width: 70, height: 30)
                                .background(.gray.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 20)
                    .background(.ultraThinMaterial)
                }
                .opacity(isUIHidden ? 0 : 1)
                .offset(y: isUIHidden ? 100 : 0)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
        .toolbar(isUIHidden ? .hidden : .automatic, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if let index = resultsManager.results.firstIndex(where: { $0.id == initialResult.id }) {
                currentIndex = index
            }
        }
        .alert("Delete Image", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                print("❌ Delete cancelled")
            }
            Button("Delete", role: .destructive) {
                print("⚠️ Confirming delete for result at index: \(currentIndex)")
                let resultToDelete = resultsManager.results[currentIndex]
                resultsManager.deleteResult(resultToDelete)
                print("✅ Delete completed, dismissing view")
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this image? This action cannot be undone.")
        }
    }
    
    private func deleteCurrentImage() {
        print("🗑️ Delete button tapped for index: \(currentIndex)")
        showDeleteConfirmation = true
    }
    
    private func saveToPhotos() {
        guard let url = URL(string: resultsManager.results[currentIndex].imageUrl) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
            } catch {
                print("Error saving image: \(error)")
            }
        }
    }
}

#Preview {
    ResultsView()
} 
