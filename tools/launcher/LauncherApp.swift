import SwiftUI
import AppKit
import Metal
import UniformTypeIdentifiers

// MARK: - Color Palette & Liquid Obsidian Material Architecture
extension Color {
    static let obsidianBase = Color(red: 10/255, green: 10/255, blue: 12/255)
    static let materialUltraThin = Color.white.opacity(0.035)
    static let materialThinElevated = Color.white.opacity(0.065)
    static let materialHover = Color.white.opacity(0.09)
    static let hairlineSpecular = Color.white.opacity(0.08)
    static let scrimTerminal = Color(red: 6/255, green: 6/255, blue: 8/255)
    static let iceBlue = Color(red: 41/255, green: 151/255, blue: 255/255)
    static let mintGreen = Color(red: 48/255, green: 209/255, blue: 88/255)
    static let accentViolet = Color(red: 191/255, green: 90/255, blue: 242/255)
    static let accentAmber = Color(red: 255/255, green: 159/255, blue: 10/255)
    static let accentCoral = Color(red: 255/255, green: 69/255, blue: 58/255)
}

// MARK: - Game Metadata & Profile
struct GameProfile: Identifiable, Hashable {
    let titleId: String
    var title: String
    var shortTitle: String
    var iconName: String
    var defaultFps: Int
    var isHeavy3D: Bool
    var appPath: String?
    var isDetected: Bool = false
    var version: String = "1.0.0"

    var id: String { titleId }

    var envPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/nxnative/\(titleId)/env.txt"
    }

    var appInternalEnvPath: String? {
        guard let app = appPath else { return nil }
        return "\(app)/Contents/Resources/dm/env.txt"
    }
}

// MARK: - Known Game Database Catalog
let kKnownGameCatalog: [GameProfile] = [
    GameProfile(titleId: "01007EF00011E000", title: "The Legend of Zelda: Breath of the Wild", shortTitle: "Zelda: BotW", iconName: "sparkles", defaultFps: 30, isHeavy3D: true),
    GameProfile(titleId: "0100F2C0115B6000", title: "The Legend of Zelda: Tears of the Kingdom", shortTitle: "Zelda: TotK", iconName: "wand.and.stars", defaultFps: 30, isHeavy3D: true),
    GameProfile(titleId: "0100000000010000", title: "Super Mario Odyssey", shortTitle: "Mario Odyssey", iconName: "crown.fill", defaultFps: 60, isHeavy3D: true),
    GameProfile(titleId: "0100152000022000", title: "Mario Kart 8 Deluxe", shortTitle: "Mario Kart 8", iconName: "flag.checkered.2.crossed", defaultFps: 60, isHeavy3D: false),
    GameProfile(titleId: "01006A800016E000", title: "Super Smash Bros. Ultimate", shortTitle: "Smash Ultimate", iconName: "flame.fill", defaultFps: 60, isHeavy3D: true),
    GameProfile(titleId: "010093801237C000", title: "Metroid Dread", shortTitle: "Metroid Dread", iconName: "shield.lefthalf.filled", defaultFps: 60, isHeavy3D: false),
    GameProfile(titleId: "010028600EBDA000", title: "Super Mario 3D World + Bowser's Fury", shortTitle: "Mario 3D World", iconName: "cat.fill", defaultFps: 60, isHeavy3D: true),
    GameProfile(titleId: "010015100B514000", title: "Super Mario Bros. Wonder", shortTitle: "Mario Wonder", iconName: "star.fill", defaultFps: 60, isHeavy3D: false),
    GameProfile(titleId: "01006BB00C6F0000", title: "The Legend of Zelda: Link's Awakening", shortTitle: "Link's Awakening", iconName: "shield.fill", defaultFps: 60, isHeavy3D: false),
    GameProfile(titleId: "01006F8002326000", title: "Animal Crossing: New Horizons", shortTitle: "Animal Crossing", iconName: "leaf.fill", defaultFps: 30, isHeavy3D: false),
    GameProfile(titleId: "01005CA01580E000", title: "Persona 5 Royal", shortTitle: "Persona 5 R", iconName: "theatermasks.fill", defaultFps: 60, isHeavy3D: true),
    GameProfile(titleId: "01007300020FA000", title: "ASTRAL CHAIN", shortTitle: "Astral Chain", iconName: "bolt.shield.fill", defaultFps: 30, isHeavy3D: true),
    GameProfile(titleId: "0100B04011742000", title: "Monster Hunter Rise", shortTitle: "MH Rise", iconName: "pawprint.fill", defaultFps: 30, isHeavy3D: true),
    GameProfile(titleId: "01008CF01BAAC000", title: "The Legend of Zelda: Echoes of Wisdom", shortTitle: "Echoes of Wisdom", iconName: "triangle.fill", defaultFps: 60, isHeavy3D: false),
    GameProfile(titleId: "0100ECD018EBE000", title: "Paper Mario: The Thousand-Year Door", shortTitle: "Paper Mario TTYD", iconName: "doc.fill", defaultFps: 30, isHeavy3D: false),
    GameProfile(titleId: "0100CD801CE5E000", title: "Balatro", shortTitle: "Balatro", iconName: "suit.spade.fill", defaultFps: 60, isHeavy3D: false)
]

// MARK: - Hardware Profile Model
struct HardwareInfo {
    let chipName: String
    let coreCount: Int
    let isFanlessBaseAir: Bool

    static func detect() -> HardwareInfo {
        let device = MTLCreateSystemDefaultDevice()
        let name = device?.name ?? "Apple Silicon"
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let lower = name.lowercased()
        let isBase = !lower.contains("pro") && !lower.contains("max") && !lower.contains("ultra")
        return HardwareInfo(chipName: name, coreCount: cores, isFanlessBaseAir: isBase)
    }
}

// MARK: - Game Settings Model
struct GameSettings: Equatable {
    var fpsTarget: Int = 30
    var renderScale: Double = 0.85
    var metalFx: Bool = true
    var metalFxColorMode: String = "perceptual" // "perceptual" or "linear"
    var opMode: Int = 1 // 1 = Docked, 0 = Handheld
    var presentSnap: Bool = true
    var antiStutterSpin: Bool = true
    var metalHud: Bool = false
    var drawDistance: Double = 1.0
    var padLayout: String = "xbox" // "nintendo" or "xbox"
    var fpsHold: Bool = true

