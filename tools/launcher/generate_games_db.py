#!/usr/bin/env python3
"""
Generates a comprehensive JSON database of all 72+ supported nxnative games,
including Title IDs, verified update versions, untested version warnings,
tested FPS targets, and game-specific patch recipes.
"""

import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
DM_GAMES = REPO_ROOT / "dm/games"
DB_OUT = HERE / "games_db.json"

sys.path.insert(0, str(DM_GAMES))
import game


def parse_readme_table():
    readme_path = DM_GAMES / "README.md"
    if not readme_path.is_file():
        return {}
    txt = readme_path.read_text(encoding="utf-8")
    info = {}
    in_table = False
    for line in txt.splitlines():
        if "| Game | Title ID |" in line:
            in_table = True
            continue
        if in_table and line.startswith("|"):
            parts = [p.strip() for p in line.split("|")[1:-1]]
            if len(parts) >= 6 and not parts[0].startswith("---"):
                tid_m = re.search(r"0100[0-9A-Fa-f]{12}", parts[1])
                if tid_m:
                    tid = tid_m.group(0).upper()
                    name_m = re.search(r"\[(.*?)\]", parts[0])
                    name = name_m.group(1) if name_m else parts[0]
                    info[tid] = {
                        "name": name,
                        "build_note": parts[2],
                        "sdk": parts[3],
                        "engine": parts[4],
                        "graphics": parts[5],
                    }
    return info


def get_game_recipes(tid, has_patches, fps_target):
    recipes = [
        {
            "id": "recipe_fps",
            "name": "60 FPS Target & Interval Pacing",
            "category": "Performance",
            "description": "Enforces 60 FPS frame interval pacing. For games with patches.py (e.g. Zelda, Astral Chain, Mario Kart), also synchronizes internal game ticks.",
            "envKey": "NVN_TARGET_FPS",
            "defaultValue": "60",
            "enabled": True,
            "hasPatchBytecode": has_patches,
        },
        {
            "id": "recipe_metalfx",
            "name": "Apple MetalFX AI Spatial Scaler",
            "category": "Graphics",
            "description": "Applies Apple Silicon neural spatial upscaling from internal resolution to native display with zero perceptible latency.",
            "envKey": "NVN_ENABLE_METALFX",
            "defaultValue": "1",
            "enabled": True,
            "hasPatchBytecode": False,
        },
        {
            "id": "recipe_async_shaders",
            "name": "Async Metal PSO Compilation",
            "category": "Performance",
            "description": "Compiles Metal Shading Language pipeline state objects across background worker threads before presentation, eliminating first-time stutter.",
            "envKey": "NVN_ASYNC_SHADERS",
            "defaultValue": "1",
            "enabled": True,
            "hasPatchBytecode": False,
        },
        {
            "id": "recipe_docked",
            "name": "Docked Power Profile (1080p)",
            "category": "System",
            "description": "Reports docked console power state to game logic to load maximum texture quality, shadow resolution, and draw distance.",
            "envKey": "DM_OPMODE",
            "defaultValue": "1",
            "enabled": True,
            "hasPatchBytecode": False,
        },
        {
            "id": "recipe_anisotropy",
            "name": "16× Anisotropic Texture Filtering",
            "category": "Graphics",
            "description": "Forces 16× anisotropic sampling on all 3D surface and terrain textures, sharpening oblique angles.",
            "envKey": "NVN_ANISOTROPY",
            "defaultValue": "16",
            "enabled": True,
            "hasPatchBytecode": False,
        },
        {
            "id": "recipe_present_snap",
            "name": "Present Snap GPU Pacing",
            "category": "Performance",
            "description": "Schedules present snapshots to prevent Apple Silicon GPU frequency drops on passively cooled Macs.",
            "envKey": "DM_PRESENT_SNAP",
            "defaultValue": "1",
            "enabled": True,
            "hasPatchBytecode": False,
        },
        {
            "id": "recipe_hud",
            "name": "Apple Metal Performance HUD",
            "category": "Telemetry",
            "description": "Draws macOS Metal developer performance overlay with real-time frame time graphs, GPU core usage, and memory pressure.",
            "envKey": "DM_METAL_HUD",
            "defaultValue": "0",
            "enabled": False,
            "hasPatchBytecode": False,
        },
    ]
    return recipes


def main():
    print("-> Reading dm/games database...")
    readme_map = parse_readme_table()
    all_g = game.all_games()
    print(f"-> Processing {len(all_g)} game profiles...")

    games_db = []

    for g in sorted(all_g, key=lambda x: x.get("name", x.id)):
        tid = g.id.upper()
        name = g.get("name", readme_map.get(tid, {}).get("name", tid))
        supported_versions = []
        for ver_key, disp, *mods in g.values("build"):
            mdict = dict([tuple(m.split("=", 1)) for m in mods])
            supported_versions.append({
                "versionCode": ver_key,
                "displayVersion": disp,
                "isTested": True,
                "mainBuildId": mdict.get("main", "")
            })

        rm = readme_map.get(tid, {})
        build_note = rm.get("build_note", "")
        engine = rm.get("engine", "Switch Native Engine")
        graphics = rm.get("graphics", "NVN")

        # Determine primary tested version display
        primary_disp = supported_versions[0]["displayVersion"] if supported_versions else build_note
        if not primary_disp:
            primary_disp = "Tested Version"

        has_patches = (g.dir / "patches.py").is_file()
        fps_target = g.get("fps_target", "60")

        unsupported_note = f"Older or unlisted game versions (e.g. Day-1 v1.0.0 without updates) lack registered shader pairs and 60 FPS patches. For guaranteed stability, use update {primary_disp}."
        if "base" in build_note.lower():
            unsupported_note = f"This title was tested on the base cartridge release ({build_note}). Updates may require a derived provisional profile."

        recipes = get_game_recipes(tid, has_patches, fps_target)

        entry = {
            "titleId": tid,
            "name": name,
            "engine": engine,
            "graphicsApi": graphics,
            "testedDisplayVersion": primary_disp,
            "testedBuildNote": build_note,
            "testedFps": int(fps_target) if fps_target.isdigit() and int(fps_target) > 0 else 60,
            "hasCustomPatches": has_patches,
            "supportedVersions": supported_versions,
            "unsupportedVersionsNote": unsupported_note,
            "recipes": recipes
        }
        games_db.append(entry)

    with open(DB_OUT, "w", encoding="utf-8") as f:
        json.dump(games_db, f, indent=2)

    print(f"✓ Generated {DB_OUT} with {len(games_db)} games ({DB_OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
