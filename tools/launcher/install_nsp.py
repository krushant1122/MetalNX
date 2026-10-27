#!/usr/bin/env python3
"""
MetalNX Native Port Installer Helper
Wraps nxnative's build_ipa_from_nsp.py to provide real-time streaming progress,
realistic stage weighting, dynamic ETA calculation, and telemetry for the SwiftUI Control Center.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent


def emit(status, progress=0.0, stage="", message="", eta_sec=None, elapsed_sec=0):
    data = {
        "status": status,
        "progress": round(progress, 3),
        "stage": stage,
        "message": message,
        "eta_seconds": int(eta_sec) if eta_sec is not None else None,
        "elapsed_seconds": int(elapsed_sec),
    }
    print(json.dumps(data), flush=True)


def find_default_keys():
    home = Path.home()
    candidates = [
        home / ".switch/prod.keys",
        home / ".config/Ryujinx/system/prod.keys",
        home / "Library/Application Support/yuzu/keys/prod.keys",
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None


def main():
    parser = argparse.ArgumentParser(description="Install Switch NSP as Mac Native Port")
    parser.add_argument("--base", help="Path to base game NSP/NSZ file")
    parser.add_argument("--update", help="Optional path to update NSP/NSZ file")
    parser.add_argument("--folder", help="Folder containing NSPs")
    parser.add_argument("--keys", help="Path to prod.keys (defaults to auto-detect)")
    parser.add_argument("--out", help="Output .app directory (default: /Applications)")
    args = parser.parse_args()

    start_time = time.time()

    # 1. Determine Keys
    keys_path = Path(args.keys) if args.keys else find_default_keys()
    if not keys_path or not keys_path.is_file():
        emit("ERROR", 0.0, "Initialization", "prod.keys not found! Place prod.keys in ~/.switch/prod.keys or select it manually.")
        sys.exit(1)

    emit("PROGRESS", 0.04, "Stage 1/7: Initializing", f"Using decryption keys from {keys_path.name}", eta_sec=120, elapsed_sec=0)

    # 2. Determine / Stage Source Folder
    staging_dir = None
    total_bytes = 0

    if args.folder and Path(args.folder).is_dir():
        nsp_dir = Path(args.folder).resolve()
        for f in nsp_dir.glob("*.ns*"):
            total_bytes += f.stat().st_size
    elif args.base and Path(args.base).is_file():
        cache_base = Path.home() / "Library/Caches/nxnative"
        cache_base.mkdir(parents=True, exist_ok=True)
        staging_dir = Path(tempfile.mkdtemp(prefix="port_stage_", dir=cache_base))
        nsp_dir = staging_dir

        base_p = Path(args.base)
        total_bytes += base_p.stat().st_size
        base_target = nsp_dir / base_p.name
        try:
            os.symlink(os.path.abspath(args.base), base_target)
        except OSError:
            shutil.copyfile(args.base, base_target)

        if args.update and Path(args.update).is_file():
            upd_p = Path(args.update)
            total_bytes += upd_p.stat().st_size
            update_target = nsp_dir / upd_p.name
            try:
                os.symlink(os.path.abspath(args.update), update_target)
            except OSError:
                shutil.copyfile(args.update, update_target)
    else:
        emit("ERROR", 0.0, "Initialization", "No valid base NSP or folder provided.")
        sys.exit(1)

    # Estimate expected total duration based on package size (rough benchmark: ~15MB/s on M1)
    size_mb = total_bytes / (1024 * 1024)
    estimated_total_sec = max(40.0, min(360.0, 30.0 + (size_mb * 0.035)))

    emit("PROGRESS", 0.08, "Stage 1/7: Preparing Packages", f"Indexed {round(size_mb, 1)} MB of Switch packages",
         eta_sec=estimated_total_sec, elapsed_sec=time.time() - start_time)

    # 3. Setup Environment
    env = os.environ.copy()
    home = str(Path.home())
    dotnet_dir = Path(home) / ".dotnet"
    if dotnet_dir.is_dir():
        env["DOTNET_ROOT"] = str(dotnet_dir)
        env["DOTNET_ROOT_ARM64"] = str(dotnet_dir)
        env["PATH"] = f"{dotnet_dir}:{env.get('PATH', '')}"

    build_script = REPO_ROOT / "scripts/build_ipa_from_nsp.py"
    if not build_script.is_file():
        emit("ERROR", 0.0, "Configuration", f"Could not find build script at {build_script}")
        sys.exit(1)

    cmd = [
        sys.executable,
        str(build_script),
        str(nsp_dir),
        "-k", str(keys_path),
        "--platform", "mac-app",
        "--progress", "lines",
    ]

    # Realistic stage milestone weights
    stage_progression = [
        (re.compile(r"survey|build nx_extract", re.I), 0.12, "Stage 1/7: Surveying Title & ExeFS"),
        (re.compile(r"extract|romfs", re.I), 0.32, "Stage 2/7: Extracting Game RomFS & Assets"),
        (re.compile(r"rewrite|checking the inputs|patch", re.I), 0.50, "Stage 3/7: Rewriting ARM64 Modules & Patches"),
        (re.compile(r"shader split|mac shaders|shader", re.I), 0.68, "Stage 4/7: Translating & Compiling Metal Shaders"),
        (re.compile(r"mac host|dmhost", re.I), 0.80, "Stage 5/7: Building Native Mac Host"),
        (re.compile(r"pipeline prebuild|pipeline archive|metal-tt", re.I), 0.90, "Stage 6/7: Prebuilding Pipeline Bases (Metal-TT)"),
        (re.compile(r"mac app|pack|signing", re.I), 0.96, "Stage 7/7: Packaging & Ad-hoc Code-signing App"),
    ]

    current_stage = "Stage 1/7: Preparing Packages"
    current_progress = 0.08

    try:
        proc = subprocess.Popen(
            cmd,
            cwd=str(REPO_ROOT),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            env=env
        )

        detected_app_path = None

        for line in proc.stdout:
            line_str = line.strip()
            if not line_str:
                continue

            now = time.time()
            elapsed = now - start_time

            # Check stage milestones
            for pattern, target_pct, stage_title in stage_progression:
                if pattern.search(line_str):
                    current_stage = stage_title
                    current_progress = max(current_progress, target_pct)
                    break

            # Dynamic ETA calculation: blend initial size estimate with rolling velocity
            if current_progress > 0.08 and elapsed > 2.0:
                measured_total = elapsed / current_progress
                blend = min(1.0, elapsed / 20.0) # Gradually favor measured velocity
                blended_total = (1.0 - blend) * estimated_total_sec + blend * measured_total
                remaining_sec = max(5.0, blended_total - elapsed)
            else:
                remaining_sec = max(10.0, estimated_total_sec - elapsed)

            # Check for completed app path in stdout
            m = re.search(r'(/[^:\n]+\.app)', line_str)
            if m and Path(m.group(1)).is_dir():
                detected_app_path = m.group(1)

            emit("PROGRESS", current_progress, current_stage, line_str, eta_sec=remaining_sec, elapsed_sec=elapsed)

        proc.wait()

        elapsed = time.time() - start_time

        if proc.returncode != 0:
            emit("ERROR", current_progress, current_stage, f"Build process failed with exit code {proc.returncode}", elapsed_sec=elapsed)
            sys.exit(proc.returncode)

        # 5. Finalize App Bundle
        final_app_path = None
        if detected_app_path and Path(detected_app_path).is_dir():
            final_app_path = detected_app_path
        else:
            found_apps = list(nsp_dir.glob("*.app"))
            if found_apps:
                final_app_path = str(found_apps[0])

        if final_app_path:
            app_name = Path(final_app_path).name
            dest_app = Path("/Applications") / app_name
            if Path(final_app_path).resolve() != dest_app.resolve():
                emit("PROGRESS", 0.98, "Stage 7/7: Installing", f"Moving {app_name} to /Applications...", eta_sec=2, elapsed_sec=elapsed)
                if dest_app.exists():
                    shutil.rmtree(dest_app)
                shutil.move(final_app_path, dest_app)
                final_app_path = str(dest_app)

            emit("SUCCESS", 1.0, "Port Ready!", f"Successfully installed port: {final_app_path}", eta_sec=0, elapsed_sec=elapsed)
        else:
            emit("SUCCESS", 1.0, "Port Ready!", "Port compilation finished successfully!", eta_sec=0, elapsed_sec=elapsed)

    finally:
        if staging_dir and staging_dir.exists():
            shutil.rmtree(staging_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