    func generateEnvContent() -> String {
        var lines: [String] = []
        lines.append("DM_FPS_TARGET=\(fpsTarget)")
        lines.append("DM_FPS_HOLD=\(fpsHold ? "on" : "off")")
        lines.append(String(format: "DM_RENDER_SCALE=%.2f", renderScale))
        lines.append("DM_PRESENT_UPSCALE=\(metalFx ? "metalfx" : "off")")
        lines.append("DM_METALFX_COLOR=\(metalFxColorMode)")
        lines.append("DM_OPMODE=\(opMode)")
        lines.append("DM_PRESENT_SNAP=\(presentSnap ? "1" : "0")")
        lines.append("DM_SPIN=\(antiStutterSpin ? "0" : "1")")
        lines.append("DM_METAL_HUD=\(metalHud ? "1" : "0")")
        if drawDistance > 1.0 {
            lines.append(String(format: "DM_LOD_SCALE=%.1f", drawDistance))
        }
        lines.append("DM_PAD_LAYOUT=\(padLayout)")
        lines.append("DM_NVN_FAST_WAKE=1")
        lines.append("DM_NVN_SLICE_MERGE=1")
        lines.append("DM_NVN_CS_HOIST=1")
        lines.append("DM_NVN_ENC_THREAD=1")
        return lines.joined(separator: "\n") + "\n"
    }

    func toEnvDictionary() -> [String: String] {
        return [
            "DM_FPS_TARGET": "\(fpsTarget)",
            "DM_FPS_HOLD": fpsHold ? "on" : "off",
            "DM_RENDER_SCALE": String(format: "%.2f", renderScale),
            "DM_PRESENT_UPSCALE": metalFx ? "metalfx" : "off",
            "DM_METALFX_COLOR": metalFxColorMode,
            "DM_OPMODE": "\(opMode)",
            "DM_PRESENT_SNAP": presentSnap ? "1" : "0",
            "DM_SPIN": antiStutterSpin ? "0" : "1",
            "DM_METAL_HUD": metalHud ? "1" : "0",
            "DM_LOD_SCALE": String(format: "%.1f", drawDistance),
            "DM_PAD_LAYOUT": padLayout,
            "DM_NVN_FAST_WAKE": "1",
            "DM_NVN_SLICE_MERGE": "1",
            "DM_NVN_CS_HOIST": "1",
            "DM_NVN_ENC_THREAD": "1"
        ]
    }
}

// MARK: - Verification Status Model
struct VerificationStatus {
    var isVerified: Bool = false
    var filePath: String = ""
    var lastVerifiedTime: Date?
    var activeValuesSummary: String = ""
    var rawConfigPreview: String = ""
}

// MARK: - Native Game Icon Component
struct GameIconView: View {
    let game: GameProfile
    let size: CGFloat

    var iconImage: NSImage? {
        if let app = game.appPath {
            let icnsPath = "\(app)/Contents/Resources/AppIcon.icns"
            if FileManager.default.fileExists(atPath: icnsPath), let img = NSImage(contentsOfFile: icnsPath) {
                return img
            }
            if FileManager.default.fileExists(atPath: app) {
                return NSWorkspace.shared.icon(forFile: app)
            }
        }
        return nil
    }

    var body: some View {
        if let img = iconImage {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(Color.hairlineSpecular, lineWidth: 0.5)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color.materialThinElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                            .stroke(Color.hairlineSpecular, lineWidth: 0.5)
                    )

                Image(systemName: game.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.45, height: size * 0.45)
                    .foregroundColor(Color.iceBlue)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Port Installer ViewModel
class PortInstallerViewModel: ObservableObject {
    @Published var baseNspPath: String = ""
    @Published var updateNspPath: String = ""
    @Published var folderPath: String = ""
    @Published var keysPath: String = ""
    @Published var isInstalling: Bool = false
    @Published var currentStage: String = "Ready"
    @Published var currentProgress: Double = 0.0
    @Published var etaSeconds: Int? = nil
    @Published var elapsedSeconds: Int = 0
    @Published var consoleLogs: [String] = []
    @Published var installedAppPath: String? = nil
    @Published var isCompleted: Bool = false
    @Published var errorMessage: String? = nil

    private var activeProcess: Process?

    init() {
        autoDetectKeys()
    }

    func autoDetectKeys() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.switch/prod.keys",
            "\(home)/.config/Ryujinx/system/prod.keys",
            "\(home)/Library/Application Support/yuzu/keys/prod.keys"
        ]
        for c in candidates where FileManager.default.fileExists(atPath: c) {
            keysPath = c
            break
        }
    }

    func formattedEta() -> String {
        guard let sec = etaSeconds else { return "Calculating ETA..." }
        if sec <= 0 { return "Finalizing bundle..." }
        let m = sec / 60
        let s = sec % 60
        return m > 0 ? "\(m)m \(s)s remaining" : "\(s)s remaining"
    }

