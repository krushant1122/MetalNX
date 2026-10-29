import Foundation

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

print("==================================================")
print("Running MetalNX Pipeline Fix Validation Suite")
print("==================================================")

let fm = FileManager.default
let testLauncherDir = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().path
let installNspPath = "\(testLauncherDir)/install_nsp.py"

// =========================================================================
// TEST 1: Centralized Output Path Construction (Requirement B)
// Must handle titles with spaces, "+", "'", ":", unicode, and external volume paths.
// Must never return an empty name or missing .app suffix.
// =========================================================================
print("\n--- Test 1: Centralized Output Path Sanitization Function ---")
let procB = Process()
procB.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
procB.arguments = ["-c", """
import sys
sys.path.insert(0, '\(testLauncherDir)')
import install_nsp

# Fail if centralized output path function does not exist
assert hasattr(install_nsp, 'build_output_app_path'), "install_nsp must have centralized build_output_app_path"

test_cases = [
    ('/Volumes/Home/user/', 'Super Mario 3D World', '/Volumes/Home/user/Super Mario 3D World.app'),
    ('/Volumes/Home/user/', \"Super Mario 3D World + Bowser's Fury\", \"/Volumes/Home/user/Super Mario 3D World + Bowser's Fury.app\"),
    ('/Applications', \"Link's Awakening\", \"/Applications/Link's Awakening.app\"),
    ('/Volumes/External SSD/', 'The Legend of Zelda: Echoes of Wisdom', '/Volumes/External SSD/The Legend of Zelda - Echoes of Wisdom.app'),
    ('/Volumes/Games/', 'ゼルダの伝説 ティアーズ オブ ザ キングダム', '/Volumes/Games/ゼルダの伝説 ティアーズ オブ ザ キングダム.app'),
    ('/Applications', '', '/Applications/nxnative.app'),
    ('/Applications', '   ', '/Applications/nxnative.app'),
    ('/Volumes/Games/Custom.app', 'Game', '/Volumes/Games/Custom.app'),
]

for dest, title, expected in test_cases:
    actual = str(install_nsp.build_output_app_path(dest, title))
    assert actual == expected, f"Mismatch for ({dest!r}, {title!r}): expected {expected!r}, got {actual!r}"

print("CENTRALIZED_PATH_TEST_PASSED")
"""]
let pipeB = Pipe()
procB.standardOutput = pipeB
procB.standardError = pipeB
try? procB.run()
procB.waitUntilExit()
let outputB = String(data: pipeB.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
assertTrue(outputB.contains("CENTRALIZED_PATH_TEST_PASSED"), "Centralized output path function handles spaces, +, ', :, unicode, external volumes: \(outputB.trimmingCharacters(in: .whitespacesAndNewlines))")

// =========================================================================
// TEST 2: Pipeline Never Fails with 'must end in .app' on Directory Target
// =========================================================================
print("\n--- Test 2: Destination Directory Target Does Not Crash Pipeline ---")
let tempFixtureDir = NSTemporaryDirectory() + "metalnx_test_fix_b_" + UUID().uuidString
try? fm.createDirectory(atPath: "\(tempFixtureDir)/nsp", withIntermediateDirectories: true)
let fakeNsp = "\(tempFixtureDir)/nsp/Super Mario 3D World + Bowser's Fury [0100152000022000][v0].nsp"
fm.createFile(atPath: fakeNsp, contents: Data("fake".utf8))

let procB2 = Process()
procB2.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
procB2.arguments = [
    installNspPath,
    "--folder", "\(tempFixtureDir)/nsp",
    "--out", "/Volumes/Home/user/"
]
let pipeB2 = Pipe()
procB2.standardOutput = pipeB2
procB2.standardError = pipeB2
try? procB2.run()
procB2.waitUntilExit()

let outputB2 = String(data: pipeB2.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
let hasAppSuffixCrash = outputB2.contains("must end in .app")
assertTrue(!hasAppSuffixCrash, "Pipeline does not crash with 'must end in .app' when directory is provided: \(outputB2.split(separator: "\n").suffix(2).joined(separator: "\n"))")

try? fm.removeItem(atPath: tempFixtureDir)

// =========================================================================
// TEST 3: Pinned Hermetic Python Environment (Requirement A)
// Pipeline must not call bare python/python3/uv and must include all modules
// (lz4.block, capstone, fontTools, backports.zstd, nsz).
// =========================================================================
print("\n--- Test 3: Pinned Hermetic Python Environment ---")
let procA = Process()
procA.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
procA.arguments = ["-c", """
import sys
from pathlib import Path
sys.path.insert(0, '\(testLauncherDir)')
import install_nsp

assert hasattr(install_nsp, 'get_hermetic_python'), "install_nsp must provide get_hermetic_python()"
py_bin = install_nsp.get_hermetic_python()
assert py_bin and Path(py_bin).is_file(), f"Hermetic Python binary must exist: {py_bin}"

# Verify all required modules are importable
import subprocess
test_code = '''
for m in ('lz4.block', 'capstone', 'fontTools', 'backports.zstd', 'nsz'):
    __import__(m)
print("ALL_MODULES_OK")
'''
res = subprocess.run([str(py_bin), "-c", test_code], capture_output=True, text=True)
assert "ALL_MODULES_OK" in res.stdout, f"Missing modules in hermetic Python: {res.stderr}"
print("HERMETIC_PYTHON_TEST_PASSED")
"""]
let pipeA = Pipe()
procA.standardOutput = pipeA
procA.standardError = pipeA
try? procA.run()
procA.waitUntilExit()
let outputA = String(data: pipeA.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
assertTrue(outputA.contains("HERMETIC_PYTHON_TEST_PASSED"), "Hermetic Python has lz4, capstone, fontTools, backports.zstd, nsz: \(outputA.trimmingCharacters(in: .whitespacesAndNewlines))")

// Summary
print("\n==================================================")
print("TEST SUMMARY: \(testsPassed)/\(testsRun) passed (\(testsFailed) failed)")
print("==================================================")

if testsFailed > 0 {
    exit(1)
} else {
    exit(0)
}
