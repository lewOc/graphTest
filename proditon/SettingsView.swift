import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Settings View")
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
} 