    func formattedElapsed() -> String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return "\(m)m \(s)s"
    }

    func browseBaseNsp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "nsp") ?? .data,
            UTType(filenameExtension: "nsz") ?? .data
        ]
        panel.prompt = "Select Base Game NSP"

        if panel.runModal() == .OK, let url = panel.url {
            baseNspPath = url.path
            folderPath = ""
            isCompleted = false
            errorMessage = nil
        }
    }

    func browseUpdateNsp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "nsp") ?? .data,
            UTType(filenameExtension: "nsz") ?? .data
        ]
        panel.prompt = "Select Update NSP (Optional)"

        if panel.runModal() == .OK, let url = panel.url {
            updateNspPath = url.path
            folderPath = ""
            isCompleted = false
            errorMessage = nil
        }
    }

    func browseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select NSP Game Folder"

        if panel.runModal() == .OK, let url = panel.url {
            folderPath = url.path
            baseNspPath = ""
            updateNspPath = ""
            isCompleted = false
            errorMessage = nil
        }
    }

    func browseKeys() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select prod.keys"

        if panel.runModal() == .OK, let url = panel.url {
            keysPath = url.path
        }
    }

    func startInstallation(onSuccess: @escaping (String) -> Void) {
        guard !isInstalling else { return }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var scriptPath = "\(Bundle.main.resourcePath ?? "")/install_nsp.py"
        if !FileManager.default.fileExists(atPath: scriptPath) {
            scriptPath = "\(home)/nxnative/tools/launcher/install_nsp.py"
        }

        guard FileManager.default.fileExists(atPath: scriptPath) else {
            errorMessage = "Could not locate install_nsp.py helper script!"
            return
        }

        isInstalling = true
        isCompleted = false
        errorMessage = nil
        installedAppPath = nil
        currentProgress = 0.05
        currentStage = "Stage 1/7: Initializing..."
        etaSeconds = nil
        elapsedSeconds = 0
        consoleLogs = ["=== macOS 27 Liquid Obsidian Port Pipeline Active ==="]

        let process = Process()
        self.activeProcess = process

        let pythonCandidates = [
            "/Library/Frameworks/Python.framework/Versions/3.10/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/bin/python3"
        ]
        let pythonPath = pythonCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "/usr/bin/python3"
        process.executableURL = URL(fileURLWithPath: pythonPath)

        var args = [scriptPath]
        if !folderPath.isEmpty {
            args.append(contentsOf: ["--folder", folderPath])
        } else if !baseNspPath.isEmpty {
            args.append(contentsOf: ["--base", baseNspPath])
            if !updateNspPath.isEmpty {
                args.append(contentsOf: ["--update", updateNspPath])
            }
        } else {
            errorMessage = "Please select either a Base NSP file or a folder containing NSPs!"
            isInstalling = false
            return
        }

        if !keysPath.isEmpty {
            args.append(contentsOf: ["--keys", keysPath])
        }

        process.arguments = args

        var env = ProcessInfo.processInfo.environment
        let dotnetDir = "\(home)/.dotnet"
        if FileManager.default.fileExists(atPath: dotnetDir) {
            env["DOTNET_ROOT"] = dotnetDir
            env["DOTNET_ROOT_ARM64"] = dotnetDir
            env["PATH"] = "\(dotnetDir):/usr/local/bin:/usr/bin:/bin:\(env["PATH"] ?? "")"
        }
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let outHandle = pipe.fileHandleForReading

        outHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }

            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                DispatchQueue.main.async {
                    guard let self = self else { return }

                    if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
                        if let jsonData = trimmed.data(using: .utf8),
                           let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            let status = dict["status"] as? String ?? ""
                            let progress = dict["progress"] as? Double ?? self.currentProgress
                            let stage = dict["stage"] as? String ?? self.currentStage
                            let msg = dict["message"] as? String ?? ""
                            let eta = dict["eta_seconds"] as? Int
                            let elapsed = dict["elapsed_seconds"] as? Int ?? self.elapsedSeconds

                            self.currentProgress = progress
                            self.currentStage = stage
                            self.etaSeconds = eta
                            self.elapsedSeconds = elapsed

                            if !msg.isEmpty {
                                self.consoleLogs.append("[\(stage)] \(msg)")
                            }

                            if status == "SUCCESS" {
                                self.isCompleted = true
                                self.isInstalling = false
                                self.etaSeconds = 0
                                if msg.contains("/Applications/") {
                                    let parts = msg.components(separatedBy: ": ")
                                    if parts.count >= 2 {
                                        self.installedAppPath = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                                }
                                onSuccess(self.installedAppPath ?? "")
                            } else if status == "ERROR" {
                                self.isInstalling = false
                                self.errorMessage = msg
                            }
                            return
                        }
                    }

                    self.consoleLogs.append(trimmed)
                    if self.consoleLogs.count > 300 {
                        self.consoleLogs.removeFirst(50)
                    }
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isInstalling = false
                if proc.terminationStatus != 0 && self.errorMessage == nil {
                    self.errorMessage = "Compilation process exited with code \(proc.terminationStatus)."
                }
            }
        }

        do {
            try process.run()
        } catch {
            self.errorMessage = "Failed to launch installer process: \(error.localizedDescription)"
            self.isInstalling = false
        }
    }

    func cancelInstallation() {
        activeProcess?.terminate()
        activeProcess = nil
        isInstalling = false
        errorMessage = "Installation canceled by user."
    }
}

// MARK: - Main ViewModel
class LauncherViewModel: ObservableObject {
    // CRITICAL: Only detected / installed games are shown in the UI. Undetected games are kept blank.
    @Published var detectedGames: [GameProfile] = []
    @Published var selectedGameId: String = "" {
        didSet {
            loadSettings()
            verifySettings()
        }
    }
    @Published var settings: GameSettings = GameSettings()
    @Published var hardware: HardwareInfo = HardwareInfo.detect()
    @Published var statusMessage: String = "Ready"
    @Published var isShowingStatus: Bool = false
    @Published var verification: VerificationStatus = VerificationStatus()
    @Published var isScanning: Bool = false
    @Published var activeTab: Int = 0

    var selectedGame: GameProfile? {
        return detectedGames.first(where: { $0.titleId == selectedGameId })
    }

    init() {
        scanInstalledGames()
        loadSettings()
        verifySettings()
    }

    func scanInstalledGames() {
        isScanning = true
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        let candidateDirs = [
            "/Applications",
            "\(home)/Applications",
            "\(home)/Games",
            "\(home)/Desktop",
            "\(home)/Downloads"
        ]

        let catalog = kKnownGameCatalog
        var detectedList: [GameProfile] = []

        for dir in candidateDirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let fullAppPath = (dir as NSString).appendingPathComponent(item)
                let plistPath = "\(fullAppPath)/Contents/Info.plist"

                guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
                      let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
                    continue
                }

                let bundleId = plist["CFBundleIdentifier"] as? String ?? ""
                let titleId = (plist["DMTitleID"] as? String)?.uppercased()
                let executable = plist["CFBundleExecutable"] as? String ?? ""
                let name = plist["CFBundleDisplayName"] as? String ?? plist["CFBundleName"] as? String ?? item.replacingOccurrences(of: ".app", with: "")
                let version = plist["CFBundleShortVersionString"] as? String ?? plist["CFBundleVersion"] as? String ?? "1.0.0"

                // Exclude the Control Center / Launcher utility itself
                let isLauncherSelf = bundleId == "org.nxnative.metalnx" ||
                                     bundleId == "org.nxnative.launcher" ||
                                     bundleId == Bundle.main.bundleIdentifier ||
                                     item == "MetalNX.app" ||
                                     item == "Nintendo Silicon Launcher.app" ||
                                     executable == "MetalNX" ||
                                     executable == "Nintendo Silicon Launcher" ||
                                     name.contains("MetalNX") ||
                                     name.contains("Nintendo Silicon")
                if isLauncherSelf {
                    continue
                }

                let isNxNativeApp = titleId != nil || bundleId.contains("nxnative") || executable == "nxnative" || executable == "dmhost" || fm.fileExists(atPath: "\(fullAppPath)/Contents/Resources/dm")

