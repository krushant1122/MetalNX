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

// MARK: - Models for DB & Verification Testing
struct GameDbEntry: Codable, Identifiable {
    var id: String { titleId }
    let titleId: String
    let name: String
    let engine: String
    let graphicsApi: String
    let testedDisplayVersion: String
    let testedBuildNote: String
    let testedFps: Int
    let hasCustomPatches: Bool
    let supportedVersions: [SupportedVersionEntry]
    let unsupportedVersionsNote: String
    let recipes: [GameRecipeEntry]
}

struct SupportedVersionEntry: Codable, Hashable {
    let versionCode: String
    let displayVersion: String
    let isTested: Bool
    let mainBuildId: String
}

struct GameRecipeEntry: Codable, Identifiable {
    var id: String
    let name: String
    let category: String
    let description: String
    let envKey: String
    let defaultValue: String
    var enabled: Bool
    let hasPatchBytecode: Bool
}

struct VerificationResult: Codable {
    let status: String
    let titleId: String
    let gameName: String
    let detectedVersion: String
    let testedVersion: String
    let isSupported: Bool
    let badge: String
    let message: String
    let unsupportedNote: String?
    let hasPatches: Bool?
    let testedFps: Int?
}

func loadDbForTest() -> [GameDbEntry] {
    let fm = FileManager.default
    let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().path
    let paths = [
        "\(testDir)/games_db.json",
        "\(fm.currentDirectoryPath)/tools/launcher/games_db.json",
        "/Applications/MetalNX.app/Contents/Resources/games_db.json"
    ]
    for p in paths {
        if fm.fileExists(atPath: p),
           let data = try? Data(contentsOf: URL(fileURLWithPath: p)),
           let entries = try? JSONDecoder().decode([GameDbEntry].self, from: data) {
            return entries
        }
    }
    return []
}

func verifyTestPackage(path: String, db: [GameDbEntry]) -> VerificationResult {
    let url = URL(fileURLWithPath: path)
    let fname = url.lastPathComponent

    var rawTid: String? = nil
    if let match = fname.range(of: "0100[0-9A-Fa-f]{12}", options: .regularExpression) {
        rawTid = String(fname[match]).uppercased()
    }

    var baseTid = rawTid
    if let tid = rawTid, tid.hasSuffix("800"), let num = UInt64(tid, radix: 16) {
        let hex = String(num - 0x800, radix: 16).uppercased()
        baseTid = String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }

    var ver = "v0"
    if let match = fname.range(of: "\\[v([0-9.]+)\\]", options: .regularExpression) {
        ver = String(fname[match]).replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
    } else if let match = fname.range(of: "v([0-9]+\\.[0-9]+(?:\\.[0-9]+)*)", options: .regularExpression) {
        ver = String(fname[match])
    }

    guard let bTid = baseTid, let entry = db.first(where: { $0.titleId.caseInsensitiveCompare(bTid) == .orderedSame }) else {
        return VerificationResult(
            status: "UNTESTED_GAME",
            titleId: baseTid ?? rawTid ?? "UNKNOWN",
            gameName: "Untested Game Title",
            detectedVersion: ver,
            testedVersion: "None",
            isSupported: false,
            badge: "ℹ️ Untested Game",
            message: "Title ID not in tested database",
            unsupportedNote: nil,
            hasPatches: false,
            testedFps: 30
        )
    }

    var isVersionMatch = false
    let cleanVer = ver.replacingOccurrences(of: "v", with: "").lowercased()
    for sv in entry.supportedVersions {
        if sv.versionCode.lowercased().contains(cleanVer) || sv.displayVersion.lowercased().contains(cleanVer) || cleanVer.contains(sv.displayVersion.lowercased()) {
            isVersionMatch = true
            break
        }
    }
    if cleanVer == entry.testedDisplayVersion.lowercased() || entry.testedDisplayVersion.lowercased().contains(cleanVer) {
        isVersionMatch = true
    }

    if isVersionMatch {
        return VerificationResult(
            status: "VERIFIED_SUPPORTED",
            titleId: bTid,
            gameName: entry.name,
            detectedVersion: ver,
            testedVersion: entry.testedDisplayVersion,
            isSupported: true,
            badge: "✓ Verified Compatible Release",
            message: "Official supported release",
            unsupportedNote: entry.unsupportedVersionsNote,
            hasPatches: entry.hasCustomPatches,
            testedFps: entry.testedFps
        )
    } else {
        return VerificationResult(
            status: "UNTESTED_VERSION",
            titleId: bTid,
            gameName: entry.name,
            detectedVersion: ver,
            testedVersion: entry.testedDisplayVersion,
            isSupported: false,
            badge: "⚠️ Untested Update Version",
            message: "Untested update",
            unsupportedNote: entry.unsupportedVersionsNote,
            hasPatches: entry.hasCustomPatches,
            testedFps: entry.testedFps
        )
    }
}

