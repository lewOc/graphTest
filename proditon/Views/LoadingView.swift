import SwiftUI

struct LoadingView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text(message)
                    .foregroundColor(.white)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            }
            .padding(40)
        }
        .transition(.opacity)
    }
} 