                if isNxNativeApp {
                    let detectedId = titleId ?? "CUSTOM_\(item.hashValue)"

                    if let idx = catalog.firstIndex(where: { $0.titleId.caseInsensitiveCompare(detectedId) == .orderedSame }) {
                        var found = catalog[idx]
                        found.isDetected = true
                        found.appPath = fullAppPath
                        found.version = version
                        detectedList.append(found)
                    } else if let idx = catalog.firstIndex(where: { name.localizedCaseInsensitiveContains($0.shortTitle) || $0.title.localizedCaseInsensitiveContains(name) }) {
                        var found = catalog[idx]
                        found.isDetected = true
                        found.appPath = fullAppPath
                        found.version = version
                        detectedList.append(found)
                    } else {
                        let custom = GameProfile(
                            titleId: detectedId,
                            title: name,
                            shortTitle: name,
                            iconName: "gamecontroller.fill",
                            defaultFps: 30,
                            isHeavy3D: true,
                            appPath: fullAppPath,
                            isDetected: true,
                            version: version
                        )
                        detectedList.append(custom)
                    }
                }
            }
        }

        // Deduplicate detected list by titleId
        var uniqueDetected: [GameProfile] = []
        var seenIds = Set<String>()
        for g in detectedList {
            if !seenIds.contains(g.titleId) {
                seenIds.insert(g.titleId)
                uniqueDetected.append(g)
            }
        }

        DispatchQueue.main.async {
            self.detectedGames = uniqueDetected
            self.isScanning = false
            if let first = uniqueDetected.first {
                if !uniqueDetected.contains(where: { $0.titleId == self.selectedGameId }) {
                    self.selectedGameId = first.titleId
                }
            } else {
                self.selectedGameId = ""
            }
            self.flashStatus("Library synced (\(uniqueDetected.count) detected)")
        }
    }

    func addCustomGame() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.prompt = "Select Game Application"

        if panel.runModal() == .OK, let url = panel.url {
            let fullAppPath = url.path
            let plistPath = "\(fullAppPath)/Contents/Info.plist"

            var titleId = "CUSTOM_\(url.lastPathComponent.hashValue)"
            var name = url.deletingPathExtension().lastPathComponent
            var version = "1.0.0"
            var bundleId = ""

            if let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                if let bid = plist["CFBundleIdentifier"] as? String { bundleId = bid }
                if let tid = plist["DMTitleID"] as? String { titleId = tid.uppercased() }
                if let disp = plist["CFBundleDisplayName"] as? String { name = disp }
                else if let n = plist["CFBundleName"] as? String { name = n }
                if let ver = plist["CFBundleShortVersionString"] as? String { version = ver }
            }

            let isLauncherSelf = bundleId == "org.nxnative.metalnx" ||
                                 bundleId == "org.nxnative.launcher" ||
                                 url.lastPathComponent == "MetalNX.app" ||
                                 url.lastPathComponent == "Nintendo Silicon Launcher.app" ||
                                 name.contains("MetalNX") ||
                                 name.contains("Nintendo Silicon")
            if isLauncherSelf {
                flashStatus("Cannot add MetalNX utility as a game")
                return
            }

            if let idx = detectedGames.firstIndex(where: { $0.titleId.caseInsensitiveCompare(titleId) == .orderedSame }) {
                detectedGames[idx].appPath = fullAppPath
                detectedGames[idx].version = version
                selectedGameId = detectedGames[idx].titleId
            } else {
                let custom = GameProfile(
                    titleId: titleId,
                    title: name,
                    shortTitle: name,
                    iconName: "gamecontroller.fill",
                    defaultFps: 30,
                    isHeavy3D: true,
                    appPath: fullAppPath,
                    isDetected: true,
                    version: version
                )
                detectedGames.insert(custom, at: 0)
                selectedGameId = custom.titleId
            }
            loadSettings()
            verifySettings()
            flashStatus("Added \(name)")
        }
    }

    func provideSetupConfig() {
        guard let current = selectedGame else { return }
        var rec = GameSettings()
        let isFanless = hardware.isFanlessBaseAir
        let isHeavy = current.isHeavy3D

        if isFanless {
            if isHeavy {
                rec.fpsTarget = 30
                rec.renderScale = 0.85
                rec.metalFx = true
                rec.metalFxColorMode = "perceptual"
                rec.opMode = 1
                rec.presentSnap = true
                rec.antiStutterSpin = true
                rec.metalHud = false
                rec.fpsHold = true
                rec.drawDistance = 1.0
            } else {
                rec.fpsTarget = 60
                rec.renderScale = 0.80
                rec.metalFx = true
                rec.metalFxColorMode = "perceptual"
                rec.opMode = 1
                rec.presentSnap = true
                rec.antiStutterSpin = true
                rec.metalHud = false
                rec.fpsHold = false
                rec.drawDistance = 1.0
            }
        } else {
            rec.fpsTarget = current.defaultFps
            rec.renderScale = 1.00
            rec.metalFx = true
            rec.metalFxColorMode = "perceptual"
            rec.opMode = 1
            rec.presentSnap = true
            rec.antiStutterSpin = true
            rec.metalHud = false
            rec.fpsHold = false
            rec.drawDistance = 1.0
        }

        self.settings = rec
        saveSettings()
        verifySettings()
        flashStatus("Optimal Liquid profile applied")
    }

    func loadSettings() {
        guard let current = selectedGame else { return }
        var loaded = GameSettings()
        loaded.fpsTarget = current.defaultFps

        let candidates = [
            current.envPath,
            current.appInternalEnvPath ?? ""
        ]

        for path in candidates where !path.isEmpty {
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                guard parts.count == 2 else { continue }
                let key = parts[0]
                let val = parts[1]

                switch key {
                case "DM_FPS_TARGET":
                    if let v = Int(val) { loaded.fpsTarget = v }
                case "DM_RENDER_SCALE":
                    if let v = Double(val) { loaded.renderScale = v }
                case "DM_PRESENT_UPSCALE":
                    loaded.metalFx = (val.lowercased() == "metalfx" || val == "1")
                case "DM_OPMODE":
                    if let v = Int(val) { loaded.opMode = v }
                case "DM_PRESENT_SNAP":
                    loaded.presentSnap = (val == "1")
                case "DM_SPIN":
                    loaded.antiStutterSpin = (val == "0")
                case "DM_METAL_HUD":
                    loaded.metalHud = (val == "1")
                case "DM_LOD_SCALE":
                    if let v = Double(val) { loaded.drawDistance = v }
                case "DM_PAD_LAYOUT":
                    loaded.padLayout = (val.lowercased() == "xbox" || val == "1") ? "xbox" : "nintendo"
                case "DM_FPS_HOLD":
                    loaded.fpsHold = (val.lowercased() == "on" || val == "1")
                case "DM_METALFX_COLOR":
                    loaded.metalFxColorMode = (val.lowercased() == "linear") ? "linear" : "perceptual"
                default:
                    break
                }
            }
            break
        }
        self.settings = loaded
    }

    func saveSettings() {
        guard let current = selectedGame else { return }
        let content = settings.generateEnvContent()
        let fm = FileManager.default

        let destinations = [
            current.envPath,
            current.appInternalEnvPath ?? ""
        ]

        for path in destinations where !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }

        verifySettings()
        flashStatus("Settings synchronized")
    }

    func verifySettings() {
        guard let current = selectedGame else {
            verification = VerificationStatus(isVerified: false, filePath: "No game selected", lastVerifiedTime: nil, activeValuesSummary: "Select or install a game", rawConfigPreview: "")
            return
        }
        let path = current.envPath
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            verification = VerificationStatus(
                isVerified: false,
                filePath: path,
                lastVerifiedTime: nil,
                activeValuesSummary: "Config pending creation",
                rawConfigPreview: "None"
            )
            return
        }

        var verifiedCount = 0
        let targetFpsStr = "DM_FPS_TARGET=\(settings.fpsTarget)"
        let targetScaleStr = String(format: "DM_RENDER_SCALE=%.2f", settings.renderScale)
        let targetUpscaleStr = "DM_PRESENT_UPSCALE=\(settings.metalFx ? "metalfx" : "off")"

        if content.contains(targetFpsStr) { verifiedCount += 1 }
        if content.contains(targetScaleStr) { verifiedCount += 1 }
        if content.contains(targetUpscaleStr) { verifiedCount += 1 }

        let isMatch = (verifiedCount == 3)
        let summary = "\(settings.opMode == 1 ? "Docked" : "Handheld") • Scale: \(Int(settings.renderScale * 100))% • MetalFX: \(settings.metalFx ? "ON" : "OFF") • Target: \(settings.fpsTarget) FPS"

        verification = VerificationStatus(
            isVerified: isMatch,
            filePath: path,
            lastVerifiedTime: Date(),
            activeValuesSummary: summary,
            rawConfigPreview: content.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func launchGame() {
        saveSettings()
        guard let current = selectedGame, let appPath = current.appPath, FileManager.default.fileExists(atPath: appPath) else {
            flashStatus("Select an installed game port")
            return
        }

        let appUrl = URL(fileURLWithPath: appPath)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.environment = settings.toEnvDictionary()

        NSWorkspace.shared.openApplication(at: appUrl, configuration: config) { app, err in
            DispatchQueue.main.async {
                if let err = err {
                    self.flashStatus("Launch failed: \(err.localizedDescription)")
                } else {
                    self.flashStatus("Launched \(current.shortTitle)")
                }
            }
        }
    }

    func flashStatus(_ msg: String) {
        statusMessage = msg
        isShowingStatus = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            self.isShowingStatus = false
        }
    }
}

