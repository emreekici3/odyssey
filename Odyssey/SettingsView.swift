import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var manager: DownloadManager
    @Environment(\.dismiss) var dismiss
    @State private var showingFolderPicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider().background(Color.white.opacity(0.06))

            ScrollView {
                VStack(spacing: 20) {
                    SettingsSection(title: "Download Directory") {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(Color(hex: "FF4757"))
                                .font(.system(size: 14))
                            Text(manager.outputFolder.path)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Change") { showingFolderPicker = true }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "FF4757"))
                                .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    SettingsSection(title: "About") {
                        VStack(spacing: 8) {
                            ClickableSettingsRow(icon: "info.circle", title: "Odyssey Version", subtitle: "1.0 - @emreekici3 (Github)", url: "https://github.com/emreekici3/odyssey")
                            ClickableSettingsRow(icon: "curlybraces", title: "Source Code", subtitle: "Source code is available for review only. Reproduction or redistribution is not permitted.", url: "https://github.com/yt-dlp/yt-dlp")
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 520)
        .background(Color(hex: "0D0D0F"))
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $showingFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                manager.outputFolder = url
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
                .textCase(.uppercase)
                .tracking(1)
            content()
        }
    }
}

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.7))
                Text(subtitle).font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
            }
            Spacer()
            trailing()
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ClickableSettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let url: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(isHovered ? Color(hex: "FF4757") : .white.opacity(0.4))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isHovered ? Color(hex: "FF4757") : .white.opacity(0.7))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 10))
                .foregroundColor(isHovered ? Color(hex: "FF4757") : .white.opacity(0.2))
        }
        .padding(12)
        .background(isHovered ? Color(hex: "FF4757").opacity(0.08) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isHovered ? Color(hex: "FF4757").opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        }
        .cursor(.pointingHand)
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
