import Foundation
import AppKit
import Combine

enum VideoFormat: String, CaseIterable, Identifiable {
    case best  = "Best Quality"
    case h1080 = "1080p"
    case h720  = "720p"
    case h480  = "480p"
    case mp3   = "MP3 Audio"
    case m4a   = "M4A Audio"

    var id: String { rawValue }

    var ytdlpFormat: String {
        switch self {
        case .best:  return "bestvideo+bestaudio/best"
        case .h1080: return "bestvideo[height<=1080]+bestaudio/best[height<=1080]"
        case .h720:  return "bestvideo[height<=720]+bestaudio/best[height<=720]"
        case .h480:  return "bestvideo[height<=480]+bestaudio/best[height<=480]"
        case .mp3:   return "bestaudio"
        case .m4a:   return "bestaudio"
        }
    }

    var isAudioOnly: Bool { self == .mp3 || self == .m4a }
}

enum DownloadStatus {
    case pending
    case downloading(progress: Double, speed: String)
    case converting
    case done(path: String)
    case failed(error: String)
}

struct DownloadItem: Identifiable {
    let id = UUID()
    let url: String
    var title: String
    let format: VideoFormat
    var status: DownloadStatus
    let date: Date
    var outputPath: String?
}

@MainActor
class DownloadManager: ObservableObject {
    @Published var items: [DownloadItem] = []
    @Published var currentURL: String = ""
    @Published var selectedFormat: VideoFormat = .best
    @Published var outputFolder: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!

    private var processes: [UUID: Process] = [:]

    private var ffmpegPath: String {
        ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
            .first { FileManager.default.fileExists(atPath: $0) } ?? ""
    }

    func startDownload() {
        let urlStr = currentURL.trimmingCharacters(in: .whitespaces)
        guard !urlStr.isEmpty else { return }
        let item = DownloadItem(url: urlStr, title: urlStr, format: selectedFormat, status: .pending, date: Date())
        items.insert(item, at: 0)
        currentURL = ""
        performDownload(item: item)
    }

    private func performDownload(item: DownloadItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].status = .downloading(progress: 0, speed: "")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        var args: [String] = ["yt-dlp"]
        args += ["-o", outputFolder.appendingPathComponent("%(title)s.%(ext)s").path]
        args += ["-f", item.format.ytdlpFormat]

        if item.format == .mp3 {
            args += ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
        } else if item.format == .m4a {
            args += ["-x", "--audio-format", "m4a"]
        }

        if !ffmpegPath.isEmpty { args += ["--ffmpeg-location", ffmpegPath] }
        if !item.format.isAudioOnly { args += ["--merge-output-format", "mp4"] }
        args += ["--newline", "--progress", item.url]
        process.arguments = args

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let str = String(data: data, encoding: .utf8), !str.isEmpty else { return }
            DispatchQueue.main.async { self?.parseProgress(str, for: item.id) }
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let str = String(data: data, encoding: .utf8), !str.isEmpty else { return }
            DispatchQueue.main.async { self?.parseProgress(str, for: item.id) }
        }

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async { self?.handleTermination(proc, for: item.id) }
        }

        processes[item.id] = process
        do {
            try process.run()
        } catch {
            items[idx].status = .failed(error: "Could not start: \(error.localizedDescription)")
        }
    }

    private func parseProgress(_ output: String, for id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }

        for raw in output.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            for prefix in ["[download] Destination:", "[ExtractAudio] Destination:"] {
                if line.hasPrefix(prefix) {
                    let path = line.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespaces)
                    if !path.isEmpty && path != "/" {
                        items[idx].outputPath = path
                        items[idx].title = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                    }
                }
            }

            if line.contains("[Merger]") && line.contains("into \"") {
                if let start = line.range(of: "into \"")?.upperBound {
                    let after = String(line[start...])
                    let path = after.components(separatedBy: "\"").first ?? ""
                    if !path.isEmpty {
                        items[idx].outputPath = path
                        items[idx].title = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                    }
                }
            }

            if line.contains("[download]") && line.contains("%") {
                if let pctRange = line.range(of: #"(\d+\.?\d*)%"#, options: .regularExpression) {
                    let pct = Double(String(line[pctRange]).replacingOccurrences(of: "%", with: "")) ?? 0
                    var speed = ""
                    if let sRange = line.range(of: #"at\s+([\d.]+\s*\S+/s)"#, options: .regularExpression) {
                        speed = String(line[sRange]).replacingOccurrences(of: "at ", with: "")
                    }
                    items[idx].status = .downloading(progress: pct / 100.0, speed: speed)
                }
            }

            if line.lowercased().contains("merging") || line.lowercased().contains("converting") {
                items[idx].status = .converting
            }
        }
    }

    private func handleTermination(_ process: Process, for id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        processes.removeValue(forKey: id)

        guard process.terminationStatus == 0 else {
            items[idx].status = .failed(error: "Download failed (code: \(process.terminationStatus))")
            return
        }

        if let path = items[idx].outputPath, !path.isEmpty, path != "/",
           FileManager.default.fileExists(atPath: path) {
            items[idx].status = .done(path: path)
            return
        }

        let fm = FileManager.default
        let exts = Set(["mp4", "mkv", "webm", "mp3", "m4a", "mov"])
        if let files = try? fm.contentsOfDirectory(at: outputFolder, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles),
           let newest = files
            .filter({ exts.contains($0.pathExtension.lowercased()) })
            .compactMap({ url -> (URL, Date)? in
                guard let d = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate else { return nil }
                return (url, d)
            })
            .filter({ Date().timeIntervalSince($0.1) < 60 })
            .sorted(by: { $0.1 > $1.1 })
            .first {
            items[idx].outputPath = newest.0.path
            items[idx].title = newest.0.deletingPathExtension().lastPathComponent
            items[idx].status = .done(path: newest.0.path)
        } else {
            items[idx].status = .done(path: outputFolder.path)
        }
    }

    func cancelDownload(id: UUID) {
        processes[id]?.terminate()
        processes.removeValue(forKey: id)
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].status = .failed(error: "Cancelled")
        }
    }

    func removeItem(id: UUID) {
        cancelDownload(id: id)
        items.removeAll { $0.id == id }
    }

    func clearHistory() {
        items = items.filter {
            if case .downloading = $0.status { return true }
            if case .converting  = $0.status { return true }
            return false
        }
    }

    func revealInFinder(path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
}