// MARK: - Root View (macOS 27 Liquid Obsidian Architecture)
struct ContentView: View {
    @StateObject var vm = LauncherViewModel()
    @StateObject var installerVm = PortInstallerViewModel()

    @AppStorage("hasCompletedPermissionSetup") var hasCompletedPermissionSetup: Bool = false
    @State private var showingPermissionSheet: Bool = false
    @State private var showingConfigSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Window Toolbar (48 pt)
            HStack(spacing: 12) {
                // Window Title & Chip Telemetry
                HStack(spacing: 8) {
                    Text("MetalNX Control Center")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(-0.13)
                        .foregroundColor(Color.white.opacity(0.88))

                    // Minimal Telemetry Pill
                    HStack(spacing: 4) {
                        Circle()
                            .fill(vm.hardware.isFanlessBaseAir ? Color.accentAmber : Color.mintGreen)
                            .frame(width: 5, height: 5)
                        Text("\(vm.hardware.chipName) • \(vm.hardware.coreCount)C")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.materialThinElevated)
                    .cornerRadius(4)
                }

                Spacer()

                // Integrated Segmented Switcher (Liquid Obsidian, Zero-Focus Ring)
                LiquidSegmentedControl(activeTab: $vm.activeTab)

                Spacer()

                // Status Toast
                if vm.isShowingStatus {
                    Text(vm.statusMessage)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(Color.iceBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.iceBlue.opacity(0.12))
                        .cornerRadius(4)
                        .transition(.opacity)
                }

                Button(action: {
                    showingPermissionSheet = true
                }) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .buttonStyle(.plain)
        .focusable(false)
                .padding(6)
                .background(Color.materialThinElevated)
                .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(.ultraThinMaterial)

            Divider().opacity(0.12)

            // Primary Content Area
            ScrollView(.vertical, showsIndicators: false) {
                if vm.activeTab == 0 {
                    LiquidLibraryTweakerView(vm: vm, showingConfigSheet: $showingConfigSheet)
                } else {
                    LiquidPortInstallerView(installerVm: installerVm) { newAppPath in
                        vm.scanInstalledGames()
                        vm.activeTab = 0
                    }
                }
            }
            .scrollContentBackground(.hidden)

            Divider().opacity(0.12)

            // Pinned Bottom Glass Bar (52 pt)
            HStack(spacing: 12) {
                if vm.activeTab == 0 {
                    Button(action: {
                        vm.saveSettings()
                    }) {
                        Text("Save Settings")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .frame(height: 28)
                            .background(Color.materialThinElevated)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.hairlineSpecular, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
        .focusable(false)

                    Button(action: {
                        vm.loadSettings()
                        vm.verifySettings()
                    }) {
                        Text("Revert")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
        .focusable(false)

                    Spacer()

                    // Primary Launch CTA
                    Button(action: {
                        vm.launchGame()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text(vm.selectedGame != nil ? "Launch \(vm.selectedGame!.shortTitle)" : "Launch Game")
                                .font(.system(size: 12.5, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 32)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0, green: 122/255, blue: 255/255), Color.iceBlue],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                        .shadow(color: Color.iceBlue.opacity(0.35), radius: 8, y: 2)
                    }
                    .buttonStyle(.plain)
        .focusable(false)
                    .disabled(vm.selectedGame == nil)
                    .opacity(vm.selectedGame == nil ? 0.35 : 1.0)
                } else {
                    Text("1-Click Switch NSP to Native macOS ARM64 Translator")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.45))

                    Spacer()

                    Button("Return to Configuration") {
                        vm.activeTab = 0
                    }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.plain)
        .focusable(false)
                    .foregroundColor(Color.iceBlue)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 700, idealWidth: 720, minHeight: 760, idealHeight: 780)
        .background(Color.obsidianBase)
        .onAppear {
            if !hasCompletedPermissionSetup {
                showingPermissionSheet = true
            }
        }
        .sheet(isPresented: $showingPermissionSheet) {
            LiquidPermissionSheet(hasCompleted: $hasCompletedPermissionSetup)
        }
        .sheet(isPresented: $showingConfigSheet) {
            LiquidConfigViewerSheet(verification: vm.verification)
        }
    }
}