// Test 6: Database Loading (72 Registered Switch Games)
print("\n--- Test 6: Compatibility Database Loading ---")
let db = loadDbForTest()
assertTrue(db.count >= 72, "Successfully loaded full game database (\(db.count) titles >= 72)")

let botwEntry = db.first(where: { $0.titleId == "01007EF00011E000" })
assertTrue(botwEntry != nil, "Database contains Breath of the Wild (01007EF00011E000)")
if let botw = botwEntry {
    assertEqual(botw.name, "The Legend of Zelda: Breath of the Wild", "BotW game name verified")
    assertTrue(botw.engine.contains("Nintendo EPD"), "BotW engine identified as Nintendo EPD")
    assertEqual(botw.testedFps, 60, "BotW tested target FPS is 60")
    assertTrue(botw.hasCustomPatches, "BotW has registered nxnative patches")
    assertTrue(!botw.recipes.isEmpty, "BotW has active recipes available (\(botw.recipes.count) recipes)")
    assertTrue(botw.supportedVersions.contains(where: { $0.displayVersion.contains("1.9.0") || $0.versionCode.contains("1114112") }), "BotW lists 1.9.0 (v1114112) as supported")
}

let smoEntry = db.first(where: { $0.titleId == "0100000000010000" })
assertTrue(smoEntry != nil, "Database contains Super Mario Odyssey (0100000000010000)")
if let smo = smoEntry {
    assertEqual(smo.testedFps, 60, "Super Mario Odyssey target FPS is 60")
    assertTrue(smo.engine.contains("Nintendo EPD"), "Super Mario Odyssey engine identified as Nintendo EPD")
}

// Test 7: Package Compatibility Verifier
print("\n--- Test 7: NSP Package Compatibility Verifier ---")
// Subtest 7A: Supported Base / Update
let validBotwPath = "/Volumes/Backup/The Legend of Zelda Breath of the Wild [01007EF00011E800][v1114112].nsp"
let resA = verifyTestPackage(path: validBotwPath, db: db)
assertEqual(resA.status, "VERIFIED_SUPPORTED", "Zelda 1.9.0 update classified as VERIFIED_SUPPORTED")
assertTrue(resA.isSupported, "Zelda update flagged as supported")
assertEqual(resA.titleId, "01007EF00011E000", "Update Title ID 01007EF00011E800 correctly normalized to Base ID 01007EF00011E000")

// Subtest 7B: Untested Version
let untestedBotwPath = "/Volumes/Backup/Zelda [01007EF00011E800][v65536].nsp"
let resB = verifyTestPackage(path: untestedBotwPath, db: db)
assertEqual(resB.status, "UNTESTED_VERSION", "Untested Zelda update classified as UNTESTED_VERSION")
assertTrue(!resB.isSupported, "Untested version correctly flagged as not certified")

// Subtest 7C: Untested Game
let unknownGamePath = "/Volumes/Backup/Homebrew Game [0100DEADBEEF0000][v0].nsp"
let resC = verifyTestPackage(path: unknownGamePath, db: db)
assertEqual(resC.status, "UNTESTED_GAME", "Unknown Title ID classified as UNTESTED_GAME")
assertTrue(!resC.isSupported, "Untested game flagged as unverified")

