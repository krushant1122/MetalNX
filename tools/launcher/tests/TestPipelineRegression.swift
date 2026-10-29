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
print("Running MetalNX Pipeline Regression Test Suite")
print("==================================================")

let fm = FileManager.default
let testLauncherDir = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().path
let installNspPath = "\(testLauncherDir)/install_nsp.py"

// =========================================================================
// REGRESSION TEST B1: Destination directory without .app (Issue #6, #9)
// When a user selects a directory (e.g. /Volumes/Home/user/) as destination,
// current code passes `-o /Volumes/Home/user` directly to build_ipa_from_nsp.py,
// which crashes with: [RED] the Mac app (-o / OUT_IPA) must end in .app: /Volumes/Home/user
// =========================================================================
print("\n--- Regression Test B1: Destination Directory Path Without .app Suffix ---")
let tempFixtureDir = NSTemporaryDirectory() + "metalnx_regression_b1_" + UUID().uuidString
try? fm.createDirectory(atPath: "\(tempFixtureDir)/nsp", withIntermediateDirectories: true)
let fakeNsp = "\(tempFixtureDir)/nsp/Game [0100152000022000][v0].nsp"
fm.createFile(atPath: fakeNsp, contents: Data("fake".utf8))

let procB1 = Process()
procB1.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
procB1.arguments = [
    installNspPath,
    "--folder", "\(tempFixtureDir)/nsp",
    "--out", "/Volumes/Home/user/"
]
let pipeB1 = Pipe()
procB1.standardOutput = pipeB1
procB1.standardError = pipeB1
try? procB1.run()
procB1.waitUntilExit()