// MARK: - Liquid Segmented Control (Smooth Sliding, Zero Blue Focus Ring)
struct LiquidSegmentedControl: View {
    @Binding var activeTab: Int
    @Namespace private var segmentAnimation

    var body: some View {
        HStack(spacing: 0) {
            segmentButton(title: "Configuration", icon: "slider.horizontal.3", index: 0)
            segmentButton(title: "1-Click Port Installer", icon: "bolt.badge.automatic.fill", index: 1)
        }
        .padding(2.5)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.hairlineSpecular, lineWidth: 0.5)
        )
    }

    private func segmentButton(title: String, icon: String, index: Int) -> some View {
        let isSelected = activeTab == index
        return Button(action: {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                activeTab = index
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : Color.white.opacity(0.55))
            .padding(.horizontal, 13)
            .frame(height: 24)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                        .matchedGeometryEffect(id: "activeTabSegment", in: segmentAnimation)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusable(false)
    }
}

// MARK: - Liquid Library & Tweaker View
struct LiquidLibraryTweakerView: View {
    @ObservedObject var vm: LauncherViewModel
    @Binding var showingConfigSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            // 1. GAME SHELF (Only Show Detected Games; Undetected Games Kept Blank)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("INSTALLED GAME SHELF")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.66)
                        .foregroundColor(Color.white.opacity(0.45))

                    Spacer()

                    Button(action: { vm.scanInstalledGames() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
        .focusable(false)

                    Button(action: { vm.addCustomGame() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                            Text("Locate .app")
                        }
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.iceBlue)
                    }
                    .buttonStyle(.plain)
        .focusable(false)
                }

