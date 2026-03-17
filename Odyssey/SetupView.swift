import SwiftUI

struct SetupView: View {
    @ObservedObject var installer: DependencyInstaller
    @State private var logExpanded = false
    @State private var dotCount = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0D0D0F"), Color(hex: "111318")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            if case .waitingForConsent = installer.step {
                ConsentView(installer: installer).transition(.opacity)
            } else if case .declined = installer.step {
                DeclinedView(installer: installer).transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    Spacer()

                    ZStack {
                        Circle().fill(Color(hex: "FF4757").opacity(0.08)).frame(width: 100, height: 100)
                        Circle().fill(Color(hex: "FF4757").opacity(0.12)).frame(width: 80, height: 80)
                        Image(systemName: stepIcon)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                    .padding(.bottom, 24)

                    Text(stepTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.bottom, 8)

                    Text(stepSubtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 32)

                    if installer.step.isWorking {
                        VStack(spacing: 8) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(colors: [Color(hex: "FF4757"), Color(hex: "FF6B81")],
                                                             startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * installer.progress)
                                        .animation(.easeInOut(duration: 0.5), value: installer.progress)
                                }
                                .frame(height: 6)
                            }
                            .frame(height: 6)
                            Text(installer.step.label + dots)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.bottom, 24)
                    }

                    HStack(spacing: 12) {
                        DependencyBadge(name: "Homebrew", icon: "shippingbox",         isInstalled: installer.isBrewInstalled)
                        DependencyBadge(name: "yt-dlp",   icon: "arrow.down.circle",  isInstalled: installer.isYtdlpInstalled)
                        DependencyBadge(name: "ffmpeg",   icon: "waveform",            isInstalled: installer.isFfmpegInstalled)
                    }
                    .padding(.bottom, 24)

                    if case .failed(let err) = installer.step {
                        VStack(spacing: 10) {
                            Text(err).font(.system(size: 12)).foregroundColor(Color(hex: "FF4757")).multilineTextAlignment(.center)
                            Button("Try Again") { Task { await installer.install() } }
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                .padding(.horizontal, 24).padding(.vertical, 10)
                                .background(Color(hex: "FF4757").opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 10)).buttonStyle(.plain)
                        }
                        .padding(.bottom, 16)
                    }

                    if case .done = installer.step {
                        Text("🎉 Everything is ready!")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "2ECC71"))
                            .padding(.bottom, 16)
                    }

                    Button(action: { withAnimation { logExpanded.toggle() } }) {
                        HStack(spacing: 5) {
                            Image(systemName: logExpanded ? "chevron.up" : "chevron.down").font(.system(size: 10))
                            Text(logExpanded ? "Hide Logs" : "Show Details").font(.system(size: 11))
                        }
                        .foregroundColor(.white.opacity(0.25))
                    }
                    .buttonStyle(.plain)

                    if logExpanded {
                        ScrollViewReader { proxy in
                            ScrollView {
                                Text(installer.log.isEmpty ? "Waiting..." : installer.log)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12).id("bottom")
                            }
                            .frame(maxWidth: .infinity, maxHeight: 120)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.top, 10)
                            .onChange(of: installer.log) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                    }
                    Spacer()
                }
                .padding(30)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: installer.step.label)
        .onAppear { startDotTimer() }
        .onDisappear { timer?.invalidate() }
    }

    var dots: String { String(repeating: ".", count: dotCount) }

    var stepIcon: String {
        switch installer.step {
        case .done: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .installingBrew: return "shippingbox.fill"
        default: return "arrow.down.circle.fill"
        }
    }

    var iconColor: Color {
        switch installer.step {
        case .done: return Color(hex: "2ECC71")
        case .failed: return Color(hex: "FF4757")
        default: return Color(hex: "FF4757")
        }
    }

    var stepTitle: String {
        switch installer.step {
        case .idle, .checkingBrew: return "Preparing"
        case .waitingForConsent, .declined: return ""
        case .installingBrew: return "Installing Homebrew"
        case .installingYtdlp: return "Installing yt-dlp"
        case .installingFfmpeg: return "Installing ffmpeg"
        case .done: return "Ready!"
        case .failed: return "An Error Occurred"
        }
    }

    var stepSubtitle: String {
        switch installer.step {
        case .idle, .checkingBrew: return "Checking for required tools"
        case .waitingForConsent, .declined: return ""
        case .installingBrew: return "Setting up Homebrew, this may take a few minutes"
        case .installingYtdlp: return "Installing the video download engine"
        case .installingFfmpeg: return "Installing the media converter"
        case .done: return "All dependencies have been successfully installed"
        case .failed: return "Something went wrong during the installation"
        }
    }

    func startDotTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async { self.dotCount = (self.dotCount + 1) % 4 }
        }
    }
}

