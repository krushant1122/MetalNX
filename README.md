<div align="center">

<img src="tools/launcher/docs/screenshots/02_recipes_and_patches.png" width="80%" alt="MetalNX Control Center" />

# MetalNX

**Native Apple Silicon graphics control center and 1-click Switch-to-Mac port studio.**

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-M1%20M2%20M3%20M4-blue?style=flat-square&logo=apple)](https://www.apple.com/mac/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)](https://swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-51%2F51_passing-brightgreen?style=flat-square)](#automated-tests)
[![Release](https://img.shields.io/badge/Download-v2.0.8_DMG-blue?style=flat-square)](https://github.com/krushant1122/MetalNX/releases/tag/v2.0.8)

[**Download MetalNX-2.0.8.dmg**](https://github.com/krushant1122/MetalNX/releases/tag/v2.0.8) · [User Guide](#user-guide) · [Compatibility Database](#compatibility-database) · [Build from Source](#build-from-source)

</div>

---

> **Not an emulator.** Games run their own native ARM64 machine code directly on Apple Silicon. Maxwell GPU shaders are recompiled once into native Apple Metal Shading Language (MSL). MetalNX is the graphical control center built on top of the `nxnative` engine.

---

## Screenshots

<p align="center">
  <img src="tools/launcher/docs/screenshots/02_recipes_and_patches.png" width="48%" alt="Recipes & Patches Studio — Zelda: Breath of the Wild" />
  <img src="tools/launcher/docs/screenshots/01_tuning_control_center.png" width="48%" alt="Tuning Control Center — Graphics & MetalFX" />
</p>


---

## Features

### 🎛️ Tuning Control Center
Form-aligned performance rails following macOS system preferences conventions — settings on the left, controls on the right:

| Setting | Range | Notes |
|:---|:---|:---|
| Resolution Scale | `0.50×` → `2.00×` | Paired with MetalFX, `0.85×` renders razor-sharp 1440p |
| Target Frame Rate | `30 / 60 / Uncapped` | Auto v-sync negotiation |
| Apple MetalFX AI Upscaling | `Ultra Perf / Perf / Balanced / Ultra Quality` | Neural spatial super-resolution |
| Anisotropic Filtering | `1× / 2× / 4× / 8× / 16×` | Hardware texture sharpening |
| Async Metal PSO Compilation | Toggle | Eliminates shader stutter |

### 🧪 Recipes & Patches Studio
Per-game community recipes parsed from the engine database. Toggle individually or **Apply All Optimal** in one tap:

- **60 FPS Target & VFR Interval Pacing** — removes the 30 FPS console lock, syncs internal tick clocks
- **Apple MetalFX Spatial Upscaler** — AI super-resolution from lightweight internal buffers
- **Async Shader Workers** — pre-compiles Metal PSOs across background threads before presentation
- **Docked Console Mode (1080p Profile)** — forces high-res texture LODs and expanded draw distance
- **16× Anisotropic Filtering** — sharpens ground textures at oblique viewing angles
- **Present Snap Buffering** — aligns presentation timestamps with ProMotion and 60Hz displays
- **Metal Performance HUD** — real-time FPS, frame time, and GPU load overlay

### Compatibility Database
Ships with an offline, self-contained catalog for all 72 registered Switch titles:
- Tested update versions (e.g. Zelda: BotW `1.9.0 (v1114112)`, MK8D `4.0.0/4.0.1`, SSBU `13.0.3`)
- Unsupported version advisories explaining missing shader dumps or patch stubs
- Engine identification, target FPS, and custom patch registration per title

### 🔍 Package Compatibility Verifier
Drop an `.nsp` or `.nsz` in the installer tab for instant certification:

| Badge | Meaning |
|:---|:---|
| 🟢 **Verified Compatible Release** | Exact match — optimal patches applied automatically |
| 🟡 **Untested Update Version** | Game known, update not benchmarked |
| 🔵 **Untested Game** | Title ID not in database — provisional install |

### ⚡ 1-Click Native Port Installer
Converts raw Switch dumps into standalone macOS apps with a 7-stage pipeline:

1. Package surveying & key verification
2. RomFS & asset tree extraction
3. ARM64 binary rewriting & calling convention translation
4. Maxwell → Metal Shading Language shader compilation
5. Native macOS Cocoa host shell compilation
6. Metal Pipeline State Object prebuilding (Metal-TT)
7. High-density icon embedding, code-signing & `/Applications` deployment

Real-time progress bar, live ETA countdown, and full compiler terminal log throughout.

### 🧠 Hardware-Aware Profiles
Automatically detects your Mac and recommends settings:
- **MacBook Air (fanless)** → conservative `0.85×` scale, MetalFX Balanced, 60 FPS cap to prevent thermal throttling
- **Mac Pro / Studio / Max / Ultra** → `1.00×–1.50×`, uncapped FPS, 16× AF

---

## Requirements

- macOS 13.0 (Ventura) or newer
- Apple Silicon Mac — M1, M2, M3, or M4 (any tier)
- Nintendo Switch decryption keys (`prod.keys`)
- Legally dumped game `.nsp` / `.nsz` base and update files

---

## Installation

### Option A — Drag-and-Drop DMG (Recommended)

1. [**Download MetalNX-2.0.0.dmg**](https://github.com/krushant1122/MetalNX/releases/tag/v2.0.0)
2. Mount the DMG and drag **MetalNX** into `/Applications`
3. Launch from Spotlight (`⌘ Space → MetalNX`) or Launchpad

### Build from Source

```bash
git clone https://github.com/krushant1122/MetalNX.git
cd MetalNX

# Compile, bundle, sign, create DMG, and install to /Applications
./tools/launcher/build.sh --install

open "/Applications/MetalNX.app"
```

---

## User Guide

### First Launch & Permissions
On first open, grant the following in the startup sheet (or via **System Settings → Privacy & Security**):
- **Full Disk Access** — required to read `.nsp` files from external drives or `~/Downloads`
- **Applications Folder** — required to install compiled game bundles to `/Applications`

### Porting a Game (1 Click)
1. Open the **1-Click Port** tab
2. Click **Browse** under *Base Game Package* → select your `.nsp` or `.nsz`
3. Click **Browse** under *Update Package* → select the game's update (e.g. `v1.9.0` for BotW)
4. Verify `prod.keys` are detected, or select your keyfile manually
5. Click **Build Native Mac Port**
6. Watch the 7-stage progress bar and live ETA — finished games open automatically in the Tuning tab

### Tuning Graphics
1. Select your game from the cover shelf at the top
2. Click **Auto-Setup Config** for hardware-matched defaults
3. Adjust sliders — on MacBook Air, `0.85×` resolution + MetalFX Balanced is the sweet spot
4. Click **Save Settings** — the green **✓ Settings Verified** badge confirms disk write

### Enabling Recipes
1. Switch to the **Recipes & Patches** tab
2. Select your game from the shelf — a green **Verified Release Active** banner confirms your version
3. Toggle individual recipes or click **Apply All Optimal Recipes**

### In-Game Shortcuts

| Shortcut | Action |
|:---|:---|
| `⌘M` | Toggle MetalFX AI Upscaling |
| `⌘F` | Toggle Fullscreen / Windowed |
| `⌘Q` | Quit cleanly |

---

## Configuration Reference

Per-game settings live at `~/Library/Application Support/nxnative/<TitleID>/env.txt`:

```bash
# Zelda: Breath of the Wild — 01007EF00011E000
DM_OPMODE=1                    # Docked mode (1080p asset profile)
DM_PRESENT_SNAP=1              # ProMotion-aligned frame presentation
NVN_RESOLUTION_SCALE=0.85      # Internal render resolution
NVN_ENABLE_METALFX=1           # Apple MetalFX spatial upscaling
NVN_METALFX_PROFILE=balanced   # Upscaler quality profile
NVN_TARGET_FPS=60              # 60 FPS target with VFR interval pacing
NVN_ASYNC_SHADERS=1            # Background Metal PSO compilation
NVN_ANISOTROPY=16              # 16× anisotropic texture filtering
```

---

## Automated Tests

45 automated Swift tests across 9 suites — run locally:

```bash
./tools/launcher/tests/run_tests.sh
# TEST SUMMARY: 45/45 passed (0 failed)
```

| Suite | Coverage |
|:---|:---|
| Game Detection | Real BotW bundle identification, Title ID extraction, version parsing |
| False-Positive Rejection | Calculator, TextEdit, Safari, MetalNX itself never appear as games |
| Synthetic Detection | Mario Kart 8D constructed bundle — correct Title ID & metadata |
| Config Path Resolution | `~/Library/Application Support/nxnative/<TitleID>/env.txt` |
| Icon Extraction | 512×512 `AppIcon.icns` resolution validation |
| Database Loading | All 72 titles with Title IDs, engines, FPS targets, recipes |
| Package Verifier | VERIFIED_SUPPORTED / UNTESTED_VERSION / UNTESTED_GAME classification |
| Recipe Preseeding | `env.txt` disk write and read-back verification |
| Python CLI | `--verify` flag, update Title ID normalization (`0x800` subtraction) |

---

## Project Structure

```
tools/launcher/
├── LauncherApp.swift          # SwiftUI Control Center (macOS 27 Liquid Obsidian)
├── games_db.json              # 72-game offline compatibility & recipe catalog
├── generate_games_db.py       # Extracts metadata from dm/games/ game profiles
├── install_nsp.py             # Port installer backend, verifier, recipe pre-seeder
├── build.sh                   # Compile → bundle → sign → DMG → install pipeline
├── make_icon.py               # Geometric MetalNX icon generator (AppIcon.icns)
├── docs/
│   ├── USER_GUIDE.md          # Comprehensive user guide
│   └── screenshots/           # UI screenshots
└── tests/
    ├── TestGameDetection.swift # 45-test automated suite
    └── run_tests.sh            # Test runner
```

---

## Credits & Architecture

MetalNX consists of two distinct layers:
1. **MetalNX Control Center & 1-Click Studio** (`tools/launcher/`):
   - Designed and built by **Krushant** ([@krushant1122](https://github.com/krushant1122)).
   - Native macOS SwiftUI control panel, 1-Click Port pipeline with real-time telemetry, 72-game offline recipe and compatibility catalog (`games_db.json`), package verifier, and zero-dependency bundled extraction runtime.
2. **nxnative Core Engine & Runtime** (`dm/`, `scripts/`):
   - Created by **seedds** ([nxnative](https://github.com/seedds/nxnative)).
   - Implements native Horizon SVC handling, Maxwell/NVN/Vulkan to Apple Metal shader translation, and static ARM64 module rewriting.
   - The engine is vendored in `dm/` to provide an all-in-one, plug-and-play experience for players without requiring manual git submodules or terminal compilation steps. Full reverse engineering credit for the underlying runtime belongs to `seedds` and contributors.

---

## License

MIT — see [LICENSE](LICENSE). Third-party components keep their own licenses; see [`dm/third_party`](dm/third_party/README.md).

This project is not affiliated with Nintendo Co., Ltd. or any game publisher. Nothing from any game is included in this repository. Bring your own legally obtained game files and `prod.keys`.
