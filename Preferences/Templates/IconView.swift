import SwiftUI

/// An `Image` view of an icon based on its UTI or bundle ID.
///
/// ```swift
/// IconView("com.example.app") // Example Bundle ID
/// IconView("com.example.graphic-icon.name") // Example UTI
/// ```
///
/// - Parameter icon: The `String` identifier of the image asset as a UTI or bundle ID.
///
/// - Note: If no bundle ID matches, it will return a template icon.
///
/// - Note: If no UTI matches, it will return a question mark on a doc icon.
///
/// - Warning: This view makes use of private methods. It is not recommended for public use.
struct IconView: View {
    let icon: String
    private var knownUTIPrefix: Bool {
        let lower = icon.lowercased()
        
        return icon.hasPrefix("com.apple.graphic")
            || lower.hasPrefix("com.apple.a")
            || lower.hasPrefix("com.apple.screen-time")
            || (icon.hasPrefix("com.apple.gamecenter") && !UIDevice.IsSimulated)
    }
    
    init(_ icon: String = "") {
        self.icon = icon
    }
    
    var body: some View {
        if knownUTIPrefix {
            if let graphicIcon = UIImage.icon(forUTI: icon) {
                Image(uiImage: graphicIcon)
            }
        } else if let asset = UIImage.icon(forBundleID: icon) {
            Image(uiImage: asset)
        } else if !icon.isEmpty {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(iconColor(for: icon))
                .clipShape(RoundedRectangle(cornerRadius: 6.5, style: .continuous))
        }
    }

    private func iconColor(for symbol: String) -> Color {
        if symbol.contains("sparkles") || symbol.contains("bubble") {
            return .blue
        } else if symbol.contains("note") || symbol.contains("slider") {
            return .orange
        } else if symbol.contains("character") || symbol.contains("book") {
            return .purple
        } else if symbol.contains("magnifyingglass") || symbol.contains("network") {
            return .teal
        } else if symbol.contains("wrench") || symbol.contains("hammer") {
            return .gray
        } else if symbol.contains("lock") || symbol.contains("shield") {
            return .green
        } else if symbol.contains("person") || symbol.contains("stethoscope") {
            return .indigo
        }
        return .blue
    }
}

#Preview {
    ContentView()
        .environment(PrimarySettingsListModel())
}