struct DependencyBadge: View {
    let name: String; let icon: String; let isInstalled: Bool
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(isInstalled ? Color(hex: "2ECC71").opacity(0.15) : Color.white.opacity(0.05)).frame(width: 36, height: 36)
                Image(systemName: isInstalled ? "checkmark" : icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isInstalled ? Color(hex: "2ECC71") : .white.opacity(0.3))
            }
            Text(name).font(.system(size: 10)).foregroundColor(isInstalled ? .white.opacity(0.6) : .white.opacity(0.25))
        }
        .frame(width: 72).padding(.vertical, 10)
        .background(Color.white.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ConsentView: View {
    @ObservedObject var installer: DependencyInstaller
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Color(hex: "FF4757").opacity(0.15)).frame(width: 120, height: 120).blur(radius: 16)
                Circle().fill(Color(hex: "FF4757").opacity(0.3)).frame(width: 80, height: 80).blur(radius: 8)
                Circle().fill(Color(hex: "FF4757").opacity(0.08)).frame(width: 100, height: 100)
                Circle().fill(Color(hex: "FF4757").opacity(0.12)).frame(width: 80, height: 80)
                Image(systemName: "shippingbox.fill").font(.system(size: 32, weight: .semibold)).foregroundColor(Color(hex: "FF4757"))
            }
            .padding(.bottom, 28)

            Text("Dependency Setup").font(.system(size: 22, weight: .bold)).foregroundColor(.white).padding(.bottom, 12)
            Text("Odyssey requires two essential tools to function correctly.").font(.system(size: 13)).foregroundColor(.white.opacity(0.5)).multilineTextAlignment(.center).padding(.bottom, 28)

            VStack(spacing: 10) {
                PackageRow(icon: "arrow.down.circle.fill", name: "yt-dlp",  description: "Download engine — support for 1000+ sites", color: "FF4757")
                PackageRow(icon: "waveform",               name: "ffmpeg",  description: "Media converter — for MP3 and MP4 output",  color: "F39C12")
            }
            .padding(.bottom, 12)

            Text("These will be installed via Homebrew. Internet connection required.")
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.25)).multilineTextAlignment(.center).padding(.bottom, 32)

            VStack(spacing: 10) {
                Button(action: { Task { await installer.userAccepted() } }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 14))
                        Text("Install and Continue").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(LinearGradient(colors: [Color(hex: "FF4757"), Color(hex: "C0392B")], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button(action: { installer.userDeclined() }) {
                    Text("No, Not Now").font(.system(size: 13)).foregroundColor(.white.opacity(0.3))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(30)
    }
}

struct PackageRow: View {
    let icon: String; let name: String; let description: String; let color: String
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color(hex: color).opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(Color(hex: color))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.85))
                Text(description).font(.system(size: 11)).foregroundColor(.white.opacity(0.35))
            }
            Spacer()
        }
        .padding(12).background(Color.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DeclinedView: View {
    @ObservedObject var installer: DependencyInstaller
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Color.white.opacity(0.04)).frame(width: 100, height: 100)
                Circle().fill(Color.white.opacity(0.06)).frame(width: 80, height: 80)
                Image(systemName: "xmark.circle.fill").font(.system(size: 36, weight: .semibold)).foregroundColor(.white.opacity(0.2))
            }
            .padding(.bottom, 28)

            Text("Cannot Continue").font(.system(size: 20, weight: .bold)).foregroundColor(.white.opacity(0.7)).padding(.bottom, 12)
            Text("Odyssey cannot download videos without yt-dlp and ffmpeg.\nYou must install these to use the application.")
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.35)).multilineTextAlignment(.center).padding(.bottom, 36)

            VStack(spacing: 10) {
                Button(action: { Task { await installer.userAccepted() } }) {
                    Text("Go Back and Install").font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(LinearGradient(colors: [Color(hex: "FF4757"), Color(hex: "C0392B")], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button(action: { NSApp.terminate(nil) }) {
                    Text("Quit Application").font(.system(size: 13)).foregroundColor(.white.opacity(0.25))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(30)
    }
}