let outputB1 = String(data: pipeB1.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
let reproducedB1 = outputB1.contains("must end in .app")
print("  Output preview: \(outputB1.split(separator: "\n").suffix(3).joined(separator: "\n"))")
assertTrue(!reproducedB1, "REGRESSION FIXED: Pipeline never crashes with 'the Mac app (-o / OUT_IPA) must end in .app' when directory path is provided")

// Cleanup fixture
try? fm.removeItem(atPath: tempFixtureDir)

// =========================================================================
// REGRESSION TEST B2: Centralized Output Path Sanitization Function
// Must handle titles with spaces, "+", "'", ":", unicode, and external volume paths.
// Must never return an empty name or missing .app suffix.
// =========================================================================
print("\n--- Regression Test B2: Centralized Output Path Sanitization ---")
let procB2 = Process()
procB2.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
procB2.arguments = ["-c", """
import sys
sys.path.insert(0, '\(testLauncherDir)')
import install_nsp

assert hasattr(install_nsp, 'build_output_app_path'), "build_output_app_path must exist"

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

print('CENTRALIZED_PATH_TEST_PASSED')
"""]
let pipeB2 = Pipe()
procB2.standardOutput = pipeB2
try? procB2.run()
procB2.waitUntilExit()
let outputB2 = String(data: pipeB2.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
let b2Passed = outputB2.contains("CENTRALIZED_PATH_TEST_PASSED")
assertTrue(b2Passed, "REGRESSION FIXED: Centralized output path sanitization function handles all edge cases correctly")

// =========================================================================
// REGRESSION TEST A1: Hermetic Python Environment Modules Verification
// Pipeline must have 'backports.zstd' and 'nsz' available.
// =========================================================================
print("\n--- Regression Test A1: Python Environment Missing Modules Check ---")
let procA1 = Process()
procA1.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
procA1.arguments = ["-c", """
import sys
from pathlib import Path
sys.path.insert(0, '\(testLauncherDir)')
import install_nsp

py_bin = install_nsp.get_hermetic_python()
assert py_bin and Path(py_bin).is_file()

import subprocess
test_code = '''
for m in ('lz4.block', 'capstone', 'fontTools', 'backports.zstd', 'nsz'):
    __import__(m)
print("ALL_REQUIRED_MODULES_PRESENT")
'''
res = subprocess.run([str(py_bin), "-c", test_code], capture_output=True, text=True)
assert "ALL_REQUIRED_MODULES_PRESENT" in res.stdout
print("HERMETIC_MODULES_VERIFIED")
"""]
let pipeA1 = Pipe()
procA1.standardOutput = pipeA1
try? procA1.run()
procA1.waitUntilExit()
let outputA1 = String(data: pipeA1.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
print("  " + outputA1.trimmingCharacters(in: .whitespacesAndNewlines))
assertTrue(outputA1.contains("HERMETIC_MODULES_VERIFIED"), "REGRESSION FIXED: Hermetic Python has backports.zstd and nsz available without error")

// =========================================================================
// REGRESSION TEST A2: install_nsp.py uses get_hermetic_python()
// =========================================================================
print("\n--- Regression Test A2: install_nsp.py Hermetic Python Integration ---")
let installNspSource = (try? String(contentsOfFile: installNspPath, encoding: .utf8)) ?? ""
let usesHermetic = installNspSource.contains("get_hermetic_python()") && !installNspSource.contains("\"--with\", \"zstandard\"")
assertTrue(usesHermetic, "REGRESSION FIXED: install_nsp.py uses get_hermetic_python() and does not rely on fragile uv run flags")

// =========================================================================
// REGRESSION TEST C1: Stage Misclassification Prevention (Shader Keyword in Log)
// Log lines with 'shader' before an error must NOT bump stage to Stage 4.
// =========================================================================
print("\n--- Regression Test C1: Stage Misclassification Prevention ---")
let procC1 = Process()
procC1.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
procC1.arguments = ["-c", """
import sys, json
sys.path.insert(0, '\(testLauncherDir)')
import install_nsp

stage = 'Stage 1/7: Initializing'
prog = 0.08

# A log message mentioning 'shader' must NOT bump stage
noisy_line = '12 shader tables were made from profile and 4 shaders found'
stage, prog, msg = install_nsp.update_stage_from_line(noisy_line, stage, prog)
assert stage == 'Stage 1/7: Initializing', f'Stage misclassified to {stage} on plain log text'
assert prog == 0.08

# Another noisy message
noisy_line2 = 'shader split was previously cached in work/shader'
stage, prog, msg = install_nsp.update_stage_from_line(noisy_line2, stage, prog)
assert stage == 'Stage 1/7: Initializing', f'Stage misclassified to {stage} on cache log text'

# Only an explicit engine stage event transitions stage
event_json = json.dumps({'ev': 'stage', 'name': 'shader split', 'step': 'starting'})
stage, prog, msg = install_nsp.update_stage_from_line(event_json, stage, prog)
assert stage == 'Stage 4/7: Translating Maxwell Shaders to Metal', f'Failed explicit stage transition: {stage}'
assert prog == 0.65

print('STAGE_MISCLASSIFICATION_TEST_PASSED')
"""]
let pipeC1 = Pipe()
procC1.standardOutput = pipeC1
try? procC1.run()
procC1.waitUntilExit()
let outputC1 = String(data: pipeC1.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
assertTrue(outputC1.contains("STAGE_MISCLASSIFICATION_TEST_PASSED"), "REGRESSION FIXED: Stage misclassification prevented via deterministic JSON events")

// =========================================================================
// REGRESSION TEST C2: Runtime Privacy Sanitizer (/Volumes/<vol>/<user>, Tracebacks, Titles)
// =========================================================================
print("\n--- Regression Test C2: Runtime Privacy Sanitizer ---")
let procC2 = Process()
procC2.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
procC2.arguments = ["-c", """
import sys, os, getpass
sys.path.insert(0, '\(testLauncherDir)')
import install_nsp

# 1. Volume user path
vol_path = '/Volumes/Home/kelvinng/.cache/uv/build.log'
sanitized_vol = install_nsp.sanitize_log_text(vol_path)
assert 'kelvinng' not in sanitized_vol, f'Failed to strip username from volume path: {sanitized_vol}'
assert '/Volumes/Home/~/' in sanitized_vol, f'Expected /Volumes/Home/~/, got: {sanitized_vol}'

# 2. Arbitrary external drive with user path
ext_path = '/Volumes/MediaBackup/Users/steve/Games/Mario Kart 8.app'
sanitized_ext = install_nsp.sanitize_log_text(ext_path)
assert 'steve' not in sanitized_ext, f'Failed to strip username from external drive: {sanitized_ext}'

# 3. Python traceback
tb = '''Traceback (most recent call last):
  File "/Users/johndoe/Projects/MetalNX/install_nsp.py", line 42, in <module>
    raise RuntimeError("test")'''
sanitized_tb = install_nsp.sanitize_log_text(tb)
assert 'johndoe' not in sanitized_tb, f'Failed to sanitize traceback username: {sanitized_tb}'
assert 'File "~/Projects/MetalNX/install_nsp.py"' in sanitized_tb, f'Traceback path not normalized: {sanitized_tb}'

# 4. Volume with space in name
vol_space_path = '/Volumes/External SSD/steve/cache/build.log'
sanitized_space = install_nsp.sanitize_log_text(vol_space_path)
assert 'steve' not in sanitized_space, f'Failed to strip username from volume with space: {sanitized_space}'

# 5. Current user (including case insensitivity)
curr_user = getpass.getuser()
if len(curr_user) > 1:
    user_line = f'Permission denied for user {curr_user} on /tmp'
    sanitized_user = install_nsp.sanitize_log_text(user_line)
    assert curr_user not in sanitized_user, f'Current username not sanitized: {sanitized_user}'
    assert '~user~' in sanitized_user, f'Expected ~user~ replacement, got: {sanitized_user}'

    # Case insensitive
    user_upper = f'/Volumes/Ext/Home/{curr_user.upper()}/game.nsp'
    sanitized_upper = install_nsp.sanitize_log_text(user_upper)
    assert curr_user.upper() not in sanitized_upper, f'Uppercase username not sanitized: {sanitized_upper}'

print('PRIVACY_SANITIZER_TEST_PASSED')
"""]
let pipeC2 = Pipe()
procC2.standardOutput = pipeC2
try? procC2.run()
procC2.waitUntilExit()
let outputC2 = String(data: pipeC2.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
assertTrue(outputC2.contains("PRIVACY_SANITIZER_TEST_PASSED"), "REGRESSION FIXED: Runtime privacy sanitizer clears /Volumes/<vol>/<user>, tracebacks, and usernames")

// =========================================================================
// REGRESSION TEST C3: is_valid_repo & Engine Version Stamp Verification
// =========================================================================
print("\n--- Regression Test C3: is_valid_repo & Engine Version Stamp ---")
let procC3 = Process()
procC3.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
procC3.arguments = ["-c", """
import sys, tempfile, json
from pathlib import Path
sys.path.insert(0, '\(testLauncherDir)')
import install_nsp

with tempfile.TemporaryDirectory() as td:
    tpath = Path(td)
    # 1. Incomplete repo (only Program.cs, missing others)
    (tpath / 'dm/tools/nx_extract').mkdir(parents=True)
    (tpath / 'dm/tools/nx_extract/Program.cs').write_text('// dummy')
    assert not install_nsp.is_valid_repo(tpath), 'Incomplete repo must be rejected'

    # 2. Add all required files
    (tpath / 'scripts').mkdir(parents=True, exist_ok=True)
    (tpath / 'scripts/build_ipa_from_nsp.py').write_text('# dummy')
    (tpath / 'dm/host').mkdir(parents=True, exist_ok=True)
    (tpath / 'dm/host/Makefile').write_text('# dummy')
    (tpath / 'dm/mac').mkdir(parents=True, exist_ok=True)
    (tpath / 'dm/mac/pack_app.py').write_text('# dummy')
    (tpath / 'dm/gfx/tools').mkdir(parents=True, exist_ok=True)
    (tpath / 'dm/gfx/tools/pso_offline.py').write_text('# dummy')

    # Without stamp or git, rejected
    assert not install_nsp.is_valid_repo(tpath), 'Unstamped repo must be rejected'

    # With mismatched stamp, rejected
    stamp_file = tpath / '.metalnx_engine_stamp.json'
    stamp_file.write_text(json.dumps({'engine_version': '2.1.0'}))
    assert not install_nsp.is_valid_repo(tpath), 'Mismatched engine stamp must be rejected'

    # With tampered commit stamp, rejected
    stamp_file.write_text(json.dumps({
        'engine_version': install_nsp.LAUNCHER_VERSION,
        'pinned_commit': 'tampered_fake_commit'
    }))
    assert not install_nsp.is_valid_repo(tpath), 'Tampered commit stamp must be rejected'

    # With matching stamp, accepted
    stamp_file.write_text(json.dumps({
        'engine_version': install_nsp.LAUNCHER_VERSION,
        'pinned_commit': install_nsp.PINNED_ENGINE_COMMIT
    }))
    assert install_nsp.is_valid_repo(tpath), 'Matching engine stamp must be accepted'

print('ENGINE_STAMP_VALIDATION_PASSED')
"""]
let pipeC3 = Pipe()
procC3.standardOutput = pipeC3
try? procC3.run()
procC3.waitUntilExit()
let outputC3 = String(data: pipeC3.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
assertTrue(outputC3.contains("ENGINE_STAMP_VALIDATION_PASSED"), "REGRESSION FIXED: Engine repository validation enforces required files and pinned version stamp")

// =========================================================================
// REGRESSION TEST C4: pso_pairs.tsv Offline Prebuilding & Packaging
// =========================================================================
print("\n--- Regression Test C4: pso_pairs.tsv Offline Prebuilding & Packaging ---")
let procC4 = Process()
procC4.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
procC4.arguments = ["-c", """
import sys, subprocess
from pathlib import Path
sys.path.insert(0, '\(testLauncherDir)')
import install_nsp

repo = install_nsp.find_repo_root()
assert repo is not None, 'Could not find repo root'

# 1. Verify dm/mac/pack_app.py has --pso-pairs argument support
pack_app_py = repo / 'dm/mac/pack_app.py'
assert pack_app_py.is_file()
res = subprocess.run(['/usr/bin/python3', str(pack_app_py), '--help'], capture_output=True, text=True)
assert '--pso-pairs' in res.stdout, '--pso-pairs option missing from dm/mac/pack_app.py'

# 2. Verify scripts/build_ipa_from_nsp.py has pso_pairs handling
build_ipa_py = repo / 'scripts/build_ipa_from_nsp.py'
content = build_ipa_py.read_text()
assert 'pso_pairs.tsv' in content, 'pso_pairs.tsv missing from build_ipa_from_nsp.py'
assert '--pairs' in content, '--pairs invocation missing from build_ipa_from_nsp.py'

print('PSO_PAIRS_TEST_PASSED')
"""]
let pipeC4 = Pipe()
procC4.standardOutput = pipeC4
try? procC4.run()
procC4.waitUntilExit()
let outputC4 = String(data: pipeC4.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
assertTrue(outputC4.contains("PSO_PAIRS_TEST_PASSED"), "REGRESSION FIXED: Upstream pso_pairs.tsv packaging and offline prebuilding verified")

// Summary
print("\n==================================================")
print("TEST SUMMARY: \(testsPassed)/\(testsRun) passed (\(testsFailed) failed)")
print("==================================================")

if testsFailed > 0 {
    exit(1)
} else {
    exit(0)
}
