import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var manager = DownloadManager()
    @StateObject private var wallpaper = WallpaperColor.shared
    @State private var showSettings = false
    @State private var showingFolderPicker = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0D0D0F"), Color(hex: "111318")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(colors: [
                        wallpaper.dominant.opacity(0.55),
                        wallpaper.dominant.opacity(0.15),
                        Color.clear,
                        wallpaper.dominant.opacity(0.1),
                        wallpaper.dominant.opacity(0.45),
                    ], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                TopBarView(manager: manager, showSettings: $showSettings)
                Divider().background(Color.white.opacity(0.06))
                URLInputView(manager: manager, showingFolderPicker: $showingFolderPicker)
                Divider().background(Color.white.opacity(0.06))
                DownloadListView(manager: manager)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView(manager: manager) }
        .fileImporter(isPresented: $showingFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { manager.outputFolder = url }
        }
        .preferredColorScheme(.dark)
    }
}

struct TopBarView: View {
    @ObservedObject var manager: DownloadManager
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                OdysseyLogo(size: 32)
                Text("Odyssey").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            }
            Spacer()
            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gear").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.6))
                    .frame(width: 30, height: 30).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}

struct URLInputView: View {
    @ObservedObject var manager: DownloadManager
    @Binding var showingFolderPicker: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "link").font(.system(size: 13)).foregroundColor(.white.opacity(0.3))
                    TextField("Paste video URL...", text: $manager.currentURL)
                        .textFieldStyle(.plain).font(.system(size: 13)).foregroundColor(.white)
                        .focused($isFocused)
                        .onSubmit { manager.startDownload() }
                    if !manager.currentURL.isEmpty {
                        Button(action: { manager.currentURL = "" }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                    isFocused ? Color(hex: "FF4757").opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1))

                Button(action: { manager.startDownload() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 13))
                        Text("Download").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white).padding(.horizontal, 18).padding(.vertical, 10)
                    .background(LinearGradient(
                        colors: manager.currentURL.isEmpty
                            ? [Color.gray.opacity(0.3), Color.gray.opacity(0.3)]
                            : [Color(hex: "FF4757"), Color(hex: "C0392B")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(manager.currentURL.isEmpty)
                .keyboardShortcut(.defaultAction)
            }

            HStack(spacing: 8) {
                Text("Format:").font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
                ForEach(VideoFormat.allCases) { format in
                    FormatChip(format: format, isSelected: manager.selectedFormat == format) {
                        manager.selectedFormat = format
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
            LinearGradient(colors: [Color(hex: "FF4757").opacity(0.6), Color(hex: "FF4757").opacity(0.1), Color.clear, Color(hex: "FF4757").opacity(0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        .shadow(color: Color(hex: "FF4757").opacity(0.15), radius: 12)
        .shadow(color: Color(hex: "FF4757").opacity(0.08), radius: 24)
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

struct FormatChip: View {
    let format: VideoFormat; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if format.isAudioOnly { Image(systemName: "music.note").font(.system(size: 9)) }
                Text(format.rawValue).font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.4))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(isSelected
                ? AnyView(LinearGradient(colors: [Color(hex: "FF4757").opacity(0.8), Color(hex: "C0392B").opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                : AnyView(Color.white.opacity(0.05)))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct DownloadListView: View {
    @ObservedObject var manager: DownloadManager
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Downloads").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.4)).textCase(.uppercase).tracking(1)
                if !manager.items.isEmpty {
                    Text("\(manager.items.count)").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Color.white.opacity(0.08)).clipShape(Capsule())
                }
                Spacer()
                if !manager.items.isEmpty {
                    Button("Clear History") { manager.clearHistory() }
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.3)).buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)

            if manager.items.isEmpty {
                EmptyStateView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(manager.items) { item in DownloadRowView(item: item, manager: manager) }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 16)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.dotted").font(.system(size: 40)).foregroundColor(.white.opacity(0.1))
            Text("No downloads yet").font(.system(size: 13)).foregroundColor(.white.opacity(0.2))
            Text("Paste a URL and hit Download").font(.system(size: 11)).foregroundColor(.white.opacity(0.1))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DownloadRowView: View {
    let item: DownloadItem
    @ObservedObject var manager: DownloadManager
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            StatusIconView(status: item.status)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title.isEmpty ? item.url : item.title)
                    .font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.85)).lineLimit(1)

                HStack(spacing: 8) {
                    Text(item.format.rawValue).font(.system(size: 10)).foregroundColor(Color(hex: "FF4757").opacity(0.8))
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Color(hex: "FF4757").opacity(0.1)).clipShape(Capsule())
                    Text(statusText).font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
                }

                if case .downloading(let progress, _) = item.status {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06)).frame(height: 3)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearGradient(colors: [Color(hex: "FF4757"), Color(hex: "FF6B81")], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * progress, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 6) {
                    if case .done(let path) = item.status {
                        Button(action: { manager.revealInFinder(path: path) }) {
                            Image(systemName: "folder.fill").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain).help("Show in Finder")
                    }
                    if case .downloading = item.status {
                        Button(action: { manager.cancelDownload(id: item.id) }) {
                            Image(systemName: "stop.circle.fill").font(.system(size: 12)).foregroundColor(Color(hex: "FF4757").opacity(0.7))
                        }
                        .buttonStyle(.plain).help("Cancel")
                    }
                    Button(action: { manager.removeItem(id: item.id) }) {
                        Image(systemName: "trash").font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain).help("Remove")
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.white.opacity(isHovered ? 0.06 : 0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    var statusText: String {
        switch item.status {
        case .pending: return "Pending..."
        case .downloading(let p, let speed): return speed.isEmpty ? "\(Int(p*100))%" : "\(Int(p*100))% · \(speed)"
        case .converting: return "Converting..."
        case .done: return "Completed ✓"
        case .failed(let err): return err
        }
    }
}

struct StatusIconView: View {
    let status: DownloadStatus

    var isDownloading: Bool {
        if case .downloading = status { return true }
        return false
    }
    var isConverting: Bool {
        if case .converting = status { return true }
        return false
    }
    var isActive: Bool { isDownloading || isConverting }

    var body: some View {
        ZStack {
            Circle().fill(iconBg).frame(width: 36, height: 36)
            if isActive {
                SpinningArc(color: arcColor, color2: arcColor2)
                    .id("arc-\(isActive)")
                PulseRing(color: arcColor)
                    .id("pulse-\(isActive)")
            }
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(iconColor)
        }
        .frame(width: 44, height: 44)
        .id(statusKey)
    }

    var statusKey: String {
        switch status {
        case .pending:     return "pending"
        case .downloading: return "downloading"
        case .converting:  return "converting"
        case .done:        return "done"
        case .failed:      return "failed"
        }
    }

    var arcColor:  Color { isConverting ? Color(hex: "F39C12") : Color(hex: "FF4757") }
    var arcColor2: Color { isConverting ? Color(hex: "F1C40F") : Color(hex: "FF6B81") }

    var iconName: String {
        switch status {
        case .pending:     return "clock"
        case .downloading: return "arrow.down"
        case .converting:  return "waveform"
        case .done:        return "checkmark"
        case .failed:      return "exclamationmark"
        }
    }
    var iconColor: Color {
        switch status {
        case .pending:     return .white.opacity(0.3)
        case .downloading: return Color(hex: "FF4757")
        case .converting:  return Color(hex: "F39C12")
        case .done:        return Color(hex: "2ECC71")
        case .failed:      return Color(hex: "FF4757")
        }
    }
    var iconBg: Color {
        switch status {
        case .pending:     return .white.opacity(0.05)
        case .downloading: return Color(hex: "FF4757").opacity(0.12)
        case .converting:  return Color(hex: "F39C12").opacity(0.12)
        case .done:        return Color(hex: "2ECC71").opacity(0.15)
        case .failed:      return Color(hex: "FF4757").opacity(0.12)
        }
    }
}

struct SpinningArc: View {
    let color: Color
    let color2: Color
    @State private var rotation: Double = 0
    var body: some View {
        Circle()
            .trim(from: 0.05, to: 0.75)
            .stroke(
                AngularGradient(colors: [color, color2, Color.clear], center: .center),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .frame(width: 36, height: 36)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                rotation = 0
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            .onDisappear { rotation = 0 }
    }
}

struct PulseRing: View {
    let color: Color
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.5
    var body: some View {
        Circle()
            .stroke(color.opacity(opacity), lineWidth: 1.5)
            .frame(width: 36, height: 36)
            .scaleEffect(scale)
            .onAppear {
                scale = 1.0
                opacity = 0.5
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    scale = 1.6
                    opacity = 0
                }
            }
            .onDisappear {
                scale = 1.0
                opacity = 0
            }
    }
}

func timeAgo(_ date: Date) -> String {
    let secs = Int(Date().timeIntervalSince(date))
    if secs < 60 { return "\(secs)s ago" }
    if secs < 3600 { return "\(secs/60)m ago" }
    return "\(secs/3600)h ago"
}

struct OdysseyLogo: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.44)
                .fill(Color(hex: "FF4757").opacity(0.35))
                .frame(width: size * 1.25, height: size * 1.25)
                .blur(radius: size * 0.25)

            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(LinearGradient(
                    colors: [Color(hex: "FF5F6D"), Color(hex: "D92B3A")],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: size, height: size)

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: size * 0.72, height: size * 0.72)

            Image(systemName: "arrow.down")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
