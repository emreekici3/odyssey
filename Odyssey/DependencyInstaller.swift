import Foundation
import AppKit
import Combine

enum InstallStep: Equatable {
    case idle
    case waitingForConsent
    case declined
    case checkingBrew
    case installingBrew
    case installingYtdlp
    case installingFfmpeg
    case done
    case failed(String)

    var label: String {
        switch self {
        case .idle:               return "Checking status..."
        case .waitingForConsent:  return "Waiting for consent..."
        case .declined:           return "Installation declined"
        case .checkingBrew:       return "Checking Homebrew..."
        case .installingBrew:     return "Installing Homebrew..."
        case .installingYtdlp:    return "Installing yt-dlp..."
        case .installingFfmpeg:   return "Installing ffmpeg..."
        case .done:               return "Ready!"
        case .failed(let e):      return "Error: \(e)"
        }
    }

    var isWorking: Bool {
        switch self {
        case .checkingBrew, .installingBrew, .installingYtdlp, .installingFfmpeg: return true
        default: return false
        }
    }
}

@MainActor
class DependencyInstaller: ObservableObject {
    @Published var step: InstallStep = .idle
    @Published var log: String = ""
    @Published var isComplete: Bool = false
    @Published var progress: Double = 0

    private let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
    private var brewPath: String { brewPaths.first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/brew" }

    var isBrewInstalled: Bool { brewPaths.contains { FileManager.default.fileExists(atPath: $0) } }
    var isYtdlpInstalled: Bool { ["/opt/homebrew/bin/yt-dlp","/usr/local/bin/yt-dlp"].contains { FileManager.default.fileExists(atPath: $0) } }
    var isFfmpegInstalled: Bool { ["/opt/homebrew/bin/ffmpeg","/usr/local/bin/ffmpeg"].contains { FileManager.default.fileExists(atPath: $0) } }
    var needsInstallation: Bool { !isYtdlpInstalled || !isFfmpegInstalled }

    func runIfNeeded() async {
        guard needsInstallation else { step = .done; isComplete = true; return }
        step = .waitingForConsent
    }

    func userAccepted() async { await install() }
    func userDeclined() { step = .declined }

    func install() async {
        isComplete = false; log = ""; progress = 0
        step = .checkingBrew

        if !isBrewInstalled {
            step = .installingBrew
            appendLog("📦 Installing Homebrew...")
            let r = await run("/bin/bash", args: ["-c", #"NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#])
            if !r.ok { step = .failed("Failed to install Homebrew"); return }
            appendLog("✅ Homebrew installed")
        } else { appendLog("✅ Homebrew is ready") }
        progress = 0.2

        if !isYtdlpInstalled {
            step = .installingYtdlp
            appendLog("📦 Installing yt-dlp...")
            let r = await run(brewPath, args: ["install", "yt-dlp"])
            if !r.ok { step = .failed("Failed to install yt-dlp"); return }
            appendLog("✅ yt-dlp installed")
        } else { appendLog("✅ yt-dlp is ready") }
        progress = 0.6

        if !isFfmpegInstalled {
            step = .installingFfmpeg
            appendLog("📦 Installing ffmpeg...")
            let r = await run(brewPath, args: ["install", "ffmpeg"])
            if !r.ok { appendLog("⚠️ Failed to install ffmpeg") } else { appendLog("✅ ffmpeg installed") }
        } else { appendLog("✅ ffmpeg is ready") }
        progress = 1.0

        step = .done; isComplete = true
        appendLog("\n🎉 All set!")
    }

    private func run(_ exec: String, args: [String]) async -> (ok: Bool, out: String) {
        let logCB: (String) -> Void = { [weak self] t in DispatchQueue.main.async { self?.appendLog(t) } }
        return await withCheckedContinuation { cont in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: exec)
            p.arguments = args
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            p.environment = env
            let pipe = Pipe()
            p.standardOutput = pipe; p.standardError = pipe
            final class SafeBuffer: @unchecked Sendable {
                private var data = Data()
                private let lock = NSLock()
                func append(_ d: Data) { lock.lock(); data.append(d); lock.unlock() }
                var string: String { lock.lock(); defer { lock.unlock() }; return String(data: data, encoding: .utf8) ?? "" }
            }
            let buffer = SafeBuffer()
            pipe.fileHandleForReading.readabilityHandler = { h in
                let chunk = h.availableData
                buffer.append(chunk)
                if let s = String(data: chunk, encoding: .utf8), !s.isEmpty {
                    logCB(s.trimmingCharacters(in: .newlines))
                }
            }
            p.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                cont.resume(returning: (proc.terminationStatus == 0, buffer.string))
            }
            do { try p.run() } catch { cont.resume(returning: (false, error.localizedDescription)) }
        }
    }

    private func appendLog(_ text: String) {
        DispatchQueue.main.async { self.log += text + "\n" }
    }
}