                if vm.detectedGames.isEmpty {
                    // Clean Empty State
                    HStack(spacing: 12) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(Color.white.opacity(0.3))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("No Installed Ports Detected")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.75))
                            Text("Switch ports in /Applications appear here. Use the 1-Click Port Installer to convert NSPs.")
                                .font(.system(size: 10.5))
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.materialUltraThin)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.hairlineSpecular, lineWidth: 0.5)
                    )
                } else {
                    // Minimal 52x52 Continuous Squircle Coverflow Strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(vm.detectedGames) { game in
                                LiquidGameShelfItem(
                                    game: game,
                                    isSelected: game.titleId == vm.selectedGameId
                                ) {
                                    vm.selectedGameId = game.titleId
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                    }
                }
            }

            // 2. LIQUID OBSIDIAN GAME HERO CARD (Actual Artwork)
            if let game = vm.selectedGame {
                HStack(spacing: 16) {
                    GameIconView(game: game, size: 64)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(game.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text(game.version)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.mintGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Color.mintGreen.opacity(0.12))
                                .cornerRadius(4)
                        }

                        HStack(spacing: 6) {
                            // Title ID Pill (Violet)
                            Text(game.titleId)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.accentViolet)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Color.accentViolet.opacity(0.12))
                                .cornerRadius(4)

                            // Architecture Pill
                            Text("ARM64 Metal")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.6))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Color.materialThinElevated)
                                .cornerRadius(4)

                            if let p = game.appPath {
                                Text((p as NSString).lastPathComponent)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.4))
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    Button(action: {
                        vm.provideSetupConfig()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11))
                            Text("Auto-Setup")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Color.iceBlue)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Color.iceBlue.opacity(0.12))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.iceBlue.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
        .focusable(false)
                }
                .padding(14)
                .background(Color.materialUltraThin)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.hairlineSpecular, lineWidth: 0.5)
                )
            }

            // 3. SETTINGS VERIFICATION STATUS WELL
            LiquidGroupWell(title: "Configuration Telemetry", icon: "checkmark.seal") {
                HStack(spacing: 10) {
                    Circle()
                        .fill(vm.verification.isVerified ? Color.mintGreen : Color.accentAmber)
                        .frame(width: 7, height: 7)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.verification.isVerified ? "Synchronized to env.txt" : "Pending Synchronization")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(vm.verification.isVerified ? Color.white : Color.accentAmber)

                        Text(vm.verification.activeValuesSummary)
                            .font(.system(size: 10.5))
                            .foregroundColor(Color.white.opacity(0.55))
                    }

                    Spacer()

                    Button("Inspect env.txt") {
                        showingConfigSheet.toggle()
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color.iceBlue)
                    .buttonStyle(.plain)
        .focusable(false)
                }
            }

            // 4. GRAPHICS & RESOLUTION SCALING (Name on Left, Sliders & Controls on Right)
            LiquidGroupWell(title: "Graphics & Resolution Scaling", icon: "display") {
                VStack(spacing: 8) {
                    // Internal Resolution Scale Slider
                    LiquidSettingRow(
                        title: "Internal Resolution Scale",
                        subtitle: "Renders internal sub-pixel geometry before upscaling"
                    ) {
                        HStack(spacing: 8) {
                            Slider(value: $vm.settings.renderScale, in: 0.50...2.00, step: 0.05) { _ in
                                vm.verifySettings()
                            }
                            .accentColor(Color.iceBlue)

                            Text(String(format: "%.0f%%", vm.settings.renderScale * 100))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.iceBlue)
                                .frame(width: 42, alignment: .trailing)
                        }
                    }

                    Divider().opacity(0.08)

                    // Draw Distance Slider
                    LiquidSettingRow(
                        title: "Draw Distance & LOD Range",
                        subtitle: "Actor visibility and terrain geometry multiplier"
                    ) {
                        HStack(spacing: 8) {
                            Slider(value: $vm.settings.drawDistance, in: 1.0...2.0, step: 0.25) { _ in
                                vm.verifySettings()
                            }
                            .accentColor(Color.iceBlue)

                            Text(String(format: "%.1fx", vm.settings.drawDistance))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.iceBlue)
                                .frame(width: 42, alignment: .trailing)
                        }
                    }

                    Divider().opacity(0.08)

                    // Target Framerate Picker
                    LiquidSettingRow(
                        title: "Target Framerate",
                        subtitle: "Paces frame interval timing to display vsync"
                    ) {
                        Picker("", selection: $vm.settings.fpsTarget) {
                            Text("30 FPS").tag(30)
                            Text("60 FPS").tag(60)
                            Text("Dynamic (0)").tag(0)
                        }
                    }

                    Divider().opacity(0.08)

                    // Console Profile Mode
                    LiquidSettingRow(
                        title: "Console Profile Mode",
                        subtitle: "Docked loads 1080p high-fidelity textures"
                    ) {
                        Picker("", selection: $vm.settings.opMode) {
                            Text("Docked (1080p)").tag(1)
                            Text("Handheld (720p)").tag(0)
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider().opacity(0.08)

                    // MetalFX AI Spatial Upscaler
                    LiquidSettingRow(
                        title: "Apple MetalFX AI Upscaler",
                        subtitle: "Spatial reconstruction filter (Press ⌘M to toggle live)"
                    ) {
                        Toggle("", isOn: $vm.settings.metalFx)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Color.mintGreen))
                    }

                    if vm.settings.metalFx {
                        Divider().opacity(0.08)

                        LiquidSettingRow(
                            title: "MetalFX Color Processing",
                            subtitle: "Perceptual sRGB gamma vs Linear HDR lighting"
                        ) {
                            Picker("", selection: $vm.settings.metalFxColorMode) {
                                Text("Perceptual").tag("perceptual")
                                Text("Linear").tag("linear")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
            }

            // 5. ENGINE ARCHITECTURE & OPTIMIZATIONS (Name on Left, Toggles on Right)
            LiquidGroupWell(title: "Engine & Hardware Architecture", icon: "cpu") {
                VStack(spacing: 8) {
                    LiquidSettingRow(
                        title: "Zero-Latency Core Handoff",
                        subtitle: "Eliminates worker back-off sleeps for seamless synchronization (DM_SPIN=0)"
                    ) {
                        Toggle("", isOn: $vm.settings.antiStutterSpin)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Color.mintGreen))
                    }

                    Divider().opacity(0.08)

                    LiquidSettingRow(
                        title: "Display Vsync Snapping",
                        subtitle: "Locks presentation to monitor refresh intervals (DM_PRESENT_SNAP=1)"
                    ) {
                        Toggle("", isOn: $vm.settings.presentSnap)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Color.mintGreen))
                    }

                    Divider().opacity(0.08)

                    LiquidSettingRow(
                        title: "Smooth Frame Pacing Clamp",
                        subtitle: "Clamps late frame spikes to preserve smooth motion (DM_FPS_HOLD=on)"
                    ) {
                        Toggle("", isOn: $vm.settings.fpsHold)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Color.mintGreen))
                    }

                    Divider().opacity(0.08)

                    LiquidSettingRow(
                        title: "Apple Metal Performance HUD",
                        subtitle: "Hardware overlay for framerate, frame time, and VRAM (DM_METAL_HUD=1)"
                    ) {
                        Toggle("", isOn: $vm.settings.metalHud)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Color.mintGreen))
                    }
                }
            }

            // 6. CONTROLLER MAPPING (Name on Left, Picker on Right)
            LiquidGroupWell(title: "Controller Mapping", icon: "gamecontroller") {
                LiquidSettingRow(
                    title: "Diamond Button Layout",
                    subtitle: vm.settings.padLayout == "xbox" ? "Western Layout (A = Bottom, B = Right)" : "Nintendo Layout (A = Right, B = Bottom)"
                ) {
                    Picker("", selection: $vm.settings.padLayout) {
                        Text("Nintendo").tag("nintendo")
                        Text("Xbox / Western").tag("xbox")
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .padding(18)
    }

    private func scaleLabel(_ scale: Double) -> String {
        if scale <= 0.6 { return "Sub-720p" }
        if scale <= 0.85 { return "720p Balanced" }
        if scale <= 1.05 { return "1080p Native" }
        if scale <= 1.35 { return "1080p Crisp" }
        if scale <= 1.65 { return "1440p Retina" }
        return "4K Ultra"
    }
}

// MARK: - Liquid Game Shelf Item (52x52 Curvature Cover)
struct LiquidGameShelfItem: View {
    let game: GameProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                GameIconView(game: game, size: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11.44, style: .continuous)
                            .stroke(isSelected ? Color.iceBlue : Color.hairlineSpecular, lineWidth: isSelected ? 1.5 : 0.5)
                    )
                    .shadow(color: isSelected ? Color.iceBlue.opacity(0.3) : Color.black.opacity(0.2), radius: isSelected ? 6 : 2, y: 2)

                // 2pt Bottom Accent Indicator
                RoundedRectangle(cornerRadius: 1)
                    .fill(isSelected ? Color.iceBlue : Color.clear)
                    .frame(width: 22, height: 2)
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

// MARK: - Liquid Setting Row (Name on Left, Sliders & Controls on Right)
struct LiquidSettingRow<Control: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let control: () -> Control

    init(title: String, subtitle: String? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundColor(.white)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.white.opacity(0.45))
                }
            }

            Spacer(minLength: 16)

            control()
                .frame(width: 220, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Liquid Group Well Container
struct LiquidGroupWell<Content: View>: View {
    let title: String
    let icon: String?
    @ViewBuilder let content: () -> Content

    init(title: String, icon: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let ic = icon {
                    Image(systemName: ic)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.45))
                }
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.66)
                    .foregroundColor(Color.white.opacity(0.45))
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.materialUltraThin)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.hairlineSpecular, lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Liquid 1-Click Port Installer View
struct LiquidPortInstallerView: View {
    @ObservedObject var installerVm: PortInstallerViewModel
    let onInstalled: (String) -> Void

