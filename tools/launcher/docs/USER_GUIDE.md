# MetalNX Control Center — Comprehensive User Guide

Welcome to **MetalNX**, the native Apple Silicon graphics control center and 1-click Switch-to-Mac port studio.

---

## Table of Contents
1. [Overview & Prerequisites](#1-overview--prerequisites)
2. [First-Time Launch & Permissions](#2-first-time-launch--permissions)
3. [Installing Games with 1-Click Port Studio](#3-installing-games-with-1-click-port-studio)
4. [Package Compatibility Verifier](#4-package-compatibility-verifier)
5. [Tuning Graphics & Apple MetalFX](#5-tuning-graphics--apple-metalfx)
6. [Enabling Community Recipes & 60 FPS Patches](#6-enabling-community-recipes--60-fps-patches)
7. [Browsing the 72-Game Offline Database](#7-browsing-the-72-game-offline-database)
8. [In-Game Controls & Hotkeys](#8-in-game-controls--hotkeys)
9. [Configuration File (`env.txt`) Reference](#9-configuration-file-envtxt-reference)
10. [Troubleshooting & FAQ](#10-troubleshooting--faq)

---

## 1. Overview & Prerequisites

### How MetalNX Works
Unlike conventional emulation layers, games converted by `nxnative` run raw ARM64 machine instructions natively on Apple Silicon cores. Maxwell GPU draw calls and shaders are recompiled directly into native Apple Metal Shading Language (MSL).

### Prerequisites
* **macOS 13.0 (Ventura) or newer** (macOS Sonoma / Sequoia recommended).
* **Apple Silicon Mac** (M1, M2, M3, M4 or Pro/Max/Ultra).
* **Nintendo Switch Decryption Keys (`prod.keys`)**:
  * MetalNX automatically discovers keys from `~/.switch/prod.keys`, `~/.config/Ryujinx/system/prod.keys`, or `~/Library/Application Support/yuzu/keys/prod.keys`.
* **Game Package Files**: Your legally dumped `.nsp` or `.nsz` base game and update files.

---

## 2. First-Time Launch & Permissions

When opening MetalNX for the first time:
1. Double-click `MetalNX.app` (or launch from Spotlight with `⌘ Space -> MetalNX`).
2. An onboarding sheet will request standard system permissions:
   * **Full Disk Access**: Required so MetalNX can inspect NSP files from external USB-C drives or your `~/Downloads` directory.
   * **Applications Folder Access**: Enables MetalNX to install compiled native games directly to `/Applications`.
3. Click **Grant Permissions** or configure in **System Settings -> Privacy & Security**.

---

## 3. Installing Games with 1-Click Port Studio

![1-Click Port Studio](screenshots/03_one_click_port_installer.png)

1. Open MetalNX and click the **1-Click Port** tab at the top.
2. In **Base Game Package**, click **Browse** and select your base `.nsp` or `.nsz` file.
3. In **Update Package**, select your game's official update (e.g. `v1.9.0` for Zelda BotW, or `v4.0.0` for Mario Kart 8).
4. Verify your `prod.keys` are detected in the **Keys File** field.
5. Click **Build Native Mac Port**.
6. The installer executes a 7-stage automated pipeline:
   * **Stage 1**: Package surveying & decryption verification.
   * **Stage 2**: RomFS & asset tree extraction.
   * **Stage 3**: ARM64 executable binary rewriting.
   * **Stage 4**: Maxwell shader translation to Apple Metal.
   * **Stage 5**: Native macOS Cocoa host shell compilation.
   * **Stage 6**: Metal pipeline state object prebuilding.
   * **Stage 7**: High-density icon embedding, code-signing, and installation to `/Applications`.
7. Once finished, MetalNX automatically switches to the **Tuning** tab with your new game ready to play.

---

## 4. Package Compatibility Verifier

When selecting an NSP in the 1-Click Port studio, the built-in verifier automatically checks whether your update is tested and certified:

| Badge | Meaning | Action |
| :--- | :--- | :--- |
| 🟢 **✓ Verified Compatible Release** | Exact match with tested benchmarks (e.g. Zelda BotW `1.9.0`). | Optimal 60 FPS patches and recipes will be applied automatically. |
| 🟡 **⚠️ Untested Update Version** | The game is known, but the update version is unverified. | Installation proceeds, but shader stubs or patches might differ from official benchmarks. |
| 🔵 **ℹ️ Untested Game** | The Title ID is not present in the tested database. | Installation will attempt a provisional survey; stability is unverified. |

---

## 5. Tuning Graphics & Apple MetalFX

![Tuning Control Center](screenshots/01_tuning_control_center.png)

Navigate to the **Tuning** tab to customize rendering parameters:
* **Resolution Scale Slider**:
  * Set internal rendering resolution from `0.50×` up to `2.00×`.
  * *MacBook Air recommendation*: `0.85×` (paired with MetalFX delivers crisp 1080p/1440p visuals while preventing thermal throttling).
  * *Mac Studio / Pro / Max recommendation*: `1.00×` or `1.25×`.
* **Target Frame Rate**: Choose between `30 FPS`, `60 FPS`, or `Uncapped`.
* **Apple MetalFX AI Upscaling**:
  * **Profile**: `Ultra Performance`, `Performance`, `Balanced`, or `Ultra Quality`.
  * **Color Space**: Perceptual (sRGB) vs. Linear (HDR).
* **Anisotropic Filtering**: `1×`, `2×`, `4×`, `8×`, or `16×` texture sampling for oblique surfaces.
* **Async Metal PSO Compilation**: Keep enabled to eliminate shader stutters by pre-compiling Metal pipeline state objects in background worker threads.
* Click **Save Settings** to persist your configuration. The green **✓ Settings Verified** checkmark confirms settings are written to disk.

---

## 6. Enabling Community Recipes & 60 FPS Patches

![Recipes & Patches](screenshots/02_recipes_and_patches.png)

Navigate to the **Recipes & Patches** tab to enable game-specific community fixes:
* **60 FPS Target & VFR Interval Pacing**: Removes 30 FPS console locks and adjusts game tick pacing.
* **Apple MetalFX AI Spatial Scaler**: Activates neural spatial upscaling.
* **Docked Console Mode (1080p Profile)**: Forces `DM_OPMODE=1` so the game engine loads higher-resolution texture LODs.
* **16× Anisotropic Filtering**: Sharpens distant textures and ground terrain.
* **One-Click Apply All**: Tap **Apply All Optimal Recipes** at the bottom bar to enable all recommended recipes simultaneously.

---

## 7. Browsing the 72-Game Offline Database

MetalNX includes an offline database of all 72 registered Switch titles:
* Click the **Database (72)** button in the top toolbar or game shelf.
* Search games by Title, Title ID, or Engine.
* View tested update versions, target FPS, and specific unsupported version notes for any title.

---

## 8. In-Game Controls & Hotkeys

While playing any native game port:

| Shortcut | Action |
| :--- | :--- |
| **`⌘M`** | Toggle Apple MetalFX AI Upscaling on/off (shows on-screen notification) |
| **`⌘F`** | Toggle Fullscreen / Windowed display mode |
| **`⌘Q`** | Quit game cleanly |

---

## 9. Configuration File (`env.txt`) Reference

Each game's configuration is stored at:
`~/Library/Application Support/nxnative/<TitleID>/env.txt`

Example:
```bash
# Zelda: Breath of the Wild (01007EF00011E000)
DM_OPMODE=1
DM_PRESENT_SNAP=1
NVN_RESOLUTION_SCALE=0.85
NVN_ENABLE_METALFX=1
NVN_METALFX_PROFILE=balanced
NVN_METALFX_COLORSPACE=perceptual
NVN_TARGET_FPS=60
NVN_ASYNC_SHADERS=1
NVN_ANISOTROPY=16
DM_DISABLE_STUTTER_SPIN=0
```

---

## 10. Troubleshooting & FAQ

#### Q: The game launches with audio but no video?
Ensure **MetalFX Spatial** is supported on your GPU (standard on all Apple Silicon M1-M4 chips). Try lowering resolution scale to `0.85×`.

#### Q: My controller is not responding?
Connect your Nintendo Switch Pro Controller, PlayStation DualSense, or Xbox Wireless Controller via macOS Bluetooth. MetalNX ports map macOS `GCController` events natively to Switch HID.

#### Q: How do I update a game after installation?
Open the **1-Click Port** tab, select the base NSP and the new update NSP, and rebuild the port. MetalNX preserves your save data located at `~/Library/Application Support/nxnative/<TitleID>/save/`.
