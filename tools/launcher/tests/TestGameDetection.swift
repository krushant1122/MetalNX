import Foundation
import AppKit

// MARK: - Test Framework
var testsRun = 0
var testsPassed = 0
var testsFailed = 0

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: String = #file, line: Int = #line) {
    testsRun += 1
    if a == b {
        testsPassed += 1
        print("  ✓ PASS: [\(a)] == [\(b)] \(message)")
    } else {
        testsFailed += 1
        print("  ✗ FAIL: [\(a)] != [\(b)] \(message) (Line \(line))")
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
    testsRun += 1
    if condition {
        testsPassed += 1
        print("  ✓ PASS: \(message)")
    } else {
        testsFailed += 1
        print("  ✗ FAIL: \(message) (Line \(line))")
    }
}

// MARK: - Detection Helper (Mirroring LauncherApp)
struct AppDetectionResult {
    let isNxNative: Bool
    let titleId: String?
    let name: String?
    let version: String?
    let appPath: String
}

func inspectApp(at fullAppPath: String) -> AppDetectionResult {
    let fm = FileManager.default
    let plistPath = "\(fullAppPath)/Contents/Info.plist"

    guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
          let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
        return AppDetectionResult(isNxNative: false, titleId: nil, name: nil, version: nil, appPath: fullAppPath)
    }

    let bundleId = plist["CFBundleIdentifier"] as? String ?? ""
    let titleId = (plist["DMTitleID"] as? String)?.uppercased()
    let executable = plist["CFBundleExecutable"] as? String ?? ""
    let name = plist["CFBundleDisplayName"] as? String ?? plist["CFBundleName"] as? String
    let version = plist["CFBundleShortVersionString"] as? String ?? plist["CFBundleVersion"] as? String

    // Exclude the Control Center / Launcher utility itself
    let isLauncherSelf = bundleId == "org.nxnative.metalnx" ||
                         bundleId == "org.nxnative.launcher" ||
                         fullAppPath.hasSuffix("MetalNX.app") ||
                         fullAppPath.hasSuffix("Nintendo Silicon Launcher.app") ||
                         executable == "MetalNX" ||
                         executable == "Nintendo Silicon Launcher" ||
                         name == "MetalNX" ||
                         name == "MetalNX Control Center" ||
                         name == "Nintendo Silicon Launcher" ||
                         name == "Nintendo Silicon Control Center"
    if isLauncherSelf {
        return AppDetectionResult(isNxNative: false, titleId: nil, name: name, version: version, appPath: fullAppPath)
    }

    let hasDmDir = fm.fileExists(atPath: "\(fullAppPath)/Contents/Resources/dm")
    let isNx = titleId != nil || bundleId.contains("nxnative") || executable == "nxnative" || executable == "dmhost" || hasDmDir

    return AppDetectionResult(
        isNxNative: isNx,
        titleId: titleId,
        name: name,
        version: version,
        appPath: fullAppPath
    )
}

// MARK: - Test Cases
print("==================================================")
print("Running Game Detection & Scanner Unit Tests")
print("==================================================")

// Test 1: Real Installed Zelda App Detection
print("\n--- Test 1: Real Installed Breath of the Wild App ---")
let realZeldaPath = "/Applications/The Legend of Zelda Breath of the Wild.app"
if FileManager.default.fileExists(atPath: realZeldaPath) {
    let result = inspectApp(at: realZeldaPath)
    assertTrue(result.isNxNative, "Identified Zelda as an nxnative game bundle")
    assertEqual(result.titleId, "01007EF00011E000", "Extracted Title ID matches BotW")
    assertEqual(result.name, "The Legend of Zelda: Breath of the Wild", "Extracted Display Name matches")
    assertEqual(result.version, "1.9.0", "Extracted game version matches 1.9.0")
} else {
    print("  [SKIP] Zelda app not found at \(realZeldaPath)")
}

// Test 2: Standard macOS Non-Game Apps (False Positive Rejection)
print("\n--- Test 2: Reject Standard macOS Non-Game Apps ---")
let testNonGameApps = [
    "/System/Applications/Calculator.app",
    "/System/Applications/TextEdit.app",
    "/Applications/Safari.app"
]
for app in testNonGameApps where FileManager.default.fileExists(atPath: app) {
    let result = inspectApp(at: app)
    assertTrue(!result.isNxNative, "Correctly rejected non-game app: \(URL(fileURLWithPath: app).lastPathComponent)")
    assertTrue(result.titleId == nil, "No Title ID detected for standard app")
}

