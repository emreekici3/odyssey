import AppKit
import SwiftUI
import Combine

@MainActor
class WallpaperColor: ObservableObject {
    @Published var dominant: Color = Color(hex: "FF4757")
    static let shared = WallpaperColor()

    private init() {
        Task { await self.performRefresh() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performRefresh()
            }
        }
    }

    private func performRefresh() async {
        guard let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return }
        let color = await Task.detached(priority: .utility) {
            WallpaperColorExtractor.extract(from: url)
        }.value
        self.dominant = color
    }
}

enum WallpaperColorExtractor: Sendable {
    static func extract(from url: URL) -> Color {
        guard let img = NSImage(contentsOf: url),
              let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return Color(hex: "FF4757") }

        let size = 48
        var data = [UInt8](repeating: 0, count: size * size * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &data, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size * 4, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return Color(hex: "FF4757") }

        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))

        var rT: CGFloat = 0, gT: CGFloat = 0, bT: CGFloat = 0, n: CGFloat = 0
        for i in stride(from: 0, to: data.count, by: 4) {
            let r = CGFloat(data[i])   / 255
            let g = CGFloat(data[i+1]) / 255
            let b = CGFloat(data[i+2]) / 255
            let br  = (r + g + b) / 3
            let sat = max(r, g, b) - min(r, g, b)
            guard br > 0.08, br < 0.92, sat > 0.12 else { continue }
            rT += r; gT += g; bT += b; n += 1
        }
        guard n > 0 else { return Color(hex: "FF4757") }

        let ns = NSColor(red: rT/n, green: gT/n, blue: bT/n, alpha: 1)
            .usingColorSpace(.sRGB) ?? NSColor(red: rT/n, green: gT/n, blue: bT/n, alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &br, alpha: &a)
        return Color(NSColor(hue: h, saturation: min(s*1.5,1), brightness: max(br,0.5), alpha: 1))
    }
}