    @State private var showingLogs: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Pipeline Hero Banner
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.iceBlue.opacity(0.14))
                    Image(systemName: "bolt.badge.automatic.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.iceBlue)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("1-Click Switch-to-Mac Native Port Pipeline")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Extracts Switch RomFS, translates NSO binaries, compiles Metal shaders, and packages signed macOS .app")
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.white.opacity(0.55))
                }
            }
            .padding(14)
            .background(Color.materialUltraThin)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.hairlineSpecular, lineWidth: 0.5)
            )

            // Step 1: Package Selection (Dashed Inset Wells)
            LiquidGroupWell(title: "1. Switch Package Dumps (.nsp / .nsz)", icon: "shippingbox") {
                VStack(alignment: .leading, spacing: 10) {
                    // Base File
                    HStack {
                        Image(systemName: "doc")
                            .font(.system(size: 11))
                            .foregroundColor(Color.iceBlue)

                        if installerVm.baseNspPath.isEmpty {
                            Text("Base Game NSP/NSZ (Required)")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.35))
                        } else {
                            Text((installerVm.baseNspPath as NSString).lastPathComponent)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button("Browse Base...") {
                            installerVm.browseBaseNsp()
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.iceBlue)
                        .buttonStyle(.plain)
        .focusable(false)
                    }
                    .padding(10)
                    .background(Color.materialThinElevated)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    )

                    // Update File
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                            .foregroundColor(Color.mintGreen)

                        if installerVm.updateNspPath.isEmpty {
                            Text("Update NSP/NSZ (Optional, e.g. v1.9.0)")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.35))
                        } else {
                            Text((installerVm.updateNspPath as NSString).lastPathComponent)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button("Browse Update...") {
                            installerVm.browseUpdateNsp()
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.mintGreen)
                        .buttonStyle(.plain)
        .focusable(false)
                    }
                    .padding(10)
                    .background(Color.materialThinElevated)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    )

                    HStack {
                        Text("Or select folder containing NSPs:")
                            .font(.system(size: 10.5))
                            .foregroundColor(Color.white.opacity(0.45))
                        Spacer()
                        Button(installerVm.folderPath.isEmpty ? "Browse Game Folder..." : (installerVm.folderPath as NSString).lastPathComponent) {
                            installerVm.browseFolder()
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(Color.accentAmber)
                        .buttonStyle(.plain)
        .focusable(false)
                    }
                }
            }

            // Step 2: Keys
            LiquidGroupWell(title: "2. Decryption Keys", icon: "key") {
                HStack {
                    Circle()
                        .fill(installerVm.keysPath.isEmpty ? Color.accentAmber : Color.mintGreen)
                        .frame(width: 6, height: 6)

                    Text(installerVm.keysPath.isEmpty ? "prod.keys not found" : (installerVm.keysPath as NSString).lastPathComponent)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.85))

                    Spacer()

                    Button("Locate Keys...") {
                        installerVm.browseKeys()
                    }
                    .font(.system(size: 10.5))
                    .foregroundColor(Color.iceBlue)
                    .buttonStyle(.plain)
        .focusable(false)
                }
            }

            // Real-Time Progress & Realistic ETA Card
            if installerVm.isInstalling {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(installerVm.currentStage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.1f%%", installerVm.currentProgress * 100))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.iceBlue)
                    }

                    // 3pt Precision Track
                    ProgressView(value: installerVm.currentProgress, total: 1.0)
                        .accentColor(Color.iceBlue)

                    HStack {
                        Text("ETA: \(installerVm.formattedEta())")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.75))

                        Spacer()

                        Text("Elapsed: \(installerVm.formattedElapsed())")
                            .font(.system(size: 10.5))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                }
                .padding(14)
                .background(Color.materialThinElevated)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.iceBlue.opacity(0.35), lineWidth: 0.5)
                )
            }

            // Completed Banner
            if installerVm.isCompleted {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.mintGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Native Port Deployed to /Applications")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(Color.mintGreen)
                        Text(installerVm.installedAppPath ?? "")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                    }

                    Spacer()

                    Button("View in Shelf") {
                        onInstalled(installerVm.installedAppPath ?? "")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.mintGreen)
                    .buttonStyle(.plain)
        .focusable(false)
                }
                .padding(12)
                .background(Color.mintGreen.opacity(0.12))
                .cornerRadius(10)
            }

            // Primary Build Button
            HStack(spacing: 12) {
                Button(action: {
                    installerVm.startInstallation { newPath in
                        onInstalled(newPath)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                        Text(installerVm.isInstalling ? "Compiling Native Port..." : "1-Click Compile & Install Port")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0, green: 122/255, blue: 255/255), Color.iceBlue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: Color.iceBlue.opacity(0.3), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
        .focusable(false)
                .disabled(installerVm.isInstalling || (installerVm.baseNspPath.isEmpty && installerVm.folderPath.isEmpty) || installerVm.keysPath.isEmpty)
                .opacity(installerVm.isInstalling || (installerVm.baseNspPath.isEmpty && installerVm.folderPath.isEmpty) ? 0.35 : 1.0)

                if installerVm.isInstalling {
                    Button("Abort") {
                        installerVm.cancelInstallation()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.accentCoral)
                    .frame(width: 70, height: 36)
                    .background(Color.accentCoral.opacity(0.12))
                    .cornerRadius(8)
                    .buttonStyle(.plain)
        .focusable(false)
                }
            }

            // Recessed Monospaced Terminal (#060608)
            LiquidGroupWell(title: "Compilation Telemetry", icon: "terminal") {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(installerVm.consoleLogs.enumerated()), id: \.offset) { idx, log in
                                Text(log)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.8))
                                    .id(idx)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }
                    .frame(height: 120)
                    .background(Color.scrimTerminal)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
                    .onChange(of: installerVm.consoleLogs.count) { newCount in
                        if newCount > 0 {
                            proxy.scrollTo(newCount - 1, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(18)
    }
}

// MARK: - Liquid Permission Sheet
struct LiquidPermissionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var hasCompleted: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36))
                .foregroundColor(Color.iceBlue)

            VStack(spacing: 4) {
                Text("System Permissions & Sandbox")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("macOS requires Full Disk Access to read Switch NSP game dumps from Downloads and install ports to /Applications.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Color.mintGreen).font(.system(size: 12))
                    Text("Read access to NSP / NSZ dumps in Downloads or external drives")
                        .font(.system(size: 11)).foregroundColor(Color.white.opacity(0.8))
                }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Color.mintGreen).font(.system(size: 12))
                    Text("Write deployment access to /Applications")
                        .font(.system(size: 11)).foregroundColor(Color.white.opacity(0.8))
                }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Color.mintGreen).font(.system(size: 12))
                    Text("Apple Metal offline shader compiler and codesigning tools")
                        .font(.system(size: 11)).foregroundColor(Color.white.opacity(0.8))
                }
            }
            .padding(14)
            .background(Color.materialThinElevated)
            .cornerRadius(10)

            HStack(spacing: 12) {
                Button("Open Privacy Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(Color.iceBlue)
                .buttonStyle(.plain)
        .focusable(false)

                Spacer()

                Button("Authorize & Continue") {
                    hasCompleted = true
                    dismiss()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 28)
                .background(Color.iceBlue)
                .cornerRadius(6)
                .buttonStyle(.plain)
        .focusable(false)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Color.obsidianBase)
    }
}

// MARK: - Liquid Config Viewer Sheet
struct LiquidConfigViewerSheet: View {
    @Environment(\.dismiss) var dismiss
    let verification: VerificationStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Configuration (env.txt)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.iceBlue)
                .buttonStyle(.plain)
        .focusable(false)
            }

            Text(verification.filePath)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.45))

            ScrollView {
                Text(verification.rawConfigPreview)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.scrimTerminal)
                    .cornerRadius(6)
            }
            .frame(maxHeight: 280)
        }
        .padding(18)
        .frame(width: 480, height: 360)
        .background(Color.obsidianBase)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.title = "MetalNX Control Center"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.setContentSize(NSSize(width: 720, height: 780))
            window.minSize = NSSize(width: 700, height: 760)
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct LauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("MetalNX Control Center", id: "main") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
    }
}