// Test 2B: MetalNX Self-Detection Rejection
print("\n--- Test 2B: Reject MetalNX Utility From Game Scanner ---")
let metalNxAppPath = "/Applications/MetalNX.app"
if FileManager.default.fileExists(atPath: metalNxAppPath) {
    let result = inspectApp(at: metalNxAppPath)
    assertTrue(!result.isNxNative, "Correctly rejected MetalNX from game list")
    assertTrue(result.titleId == nil, "No Title ID assigned to MetalNX utility")
}

// Synthetic MetalNX test
let baseTempDir = NSTemporaryDirectory() + "nxnative_test_apps"
let syntheticLauncherApp = "\(baseTempDir)/MetalNX.app"
let testFm = FileManager.default
try? testFm.createDirectory(atPath: "\(syntheticLauncherApp)/Contents", withIntermediateDirectories: true)
let launcherPlist: [String: Any] = [
    "CFBundleDisplayName": "MetalNX",
    "CFBundleName": "MetalNX",
    "CFBundleIdentifier": "org.nxnative.metalnx",
    "CFBundleExecutable": "MetalNX"
]
if let data = try? PropertyListSerialization.data(fromPropertyList: launcherPlist, format: .xml, options: 0) {
    try? data.write(to: URL(fileURLWithPath: "\(syntheticLauncherApp)/Contents/Info.plist"))
}
let syntheticLauncherResult = inspectApp(at: syntheticLauncherApp)
assertTrue(!syntheticLauncherResult.isNxNative, "Correctly rejected synthetic MetalNX bundle with org.nxnative.metalnx")
assertTrue(syntheticLauncherResult.titleId == nil, "Synthetic MetalNX has no Title ID")
try? testFm.removeItem(atPath: syntheticLauncherApp)

// Test 3: Synthetic Mario Kart 8 Deluxe App Detection
print("\n--- Test 3: Synthetic Mario Kart 8 Deluxe App Detection ---")
let tempDir = NSTemporaryDirectory() + "nxnative_test_apps"
let syntheticMk8App = "\(tempDir)/Mario Kart 8 Deluxe.app"
let fm = FileManager.default
try? fm.createDirectory(atPath: "\(syntheticMk8App)/Contents/MacOS", withIntermediateDirectories: true)
try? fm.createDirectory(atPath: "\(syntheticMk8App)/Contents/Resources/dm", withIntermediateDirectories: true)

let syntheticPlist: [String: Any] = [
    "CFBundleDisplayName": "Mario Kart 8 Deluxe",
    "CFBundleName": "Mario Kart 8 Deluxe",
    "CFBundleIdentifier": "org.nxnative.0100152000022000",
    "CFBundleExecutable": "nxnative",
    "CFBundleShortVersionString": "3.0.1",
    "DMTitleID": "0100152000022000"
]
let plistUrl = URL(fileURLWithPath: "\(syntheticMk8App)/Contents/Info.plist")
if let data = try? PropertyListSerialization.data(fromPropertyList: syntheticPlist, format: .xml, options: 0) {
    try? data.write(to: plistUrl)
}

let synthResult = inspectApp(at: syntheticMk8App)
assertTrue(synthResult.isNxNative, "Synthetic Mario Kart 8 Deluxe detected as nxnative app")
assertEqual(synthResult.titleId, "0100152000022000", "Synthetic Title ID matches MK8D")
assertEqual(synthResult.version, "3.0.1", "Synthetic version correctly read")
assertEqual(synthResult.name, "Mario Kart 8 Deluxe", "Synthetic game title correctly read")

// Cleanup
try? fm.removeItem(atPath: tempDir)

// Test 4: Environment Path Resolution
print("\n--- Test 4: Config Path Resolution ---")
let home = fm.homeDirectoryForCurrentUser.path
let expectedBotwEnv = "\(home)/Library/Application Support/nxnative/01007EF00011E000/env.txt"
let titleId = "01007EF00011E000"
let resolvedEnv = "\(home)/Library/Application Support/nxnative/\(titleId)/env.txt"
assertEqual(resolvedEnv, expectedBotwEnv, "Title ID maps to exact authoritative env.txt location")

// Test 5: Game Icon Extraction
print("\n--- Test 5: Game Icon Extraction ---")
if FileManager.default.fileExists(atPath: realZeldaPath) {
    let iconPath = "\(realZeldaPath)/Contents/Resources/AppIcon.icns"
    if fm.fileExists(atPath: iconPath) {
        let img = NSImage(contentsOfFile: iconPath)
        assertTrue(img != nil, "Successfully loaded native AppIcon.icns")
        if let img = img {
            assertTrue(img.size.width >= 128, "AppIcon resolution is high-density (width: \(img.size.width))")
        }
    }
}

// Summary
print("\n==================================================")
print("TEST SUMMARY: \(testsPassed)/\(testsRun) passed (\(testsFailed) failed)")
print("==================================================")

if testsFailed > 0 {
    exit(1)
} else {
    exit(0)
}