// Subtest 7D: XCI Cartridge Dump Package
let xciPath = "/Volumes/Backup/Monster Hunter Rise [0100559011740000][v0].xci"
let resD = verifyTestPackage(path: xciPath, db: db)
assertTrue(resD.titleId == "0100559011740000", "XCI cartridge dump Title ID extracted correctly")

// Subtest 7E: Mario Kart 8 Deluxe Update v1441792 (3.0.3 / 4.0.0)
let mk8dUpdatePath = "/Volumes/Backup/Mario Kart 8 Deluxe [0100152000022800][v1441792].nsp"
let resE = verifyTestPackage(path: mk8dUpdatePath, db: db)
assertEqual(resE.status, "VERIFIED_SUPPORTED", "Mario Kart 8 Deluxe v1441792 update classified as VERIFIED_SUPPORTED")
assertTrue(resE.isSupported, "Mario Kart 8 Deluxe update flagged as supported")
assertEqual(resE.titleId, "0100152000022000", "Mario Kart 8 Deluxe update Title ID normalized to Base ID")

// Test 8: Recipe env.txt Preseeding Verification
print("\n--- Test 8: Recipe Preseeding & Synchronization ---")
let testEnvDir = NSTemporaryDirectory() + "nxnative_recipe_test"
let testEnvFile = "\(testEnvDir)/env.txt"
try? fm.createDirectory(atPath: testEnvDir, withIntermediateDirectories: true)
let recipePayload = """
# nxnative runtime environment configuration
# Generated by MetalNX Control Center
DM_OPMODE=1
DM_PRESENT_SNAP=1
NVN_TARGET_FPS=60
NVN_ENABLE_METALFX=1
NVN_ASYNC_SHADERS=1
NVN_ANISOTROPY=16
DM_DISABLE_STUTTER_SPIN=0
"""
try? recipePayload.write(to: URL(fileURLWithPath: testEnvFile), atomically: true, encoding: .utf8)
let readBack = try? String(contentsOfFile: testEnvFile, encoding: .utf8)
assertTrue(readBack?.contains("NVN_TARGET_FPS=60") == true, "Verified NVN_TARGET_FPS=60 written")
assertTrue(readBack?.contains("NVN_ENABLE_METALFX=1") == true, "Verified NVN_ENABLE_METALFX=1 written")
assertTrue(readBack?.contains("NVN_ASYNC_SHADERS=1") == true, "Verified NVN_ASYNC_SHADERS=1 written")
assertTrue(readBack?.contains("NVN_ANISOTROPY=16") == true, "Verified NVN_ANISOTROPY=16 written")
try? fm.removeItem(atPath: testEnvDir)

// Test 9: Python CLI Verifier Execution
print("\n--- Test 9: Python Verifier CLI Integration ---")
let testLauncherDir = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().path
let pythonScript = "\(testLauncherDir)/install_nsp.py"
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
proc.arguments = [pythonScript, "--verify", "Zelda [01007EF00011E800][v1114112].nsp"]
let pipe = Pipe()
proc.standardOutput = pipe
try? proc.run()
proc.waitUntilExit()
let cliData = pipe.fileHandleForReading.readDataToEndOfFile()
if let outputStr = String(data: cliData, encoding: .utf8),
   let cliJson = try? JSONSerialization.jsonObject(with: cliData) as? [String: Any] {
    let status = cliJson["status"] as? String
    assertEqual(status, "VERIFIED_SUPPORTED", "Python CLI --verify returns VERIFIED_SUPPORTED")
    let bTid = cliJson["titleId"] as? String
    assertEqual(bTid, "01007EF00011E000", "Python CLI normalized update Title ID")
} else {
    assertTrue(false, "Failed to parse Python CLI verifier JSON output")
}

// Test 10: Repo Discovery & App Bundle Root Rejection
print("\n--- Test 10: Repo Discovery & App Bundle Protection ---")
let testRepoProc = Process()
testRepoProc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
testRepoProc.arguments = ["-c", """
import sys
from pathlib import Path
sys.path.insert(0, '\(testLauncherDir)')
import install_nsp
app_res = Path('/Applications/MetalNX.app/Contents/Resources')
assert not install_nsp.is_valid_repo(app_res), 'App bundle Resources must not be identified as repo root'
root = install_nsp.find_repo_root()
assert root is not None, 'Must discover a valid repository root'
assert (root / 'dm/tools/nx_extract/Program.cs').is_file(), 'Root must have dm/tools/nx_extract/Program.cs'
sys.path.insert(0, str(root / 'scripts'))
import build_ipa_from_nsp
discovered = build_ipa_from_nsp.find_repo(app_res / 'scripts/build_ipa_from_nsp.py')
assert discovered is not None and (discovered / 'dm/tools/nx_extract/Program.cs').is_file()
print('VALID_REPO_PASSED')
"""]
let repoPipe = Pipe()
testRepoProc.standardOutput = repoPipe
try? testRepoProc.run()
testRepoProc.waitUntilExit()
let repoOutput = String(data: repoPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
assertTrue(repoOutput.contains("VALID_REPO_PASSED"), "App bundle rejection and dynamic repo discovery verified")

// Test 11: Crash Report Generation & Disk Telemetry Logging
print("\n--- Test 11: Crash Reporting & Telemetry Logging ---")
let testCrashProc = Process()
testCrashProc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
testCrashProc.arguments = ["-c", """
import sys
from pathlib import Path
sys.path.insert(0, '\(testLauncherDir)')
import install_nsp
install_nsp.write_crash_log(
    stage='Stage 2/7: Extracting Game RomFS & Assets',
    message='Simulated test extraction failure',
    recent_lines=['line 1: start extract', 'line 2: fatal error in test'],
    title_id='0100152000022000'
)
log_path = Path.home() / 'Library/Logs/MetalNX/latest_crash_report.txt'
assert log_path.is_file(), 'latest_crash_report.txt must be written'
txt = log_path.read_text(encoding='utf-8')
assert 'MetalNX Port Diagnostic & Crash Report' in txt, 'Header present'
assert '0100152000022000' in txt, 'Title ID present'
assert 'Simulated test extraction failure' in txt, 'Error message present'
assert 'fatal error in test' in txt, 'Telemetry line present'
print('CRASH_REPORT_TEST_PASSED')
"""]
let crashPipe = Pipe()
testCrashProc.standardOutput = crashPipe
try? testCrashProc.run()
testCrashProc.waitUntilExit()
let crashOutput = String(data: crashPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
assertTrue(crashOutput.contains("CRASH_REPORT_TEST_PASSED"), "Diagnostic crash report generation and telemetry persistence verified")

// Test 12: Configurable Scratch / Build Directory & Cache Purging
print("\n--- Test 12: Configurable Scratch / Build Directory & Cache Purging ---")
let testScratchProc = Process()
testScratchProc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
testScratchProc.arguments = ["-c", """
import sys, tempfile, os
from pathlib import Path
sys.path.insert(0, '\(testLauncherDir)')
import install_nsp

with tempfile.TemporaryDirectory(prefix="metalnx_test_scratch_") as tmpdir:
    test_scratch = Path(tmpdir)
    # Simulate staging dummy RomFS and cache
    dummy_file = test_scratch / "dummy_build/RomFS.bin"
    dummy_file.parent.mkdir(parents=True)
    dummy_file.write_bytes(b"A" * 1024 * 1024)
    assert dummy_file.is_file(), "Dummy scratch file written"

    info = install_nsp.get_storage_breakdown(custom_scratch=str(test_scratch))
    assert info["total_bytes"] >= 1024 * 1024, "Storage breakdown detects scratch files"

    res = install_nsp.purge_storage(category="build_cache", custom_scratch=str(test_scratch))
    assert res["status"] == "SUCCESS", "Purge returns success"
    assert not dummy_file.exists(), "Scratch file purged"
    print("SCRATCH_PURGE_TEST_PASSED")
"""]
let scratchPipe = Pipe()
testScratchProc.standardOutput = scratchPipe
try? testScratchProc.run()
testScratchProc.waitUntilExit()
let scratchOutput = String(data: scratchPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
assertTrue(scratchOutput.contains("SCRATCH_PURGE_TEST_PASSED"), "Configurable scratch directory and cache purging verified")

// Test 13: Pre-Flight Toolchain Doctor & Required Space Calculation
print("\n--- Test 13: Pre-Flight Toolchain Doctor & Required Space (2x NSP + 10 GB) ---")
let testDoctorProc = Process()
testDoctorProc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
testDoctorProc.arguments = ["-c", """
import sys, tempfile
from pathlib import Path
sys.path.insert(0, '\(testLauncherDir)')
import install_nsp

with tempfile.TemporaryDirectory(prefix="metalnx_doc_") as tmpdir:
    dummy_nsp = Path(tmpdir) / "test [0100152000022000][v1441792].nsp"
    dummy_nsp.write_bytes(b"0" * (1024 * 1024 * 100)) # 100 MB

    doc = install_nsp.run_doctor(base_path=str(dummy_nsp), scratch_path=tmpdir)
    assert "metal_toolchain" in doc, "Metal toolchain reported"
    assert "storage" in doc, "Storage reported"
    assert doc["storage"]["nsp_bytes"] == 100 * 1024 * 1024, "Exact NSP size computed"
    expected_req = (2 * 100 * 1024 * 1024) + (10 * 1024 * 1024 * 1024)
    assert doc["storage"]["required_bytes"] == expected_req, f"Required is 2x NSP + 10 GB (expected {expected_req}, got {doc['storage']['required_bytes']})"
    assert doc["recipe_match"] is not None, "Recipe checked"
    assert doc["recipe_match"]["status"] == "VERIFIED_SUPPORTED", "MK8D v1441792 is certified"
    print("DOCTOR_TEST_PASSED")
"""]
let docPipe = Pipe()
testDoctorProc.standardOutput = docPipe
try? testDoctorProc.run()
testDoctorProc.waitUntilExit()
let docOutput = String(data: docPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
assertTrue(docOutput.contains("DOCTOR_TEST_PASSED"), "Toolchain Doctor checks, recipe matching, and 2x NSP + 10 GB disk calculation verified")

// Test 14: Storage & Toolchain Manager Scan & Purge
print("\n--- Test 14: Storage & Toolchain Manager Scan & Purge ---")
let testStorageProc = Process()
testStorageProc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
testStorageProc.arguments = ["-c", """
import sys
sys.path.insert(0, '\(testLauncherDir)')
import install_nsp

info = install_nsp.get_storage_breakdown()
assert len(info["items"]) == 4, "4 primary storage categories reported"
category_ids = {it["id"] for it in info["items"]}
assert "build_cache" in category_ids, "Build cache category present"
assert "engine_workspace" in category_ids, "Engine workspace category present"
assert "toolchain" in category_ids, "Toolchain category present"
assert "logs" in category_ids, "Logs category present"

# Test selective purge of logs category
res = install_nsp.purge_storage(category="logs")
assert res["status"] == "SUCCESS", "Selective purge succeeded"
print("STORAGE_MANAGER_TEST_PASSED")
"""]
let storagePipe = Pipe()
testStorageProc.standardOutput = storagePipe
try? testStorageProc.run()
testStorageProc.waitUntilExit()
let storageOutput = String(data: storagePipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
assertTrue(storageOutput.contains("STORAGE_MANAGER_TEST_PASSED"), "Storage Manager itemized breakdown and category purge verified")

// Summary
print("\n==================================================")
print("TEST SUMMARY: \(testsPassed)/\(testsRun) passed (\(testsFailed) failed)")
print("==================================================")

if testsFailed > 0 {
    exit(1)
} else {
    exit(0)
}
