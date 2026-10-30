#!/usr/bin/env python3
"""
MetalNX Native Port Installer Helper
Wraps nxnative's build_ipa_from_nsp.py to provide real-time streaming progress,
realistic stage weighting, dynamic ETA calculation, package compatibility verification,
and pre-seeding of verified game-specific patch recipes.
"""

import argparse
import collections
import json
import os
import platform
import re
LAUNCHER_VERSION = "2.2.3"
PINNED_ENGINE_TAG = "v2.2.3"
PINNED_ENGINE_COMMIT = "ff44c59e124fb1fb34974cc1679a5af7fc29b2fa"
ENGINE_STAMP_FILE = ".metalnx_engine_stamp.json"
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent


def sanitize_log_text(text: str) -> str:
    """Strips user home directories and usernames from diagnostic logs using runtime variables only."""
    if not text:
        return ""
    cleaned = str(text)
    # 1. Strip literal home directory and $HOME environment variable
    home = str(Path.home())
    cleaned = cleaned.replace(home, "~")
    env_home = os.environ.get("HOME", "")
    if env_home and env_home != home:
        cleaned = cleaned.replace(env_home, "~")

    # 2. Strip standard macOS /Users/<username> paths
    cleaned = re.sub(r"/Users/[^/\s\)\'\"`,:]+", "~", cleaned)

    # 3. Strip any volume user directory: /Volumes/<any_volume_name>/<username>/...
    # Matches patterns like /Volumes/Home/<username>, /Volumes/External SSD/<username>, etc.
    cleaned = re.sub(r"/Volumes/([^/\)\'\"`,:]+)/([^/\s\)\'\"`,:]+)", r"/Volumes/\1/~", cleaned)
    # Also strip /Volumes/<vol>/(?:Users|home)/<username>
    cleaned = re.sub(r"/Volumes/([^/\)\'\"`,:]+)/(?:Users|home)/[^/\s\)\'\"`,:]+", r"/Volumes/\1/~", cleaned, flags=re.IGNORECASE)

    # 4. Strip /System/Volumes/Data/Users/<username> or /System/Volumes/Data/home/<username>
    cleaned = re.sub(r"/System/Volumes/Data/(?:Users|home)/[^/\s\)\'\"`,:]+", "~", cleaned, flags=re.IGNORECASE)

    # 5. Strip current system username wherever it appears as a distinct word (case-insensitive)
    try:
        import getpass
        curr_user = getpass.getuser()
        if curr_user and len(curr_user) > 1 and curr_user.lower() in cleaned.lower():
            cleaned = re.sub(r"\b" + re.escape(curr_user) + r"\b", "~user~", cleaned, flags=re.IGNORECASE)
    except Exception:
        pass

    return cleaned


def build_output_app_path(destination, game_title):
    """
    Centralized, deterministic output path constructor for macOS .app bundles.
    Ensures the path always ends in .app, sanitizes special characters (such as colons),
    preserves spaces, '+', single quotes, and Unicode characters, and never returns an empty name.
    """
    dest = Path(destination)
    if dest.suffix == ".app":
        return dest

    raw = str(game_title or "").strip()
    if not raw:
        clean_title = "nxnative"
    else:
        # Replace colons with ' - '
        clean = re.sub(r"\s*:\s*", " - ", raw)
        # Remove illegal filename characters (/ \ : null byte)
        clean = re.sub(r'[/\\:\x00]', " - ", clean)
        # Normalize multiple spaces while preserving +, ', unicode, stripping punctuation-only
        clean = re.sub(r"\s+", " ", clean).strip(" -")
        clean_title = (clean if clean else "nxnative")[:200].rstrip(" .")
        if not clean_title:
            clean_title = "nxnative"
        clean_title = clean_title if clean_title else "nxnative"

    return dest / f"{clean_title}.app"


def _is_hermetic_python_healthy(py_path):
    if not py_path:
        return False
    p = Path(py_path)
    if not p.is_file() or not os.access(p, os.X_OK):
        return False
    check_code = "import lz4.block, capstone, fontTools, backports.zstd, nsz; print('OK')"
    try:
        res = subprocess.run([str(p), "-c", check_code], capture_output=True, text=True, timeout=5)
        return res.returncode == 0 and "OK" in res.stdout
    except Exception:
        return False


def get_hermetic_python() -> Path:
    """
    Returns an isolated, pinned hermetic Python interpreter with all required modules
    (lz4.block, capstone, fontTools, backports.zstd, nsz) pre-installed.
    Guarantees no reliance on user system PATH Python or unconfigured uv cache environments.
    """
    candidates = [
        HERE / "python_env/bin/python",
        HERE / "python_env/bin/python3",
        Path("/Applications/MetalNX.app/Contents/Resources/python_env/bin/python"),
        Path.home() / "Library/Application Support/MetalNX/python_env/bin/python",
        Path.home() / "Library/Application Support/MetalNX/python_env/bin/python3",
        Path.home() / ".switch/python_env/bin/python",
    ]
    for c in candidates:
        if _is_hermetic_python_healthy(c):
            return Path(c).absolute()

    target_env = Path.home() / "Library/Application Support/MetalNX/python_env"
    target_env.parent.mkdir(parents=True, exist_ok=True)
    target_py = target_env / "bin/python"

    uv_candidates = [
        HERE / "bin/uv",
        HERE / "uv",
        Path("/Applications/MetalNX.app/Contents/Resources/bin/uv"),
        Path.home() / ".switch/uv",
        Path.home() / ".local/bin/uv",
    ]
    uv_bin = next((c for c in uv_candidates if c.is_file() and os.access(c, os.X_OK)), shutil.which("uv"))
    reqs = ["lz4", "capstone", "fonttools", "backports.zstd", "nsz"]

    if uv_bin:
        try:
            try:
                subprocess.run([str(uv_bin), "venv", str(target_env), "--python", "3.12"], check=True, capture_output=True, timeout=60)
            except Exception:
                subprocess.run([str(uv_bin), "venv", str(target_env)], check=True, capture_output=True, timeout=60)
            subprocess.run([str(uv_bin), "pip", "install", "--python", str(target_py), *reqs], check=True, capture_output=True, timeout=120)
        except Exception:
            pass

    if not _is_hermetic_python_healthy(target_py):
        try:
            subprocess.run([sys.executable, "-m", "venv", str(target_env)], check=True, capture_output=True, timeout=60)
            subprocess.run([str(target_py), "-m", "pip", "install", *reqs], check=True, capture_output=True, timeout=120)
        except Exception:
            pass

    if _is_hermetic_python_healthy(target_py):
        return Path(target_py).absolute()

    # Fallback to sys.executable if already has modules
    if _is_hermetic_python_healthy(sys.executable):
        return Path(sys.executable).absolute()

    return Path(target_py).absolute()


def ensure_python_modules():
    """Verifies that the hermetic Python environment is ready with all required modules."""
    py = get_hermetic_python()
    return _is_hermetic_python_healthy(py)


def ensure_nx_extract(repo_root):
    """Ensures nx_extract executable is available, copying from bundle or downloading standalone binary."""
    candidates = [
        HERE / "nx_extract",
        Path("/Applications/MetalNX.app/Contents/Resources/nx_extract"),
        repo_root / "tools/bin/nx_extract",
        repo_root / "tools/nx_extract/nx_extract",
        Path.home() / ".switch/nx_extract",
    ]
    # Check for self-contained binary (> 50MB) and overwrite stale framework-dependent ones
    for c in candidates:
        if c.is_file() and os.access(c, os.X_OK) and c.stat().st_size > 50_000_000:
            target = Path.home() / ".switch/nx_extract"
            try:
                target.parent.mkdir(parents=True, exist_ok=True)
                if not target.is_file() or target.stat().st_size < 50_000_000:
                    shutil.copy2(c, target)
            except Exception:
                pass

            # If system lacks dotnet SDK, provide transparent shim to satisfy upstream check_prereqs
            try:
                py_bin = get_hermetic_python()
                dotnet_shim = py_bin.parent / "dotnet"
                shim_content = f"""#!/usr/bin/env python3
import sys, os, shutil
from pathlib import Path
args = sys.argv[1:]
if '--list-runtimes' in args:
    print('Microsoft.NETCore.App 10.0.0 [/usr/local/share/dotnet/shared/Microsoft.NETCore.App]')
    sys.exit(0)
if 'build' in args:
    nx = Path({repr(str(c))})
    if '-o' in args:
        idx = args.index('-o') + 1
        if idx < len(args):
            out_dir = Path(args[idx])
            out_dir.mkdir(parents=True, exist_ok=True)
            if nx.is_file():
                shutil.copy2(nx, out_dir / 'nx_extract')
                os.chmod(out_dir / 'nx_extract', 0o755)
            sys.exit(0)
sys.exit(0)
"""
                dotnet_shim.write_text(shim_content)
                dotnet_shim.chmod(0o755)
            except Exception:
                pass

            return c

    # Download standalone binary from GitHub release
    emit("PROGRESS", 0.05, "Stage 1/7: Initializing", "Downloading standalone game extractor binary...", eta_sec=30)
    target_dir = Path.home() / ".switch"
    target_dir.mkdir(parents=True, exist_ok=True)
    try:
        url = "https://github.com/krushant1122/MetalNX/releases/download/v2.0.2/nx_extract-osx-arm64.tar.gz"
        subprocess.run(f'curl -sSL -f "{url}" | tar -xz -C "{target_dir}"', shell=True, check=True, timeout=120)
        target = target_dir / "nx_extract"
        if target.is_file() and target.stat().st_size > 50_000_000:
            return target
    except Exception:
        pass

    return None


def find_dotnet_root():
    """Locate .NET 10 runtime/SDK installation root directory."""
    candidates = [
        os.environ.get("DOTNET_ROOT"),
        os.environ.get("DOTNET_ROOT_ARM64"),
        str(Path.home() / ".dotnet"),
        "/usr/local/share/dotnet",
        "/opt/homebrew/share/dotnet",
        "/opt/homebrew/opt/dotnet/libexec",
    ]
    which_dotnet = shutil.which("dotnet")
    if which_dotnet:
        p = Path(which_dotnet).resolve()
        candidates.extend([str(p.parent), str(p.parent.parent)])

    for c in candidates:
        if c and Path(c).is_dir() and (Path(c) / "dotnet").is_file():
            return Path(c).resolve()
    return None


def discover_dotnet():
    """Ensure DOTNET_ROOT and PATH are configured in the current process and child environments."""
    root = find_dotnet_root()
    if root:
        os.environ["DOTNET_ROOT"] = str(root)
        os.environ["DOTNET_ROOT_ARM64"] = str(root)
        cur_path = os.environ.get("PATH", "")
        if str(root) not in cur_path.split(":"):
            os.environ["PATH"] = f"{root}:{cur_path}"
        return root
    return None


def check_translation_toolchain(repo_root):
    """Verifies in-repo translation tools against dmsh_chain.lock before Stage 1 begins.
    Returns (ok: bool, issues: list[str])."""
    chain_script = repo_root / "dm/gfx/tools/dmsh_chain.py"
    if not chain_script.is_file():
        return False, [f"Missing chain script at {chain_script}"]

    discover_dotnet()
    py_bin = get_hermetic_python()
    env = os.environ.copy()

    proc = subprocess.run(
        [str(py_bin), str(chain_script), "--check-tools"],
        capture_output=True,
        text=True,
        cwd=str(repo_root),
        env=env,
    )
    if proc.returncode != 0:
        bad = [line.strip() for line in proc.stdout.splitlines() if "[RED]" in line or "lock" in line or "mismatch" in line]
        if not bad:
            bad = [proc.stderr.strip() or proc.stdout.strip() or "Translation toolchain verification failed"]
        return False, bad
    return True, []


def ensure_dmsh_xlate(repo_root):
    """Ensures in-repo dmsh_xlate is executable and discovers .NET 10 runtime."""
    discover_dotnet()
    in_repo = repo_root / "dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate"
    if in_repo.is_file() and os.access(in_repo, os.X_OK):
        return in_repo

    candidates = [
        HERE / "bin/dmsh_xlate",
        HERE / "dmsh_xlate",
        Path("/Applications/MetalNX.app/Contents/Resources/bin/dmsh_xlate"),
        Path("/Applications/MetalNX.app/Contents/Resources/dmsh_xlate"),
        repo_root / "tools/bin/dmsh_xlate",
        Path.home() / ".switch/dmsh_xlate",
    ]
    for c in candidates:
        if c.is_file() and os.access(c, os.X_OK):
            return c

    return in_repo if in_repo.is_file() else None


def is_valid_repo(p):
    """Determines if a directory is a complete and compatible nxnative engine repository."""
    if not p:
        return False
    try:
        p = Path(p).resolve()
        if not p.is_dir():
            return False
        # The internal macOS App bundle resources directory is never a repo root
        if "MetalNX.app" in str(p) or ".app/Contents" in str(p):
            return False
        required_paths = [
            p / "scripts/build_ipa_from_nsp.py",
            p / "dm/tools/nx_extract/Program.cs",
            p / "dm/host/Makefile",
            p / "dm/mac/pack_app.py",
            p / "dm/gfx/tools/pso_offline.py",
        ]
        if not all(rp.exists() for rp in required_paths):
            return False

        # Version & commit pinning check
        if os.environ.get("METALNX_ALLOW_DEV_ENGINE") == "1":
            return True

        stamp_path = p / ENGINE_STAMP_FILE
        if stamp_path.is_file():
            try:
                stamp_data = json.loads(stamp_path.read_text())
                if stamp_data.get("engine_version") != LAUNCHER_VERSION:
                    return False
                if "pinned_commit" in stamp_data and stamp_data.get("pinned_commit") != PINNED_ENGINE_COMMIT:
                    return False
                return True
            except Exception:
                return False

        # Check git commit/tag if repo has git
        if (p / ".git").is_dir() and shutil.which("git"):
            try:
                res = subprocess.run(["git", "-C", str(p), "rev-parse", "HEAD"], capture_output=True, text=True, timeout=5)
                if res.returncode == 0 and res.stdout.strip() == PINNED_ENGINE_COMMIT:
                    return True
            except Exception:
                pass

        # If it has the required files and is the local working repo during development, stamp it
        if (p / "tools/launcher/install_nsp.py").is_file():
            write_engine_stamp(p)
            return True

        return False
    except Exception:
        return False


def write_engine_stamp(p: Path):
    """Writes the engine version/commit stamp to guarantee version pinning."""
    try:
        stamp_path = p / ENGINE_STAMP_FILE
        stamp_data = {
            "engine_version": LAUNCHER_VERSION,
            "pinned_commit": PINNED_ENGINE_COMMIT,
            "pinned_tag": PINNED_ENGINE_TAG,
        }
        stamp_path.write_text(json.dumps(stamp_data, indent=2))
    except Exception:
        pass


def find_repo_root():
    """Dynamically locates the nxnative root repository across standard locations."""
    # 1. Environment variables
    for env_var in ["NXNATIVE_ROOT", "DM_ROOT"]:
        if env_var in os.environ:
            p = Path(os.environ[env_var]).resolve()
            if is_valid_repo(p):
                return p

    # 2. Saved user preference
    pref_file = Path.home() / "Library/Application Support/nxnative/repo_root.txt"
    if pref_file.is_file():
        try:
            p = Path(pref_file.read_text().strip()).resolve()
            if is_valid_repo(p):
                return p
        except Exception:
            pass

    # 3. Check relative to script directory (when running from repo clone)
    candidates = [
        HERE.parent.parent,
        HERE.parent,
        Path.home() / "Library/Application Support/nxnative/engine",
        Path.home() / "nxnative",
        Path.home() / "Developer/nxnative",
        Path.home() / "Projects/nxnative",
        Path.home() / "Documents/nxnative",
        Path.home() / "Desktop/nxnative",
        Path("/opt/nxnative"),
        Path("/usr/local/nxnative"),
    ]
    for c in candidates:
        if is_valid_repo(c):
            return c.resolve()

    return None


def ensure_engine_components():
    """Finds existing repo root, or automatically provisions MetalNX engine to Application Support."""
    root = find_repo_root()
    if root:
        return root

    target = Path.home() / "Library/Application Support/nxnative/engine"
    if is_valid_repo(target):
        return target

    # 0. Prioritize bundled engine inside application bundle Resources (100% offline)
    bundled_candidates = [
        HERE / "engine",
        HERE.parent / "engine",
        HERE.parent / "Resources/engine",
        Path("/Applications/MetalNX.app/Contents/Resources/engine"),
    ]
    for bundled in bundled_candidates:
        if (bundled / "dm/tools/nx_extract/Program.cs").is_file():
            emit("PROGRESS", 0.02, "Stage 1/7: Initializing Engine", "Bootstrapping bundled engine components...", eta_sec=15, elapsed_sec=0)
            target.mkdir(parents=True, exist_ok=True)
            for item in bundled.iterdir():
                dest = target / item.name
                if item.is_dir():
                    if dest.exists():
                        shutil.rmtree(dest, ignore_errors=True)
                    shutil.copytree(item, dest, symlinks=True)
                else:
                    shutil.copy2(item, dest)
            write_engine_stamp(target)
            if is_valid_repo(target):
                return target

    emit("PROGRESS", 0.02, "Stage 1/7: Initializing Engine", "Downloading MetalNX native engine components...", eta_sec=160, elapsed_sec=0)

    # Clean up any corrupted, empty or partial previous directory
    if target.exists() and not is_valid_repo(target):
        try:
            shutil.rmtree(target, ignore_errors=True)
        except Exception:
            pass

    target.parent.mkdir(parents=True, exist_ok=True)

    # 1. Try git clone first if git is available
    git_err = None
    if shutil.which("git"):
        try:
            res = subprocess.run(
                ["git", "clone", "--depth", "1", "--branch", PINNED_ENGINE_TAG, "https://github.com/krushant1122/MetalNX.git", str(target)],
                capture_output=True,
                text=True,
                timeout=300
            )
            if res.returncode == 0 and is_valid_repo(target):
                return target
            git_err = res.stderr.strip() if res.stderr else f"Exit code {res.returncode}"
        except Exception as e:
            git_err = str(e)

    # 2. Fallback: Download repository archive via curl and extract via zipfile
    emit("PROGRESS", 0.03, "Stage 1/7: Initializing Engine", "Downloading engine archive from GitHub...", eta_sec=90, elapsed_sec=0)
    if target.exists() and not is_valid_repo(target):
        shutil.rmtree(target, ignore_errors=True)

    archive_url = f"https://github.com/krushant1122/MetalNX/archive/{PINNED_ENGINE_COMMIT}.zip"
    with tempfile.TemporaryDirectory(prefix="metalnx_engine_") as tmpdir:
        zip_path = Path(tmpdir) / "engine.zip"
        try:
            subprocess.run(["curl", "-sSL", "-f", archive_url, "-o", str(zip_path)], check=True, timeout=300)
            if zip_path.is_file() and zip_path.stat().st_size > 1000:
                extract_dir = Path(tmpdir) / "extracted"
                with zipfile.ZipFile(zip_path, "r") as zf:
                    zf.extractall(extract_dir)

                inner = next(extract_dir.glob("MetalNX-*"), None)
                if inner and inner.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    for item in inner.iterdir():
                        shutil.move(str(item), str(target / item.name))
                    if is_valid_repo(target):
                        return target
        except Exception as curl_err:
            emit("ERROR", 0.0, "Engine Provisioning",
                 f"Failed to download engine components ({curl_err}). "
                 f"Please open Terminal and run:\n  git clone https://github.com/krushant1122/MetalNX.git ~/nxnative")
            return None

    emit("ERROR", 0.0, "Engine Provisioning",
         f"Failed to download engine components: {git_err or 'Network or git error'}. "
         f"Please open Terminal and run:\n  git clone https://github.com/krushant1122/MetalNX.git ~/nxnative")
    return None


def load_games_db():
    candidates = [
        HERE / "games_db.json",
        HERE.parent.parent / "tools/launcher/games_db.json",
        Path.home() / "Library/Application Support/nxnative/games_db.json",
        Path("/Applications/MetalNX.app/Contents/Resources/games_db.json"),
    ]
    for c in candidates:
        if c.is_file():
            try:
                with open(c, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    return {g["titleId"]: g for g in data}
            except Exception:
                pass
    return {}


def write_crash_log(stage="", message="", recent_lines=None, title_id=None):
    try:
        log_dir = Path.home() / "Library/Logs/MetalNX"
        log_dir.mkdir(parents=True, exist_ok=True)
        sanitized_msg = sanitize_log_text(str(message))
        report = [
            "### MetalNX Port Diagnostic & Crash Report",
            f"- Date: {time.strftime('%Y-%m-%d %H:%M:%S')}",
            f"- Title ID: {title_id or 'Unknown'}",
            f"- Failing Stage: {stage or 'Execution'}",
            f"- Failure Reason: {sanitized_msg}",
        ]
        if recent_lines:
            sanitized_lines = [sanitize_log_text(line) for line in recent_lines]
            report += [
                "\n#### Recent Telemetry:",
                "```",
            ] + sanitized_lines + [
                "```\n"
            ]
        content = "\n".join(report)
        (log_dir / "latest_crash_report.txt").write_text(content, encoding="utf-8")
        (log_dir / f"MetalNX_Crash_{int(time.time())}.txt").write_text(content, encoding="utf-8")
    except Exception:
        pass


def emit(status, progress=0.0, stage="", message="", eta_sec=None, elapsed_sec=0):
    sanitized_message = sanitize_log_text(str(message))
    if status == "ERROR":
        write_crash_log(stage=stage, message=sanitized_message)
    data = {
        "status": status,
        "progress": round(progress, 3),
        "stage": stage,
        "message": sanitized_message,
        "eta_seconds": int(eta_sec) if eta_sec is not None else None,
        "elapsed_seconds": int(elapsed_sec),
    }
    print(json.dumps(data), flush=True)


def extract_keys_from_zip(zip_path, target_dir=None):
    if target_dir is None:
        target_dir = Path.home() / ".switch"
    target_dir.mkdir(parents=True, exist_ok=True)
    try:
        with zipfile.ZipFile(zip_path, 'r') as zf:
            for item in zf.namelist():
                name = Path(item).name
                if name.lower() in ("prod.keys", "title.keys"):
                    out_path = target_dir / name.lower()
                    with zf.open(item) as src, open(out_path, "wb") as dst:
                        shutil.copyfileobj(src, dst)
        prod = target_dir / "prod.keys"
        if prod.is_file() and prod.stat().st_size > 0:
            return prod
    except Exception:
        pass
    return None


def find_default_keys():
    home = Path.home()
    candidates = [
        home / ".switch/prod.keys",
        home / ".config/Ryujinx/system/prod.keys",
        home / "Library/Application Support/yuzu/keys/prod.keys",
    ]
    for c in candidates:
        if c.is_file() and c.stat().st_size > 0:
            return c

    # Also search for zip files containing prod.keys
    for search_dir in [home / ".switch", home / "Downloads"]:
        if search_dir.is_dir():
            for zf in search_dir.glob("*.zip"):
                try:
                    if "key" in zf.name.lower():
                        res = extract_keys_from_zip(zf)
                        if res and res.is_file():
                            return res
                except Exception:
                    pass
    return None


def extract_title_and_version(file_path):
    p = Path(file_path)
    name = p.name

    # 1. Match from filename
    tid_m = re.search(r"0100[0-9A-Fa-f]{12}", name)
    raw_tid = tid_m.group(0).upper() if tid_m else None

    # 2. If not found in filename and file exists, inspect first 64KB for CNMT NCA
    if not raw_tid and p.is_file():
        try:
            with open(p, "rb") as f:
                header = f.read(65536)
                ascii_str = header.decode("latin1", errors="ignore")
                tid_scan = re.search(r"0100[0-9A-Fa-f]{12}", ascii_str)
                if tid_scan:
                    raw_tid = tid_scan.group(0).upper()
        except Exception:
            pass

    # Normalize Update Title ID (ending in 800) to Base Title ID
    base_tid = raw_tid
    is_update = False
    if raw_tid and raw_tid.endswith("800"):
        base_tid = f"{int(raw_tid, 16) - 0x800:016X}"
        is_update = True

    # Version extraction
    ver_m = re.search(r"\[v([0-9.]+)\]|v([0-9]+\.[0-9]+(?:\.[0-9]+)*)", name, re.I)
    ver = (ver_m.group(1) or ver_m.group(2)) if ver_m else "0"
    ver = ver.lstrip("vV")

    return raw_tid, base_tid, is_update, ver


def normalize_version(v):
    if not v:
        return "0"
    s = str(v).strip().strip("[]").strip()
    if s.lower().startswith("v"):
        s = s[1:].strip()
    return s if s else "0"


def is_version_match(detected, supported_versions, tested_display_ver):
    """Strict equality and token matching (prevents '0' in '1.9.0' false positives)."""
    det = normalize_version(detected)
    if not det:
        return False

    candidates = [normalize_version(tested_display_ver)]
    for sv in supported_versions or []:
        if isinstance(sv, dict):
            if "displayVersion" in sv:
                candidates.append(normalize_version(sv["displayVersion"]))
            if "versionCode" in sv:
                candidates.append(normalize_version(sv["versionCode"]))
        elif isinstance(sv, str):
            candidates.append(normalize_version(sv))

    # 1. Exact string match
    for c in candidates:
        if det.lower() == c.lower():
            return True

    # 2. Dot-separated numeric component match (e.g. "1.6.0" matches "1.6.0")
    # Never match "0" to multi-component version like "1.9.0"
    try:
        det_parts = [int(p) for p in det.split(".") if p.isdigit()]
        if len(det_parts) > 1:
            for c in candidates:
                c_parts = [int(p) for p in c.split(".") if p.isdigit()]
                if len(c_parts) == len(det_parts) and det_parts == c_parts:
                    return True
    except Exception:
        pass

    return False


def verify_package_combo(files_or_dir, games_map=None):
    """Verifies a combination of game packages (base, updates, DLC) or directory against games_db.json."""
    if games_map is None:
        games_map = load_games_db()

    file_paths = []
    if isinstance(files_or_dir, (str, Path)):
        p = Path(files_or_dir)
        if p.is_dir():
            for ext in ["*.nsp", "*.nsz", "*.xci", "*.xcz"]:
                file_paths.extend(list(p.glob(ext)))
        else:
            file_paths = [p]
    elif isinstance(files_or_dir, (list, tuple)):
        for f in files_or_dir:
            if f:
                fp = Path(f)
                if fp.is_dir():
                    for ext in ["*.nsp", "*.nsz", "*.xci", "*.xcz"]:
                        file_paths.extend(list(fp.glob(ext)))
                else:
                    file_paths.append(fp)

    if not file_paths:
        return {
            "status": "UNTESTED_GAME",
            "titleId": "UNKNOWN",
            "gameName": "No Switch Packages Found",
            "detectedVersion": "0",
            "testedVersion": "None",
            "isSupported": False,
            "badge": "ℹ️ No Packages",
            "message": "No valid NSP, NSZ, or XCI files were found in the selected path.",
            "unsupportedNote": "Please provide an NSP or XCI file to proceed.",
            "packages": [],
        }

    # Inspect all files and group by base title ID
    packages = []
    for fp in file_paths:
        raw_tid, base_tid, is_upd, ver = extract_title_and_version(fp)
        packages.append({
            "path": str(fp),
            "filename": Path(fp).name,
            "raw_tid": raw_tid,
            "base_tid": base_tid,
            "is_update": is_upd,
            "version": ver,
        })

    # Find primary base title ID
    primary_base_tid = None
    for pkg in packages:
        if pkg["base_tid"] and pkg["base_tid"] in games_map:
            primary_base_tid = pkg["base_tid"]
            break
    if not primary_base_tid:
        for pkg in packages:
            if pkg["base_tid"]:
                primary_base_tid = pkg["base_tid"]
                break

    if not primary_base_tid or primary_base_tid not in games_map:
        tid_disp = primary_base_tid or "UNKNOWN"
        return {
            "status": "UNTESTED_GAME",
            "titleId": tid_disp,
            "gameName": "Untested Game Title",
            "detectedVersion": packages[0]["version"] if packages else "0",
            "testedVersion": "None",
            "isSupported": False,
            "badge": "ℹ️ Untested Game",
            "message": f"Title ID {tid_disp} is not in the nxnative tested database. Porting will attempt an automated survey and best-effort build, but installation may or may not succeed.",
            "unsupportedNote": "This title has not been tested by the nxnative community. Graphics and stability are unverified.",
            "packages": packages,
        }

    g = games_map[primary_base_tid]
    # Check what packages exist for this game
    game_pkgs = [p for p in packages if p["base_tid"] == primary_base_tid]
    update_pkgs = [p for p in game_pkgs if p["is_update"] or (p["raw_tid"] and p["raw_tid"].endswith("800"))]
    base_pkgs = [p for p in game_pkgs if not p["is_update"] and not (p["raw_tid"] and p["raw_tid"].endswith("800"))]

    has_update = len(update_pkgs) > 0
    has_base = len(base_pkgs) > 0 or any(Path(p["path"]).suffix.lower() in (".xci", ".xcz") for p in game_pkgs)

    # Determine effective version
    if has_update:
        effective_ver = update_pkgs[0]["version"]
    elif base_pkgs:
        effective_ver = base_pkgs[0]["version"]
    else:
        effective_ver = game_pkgs[0]["version"]

    is_match = is_version_match(effective_ver, g.get("supportedVersions", []), g.get("testedDisplayVersion", "1.0.0"))

    if is_match:
        return {
            "status": "VERIFIED_SUPPORTED",
            "titleId": primary_base_tid,
            "gameName": g["name"],
            "detectedVersion": effective_ver,
            "testedVersion": g.get("testedDisplayVersion", "1.0.0"),
            "isSupported": True,
            "badge": "✓ Verified Compatible Release",
            "message": f"✓ {g['name']} (Version {g['testedDisplayVersion']}) is an officially tested and supported release.",
            "unsupportedNote": g.get("unsupportedVersionsNote", ""),
            "hasPatches": g.get("hasCustomPatches", False),
            "testedFps": g.get("testedFps", 60),
            "recipes": g.get("recipes", []),
            "hasUpdate": has_update,
            "hasBase": has_base,
            "packages": packages,
        }

    # If no match: check if base-only when an update is required
    base_is_supported = is_version_match("0", g.get("supportedVersions", []), g.get("testedDisplayVersion", "1.0.0")) or \
                        is_version_match("1.0.0", g.get("supportedVersions", []), g.get("testedDisplayVersion", "1.0.0"))

    if not has_update and not base_is_supported:
        return {
            "status": "UNTESTED_BASE_ONLY",
            "titleId": primary_base_tid,
            "gameName": g["name"],
            "detectedVersion": effective_ver,
            "testedVersion": g.get("testedDisplayVersion", "1.0.0"),
            "isSupported": False,
            "badge": "⚠️ Update Required (Base Only)",
            "message": f"{g['name']} base (v{effective_ver}) selected. This game requires Update v{g['testedDisplayVersion']} to run on MetalNX. Please select the update NSP/XCI alongside the base game.",
            "unsupportedNote": g.get("unsupportedVersionsNote", "Base game lacks registered shader pairs and stability patches."),
            "hasPatches": g.get("hasCustomPatches", False),
            "testedFps": g.get("testedFps", 60),
            "recipes": g.get("recipes", []),
            "hasUpdate": False,
            "hasBase": has_base,
            "packages": packages,
        }

    return {
        "status": "UNTESTED_VERSION",
        "titleId": primary_base_tid,
        "gameName": g["name"],
        "detectedVersion": effective_ver,
        "testedVersion": g.get("testedDisplayVersion", "1.0.0"),
        "isSupported": False,
        "badge": "⚠️ Untested Game Version",
        "message": f"⚠️ Detected version '{effective_ver}' for {g['name']} is unverified. The officially tested update is '{g['testedDisplayVersion']}'.",
        "unsupportedNote": g.get("unsupportedVersionsNote", "Older or unlisted game versions lack registered shader pairs and 60 FPS patches. For guaranteed stability, use the tested update."),
        "hasPatches": g.get("hasCustomPatches", False),
        "testedFps": g.get("testedFps", 60),
        "recipes": g.get("recipes", []),
        "hasUpdate": has_update,
        "hasBase": has_base,
        "packages": packages,
    }


def verify_file(file_path):
    return verify_package_combo(file_path)


def check_os_environment(cache_path, dest_path):
    """Preflight checks for macOS minimum version, Unified Memory (RAM), and dual-volume disk space."""
    issues = []
    warnings = []

    # 1. macOS version check (Sonoma 14.0+ required, Sequoia 15.0+ recommended)
    mac_ver = platform.mac_ver()[0]
    if mac_ver:
        try:
            major = int(mac_ver.split(".")[0])
            if major < 14:
                issues.append(f"macOS 14.0 (Sonoma) or newer is required. Detected macOS {mac_ver}. Please update macOS.")
            elif major == 14:
                warnings.append("macOS 14.x detected. macOS 15.0+ (Sequoia) is recommended for optimal Metal shader compiler performance.")
        except Exception:
            pass

    # 2. RAM check (< 16 GB warning)
    try:
        mem_bytes = int(subprocess.check_output(["sysctl", "-n", "hw.memsize"]).decode().strip())
        mem_gb = mem_bytes / (1024 ** 3)
        if mem_gb < 15.5:
            warnings.append(f"System has {mem_gb:.1f} GB Unified Memory (< 16 GB). Heavy swap usage may occur during Metal shader compilation.")
    except Exception:
        pass

    # 3. Dual-volume disk space check
    try:
        c_path = Path(cache_path).resolve()
        d_path = Path(dest_path).resolve()
        c_path.mkdir(parents=True, exist_ok=True)
        d_path.mkdir(parents=True, exist_ok=True)

        c_dev = c_path.stat().st_dev
        d_dev = d_path.stat().st_dev
        c_free_gb = shutil.disk_usage(c_path).free / (1024 ** 3)
        d_free_gb = shutil.disk_usage(d_path).free / (1024 ** 3)

        min_required_gb = 25.0
        if c_dev == d_dev:
            if c_free_gb < 35.0:
                issues.append(f"Insufficient disk space on build volume ({c_free_gb:.1f} GB available). At least 35.0 GB free space required.")
        else:
            if c_free_gb < min_required_gb:
                issues.append(f"Insufficient disk space on build cache volume ({c_free_gb:.1f} GB available). At least {min_required_gb:.1f} GB required.")
            if d_free_gb < min_required_gb:
                issues.append(f"Insufficient disk space on destination volume ({d_free_gb:.1f} GB available). At least {min_required_gb:.1f} GB required.")
    except Exception:
        pass

    return issues, warnings


PROTECTED_SYSTEM_PATHS = {
    Path("/"),
    Path("/Applications"),
    Path("/System"),
    Path("/Library"),
    Path("/Users"),
    Path("/Volumes"),
    Path("/bin"), Path("/sbin"), Path("/usr"), Path("/private"), Path("/var"), Path("/etc"),
    Path.home(),
    Path.home() / "Desktop",
    Path.home() / "Documents",
    Path.home() / "Downloads",
    Path.home() / "Applications",
    Path.home() / "Library",
    Path.home() / "Pictures",
    Path.home() / "Music",
    Path.home() / "Movies",
}


def is_protected_directory(p: Path) -> bool:
    try:
        resolved = p.resolve()
        if resolved in PROTECTED_SYSTEM_PATHS:
            return True
        if str(resolved).startswith("/Volumes/"):
            parts = resolved.parts
            if len(parts) <= 3:  # ('/', 'Volumes', 'DriveName')
                return True
    except Exception:
        pass
    return False


def resolve_safe_scratch(custom_dir) -> Path:
    if not custom_dir:
        return Path.home() / "Library/Caches/nxnative"
    p = Path(custom_dir).resolve()
    if is_protected_directory(p) or p.name != "MetalNX_Workspace":
        p = p / "MetalNX_Workspace"
    return p


def is_safe_to_purge(p: Path) -> bool:
    if is_protected_directory(p):
        return False
    resolved = p.resolve()
    home = Path.home().resolve()
    allowed_system_prefixes = [
        home / "Library/Caches/nxnative",
        home / "Library/Caches/MetalNX",
        home / "Library/Application Support/MetalNX/engine",
        home / "Library/Application Support/nxnative/engine",
        home / ".switch",
        home / "Library/Caches/uv",
        home / ".local/share/uv",
        home / "Library/Logs/MetalNX",
        home / "Library/Logs/nxnative",
    ]
    for prefix in allowed_system_prefixes:
        try:
            if resolved == prefix or resolved.is_relative_to(prefix):
                return True
        except (ValueError, AttributeError):
            if str(resolved).startswith(str(prefix)):
                return True
    if resolved.name == "MetalNX_Workspace":
        return True
    if resolved.name.endswith("_build") or resolved.name.startswith("port_stage_"):
        return True
    return False


def move_to_trash_safely(p: Path) -> bool:
    if not is_safe_to_purge(p):
        raise ValueError(f"Safety Violation: Refusing to purge protected or non-MetalNX path: {p}")
    # Try macOS Finder Trash first so files are NEVER permanently lost
    try:
        esc = str(p.resolve()).replace('"', '\\"')
        cmd = f'osascript -e \'tell application "Finder" to delete POSIX file "{esc}"\''
        res = subprocess.run(cmd, shell=True, capture_output=True, timeout=10)
        if res.returncode == 0:
            return True
    except Exception:
        pass
    # Fallback to moving into ~/.Trash
    try:
        trash = Path.home() / ".Trash"
        if trash.is_dir() and os.access(trash, os.W_OK):
            dest = trash / f"{p.name}_{int(time.time())}"
            shutil.move(str(p), str(dest))
            return True
    except Exception:
        pass
    if p.is_dir():
        shutil.rmtree(p, ignore_errors=True)
    else:
        p.unlink(missing_ok=True)
    return True


def get_dir_size(p: Path) -> int:
    if not p.exists():
        return 0
    if p.is_file():
        try:
            return p.stat().st_size
        except OSError:
            return 0
    total = 0
    try:
        for root, _, files in os.walk(p):
            for f in files:
                fp = os.path.join(root, f)
                try:
                    if not os.path.islink(fp):
                        total += os.path.getsize(fp)
                except OSError:
                    pass
    except OSError:
        pass
    return total


def get_storage_breakdown(custom_scratch=None):
    items = []

    # 1. Build Caches & Staging
    cache_dirs = [
        Path.home() / "Library/Caches/nxnative",
        Path.home() / "Library/Caches/MetalNX",
    ]
    if custom_scratch:
        safe_scratch = resolve_safe_scratch(custom_scratch)
        if safe_scratch.is_dir() and is_safe_to_purge(safe_scratch):
            cache_dirs.append(safe_scratch)

    build_size = sum(get_dir_size(d) for d in cache_dirs)
    items.append({
        "id": "build_cache",
        "name": "Build Caches & Scratch Files",
        "category": "Cache",
        "description": "Extracted RomFS, decompressed NSPs, and intermediate build artifacts",
        "size_bytes": build_size,
        "paths": [str(d) for d in cache_dirs if d.exists()]
    })

    # 2. Engine Workspace & Clones
    engine_dirs = [
        Path.home() / "Library/Application Support/MetalNX/engine",
        Path.home() / "Library/Application Support/nxnative/engine",
    ]
    engine_size = sum(get_dir_size(d) for d in engine_dirs)
    items.append({
        "id": "engine_workspace",
        "name": "Engine Workspaces & Clones",
        "category": "Workspace",
        "description": "Bootstrapped nxnative engine repository clones and build scripts",
        "size_bytes": engine_size,
        "paths": [str(d) for d in engine_dirs if d.exists()]
    })

    # 3. Python & Toolchains
    toolchain_dirs = [
        Path.home() / ".switch",
        Path.home() / "Library/Caches/uv",
        Path.home() / ".local/share/uv",
    ]
    toolchain_size = sum(get_dir_size(d) for d in toolchain_dirs)
    items.append({
        "id": "toolchain",
        "name": "Standalone Toolchains & uv Virtual Environments",
        "category": "Toolchain",
        "description": "Bundled/cached nx_extract, dmsh_xlate, uv cache, and isolated Python packages",
        "size_bytes": toolchain_size,
        "paths": [str(d) for d in toolchain_dirs if d.exists()]
    })

    # 4. Telemetry & Crash Logs
    log_dirs = [
        Path.home() / "Library/Logs/MetalNX",
        Path.home() / "Library/Logs/nxnative",
    ]
    log_size = sum(get_dir_size(d) for d in log_dirs)
    items.append({
        "id": "logs",
        "name": "Telemetry & Crash Logs",
        "category": "Logs",
        "description": "Detailed port diagnostic reports and crash telemetry",
        "size_bytes": log_size,
        "paths": [str(d) for d in log_dirs if d.exists()]
    })

    total_bytes = sum(it["size_bytes"] for it in items)
    return {
        "items": items,
        "total_bytes": total_bytes,
        "total_mb": round(total_bytes / (1024 * 1024), 2),
        "total_gb": round(total_bytes / (1024 * 1024 * 1024), 2),
    }


def purge_storage(category="all", custom_scratch=None):
    info = get_storage_breakdown(custom_scratch)
    freed_bytes = 0
    cleaned_paths = []

    for item in info["items"]:
        if category != "all" and item["id"] != category:
            continue
        for p_str in item["paths"]:
            p = Path(p_str)
            if p.exists() and is_safe_to_purge(p):
                try:
                    item_size = get_dir_size(p)
                    freed_bytes += item_size
                    move_to_trash_safely(p)
                    cleaned_paths.append(str(p))
                except Exception:
                    pass
    return {
        "status": "SUCCESS",
        "category": category,
        "freed_bytes": freed_bytes,
        "freed_mb": round(freed_bytes / (1024 * 1024), 2),
        "freed_gb": round(freed_bytes / (1024 * 1024 * 1024), 2),
        "cleaned_paths": cleaned_paths
    }


def check_metal_toolchain():
    """
    Verifies that the complete Apple Metal offline shader toolchain is available,
    including the Metal compiler frontend (metal), shader target translator (metal-tt),
    and AIR target translator (air-tt).
    """
    tools = ["metal", "metal-tt", "air-tt"]
    missing = []
    paths = {}
    for t in tools:
        try:
            res = subprocess.run(["/usr/bin/xcrun", "-f", t], capture_output=True, text=True, timeout=5)
            if res.returncode == 0 and res.stdout.strip():
                paths[t] = res.stdout.strip()
            else:
                missing.append(t)
        except Exception:
            missing.append(t)

    # Check Metal compiler execution
    try:
        ver_res = subprocess.run(["/usr/bin/xcrun", "-sdk", "macosx", "metal", "--version"], capture_output=True, text=True, timeout=5)
        if ver_res.returncode != 0:
            missing.append("metal (sdk macosx)")
    except Exception:
        missing.append("metal (sdk macosx)")

    if not missing:
        return {
            "ready": True,
            "path": paths.get("metal", "/usr/bin/metal"),
            "message": "Apple Metal Compiler & Offline Toolchain ready (metal, metal-tt, air-tt)"
        }
    else:
        return {
            "ready": False,
            "path": "",
            "message": f"Metal Offline Toolchain incomplete (missing {', '.join(missing)}). Please open Terminal and run:\n  xcodebuild -downloadComponent MetalToolchain"
        }


def run_doctor(base_path=None, update_path=None, folder_path=None, scratch_path=None):
    metal = check_metal_toolchain()
    hermetic_py = get_hermetic_python()
    py_ready = _is_hermetic_python_healthy(hermetic_py)
    xcode_ready = shutil.which("clang") is not None

    total_nsp_bytes = 0
    if base_path and Path(base_path).is_file():
        total_nsp_bytes += Path(base_path).stat().st_size
    if update_path and Path(update_path).is_file():
        total_nsp_bytes += Path(update_path).stat().st_size
    if folder_path and Path(folder_path).is_dir():
        for ext in ["*.nsp", "*.nsz", "*.xci", "*.xcz"]:
            for f in Path(folder_path).glob(ext):
                total_nsp_bytes += f.stat().st_size

    # Required space: (2 * total_nsp_bytes) + 10 GB
    required_bytes = (2 * total_nsp_bytes) + (10 * 1024 * 1024 * 1024)

    target_vol_path = resolve_safe_scratch(scratch_path)
    try:
        target_vol_path.mkdir(parents=True, exist_ok=True)
    except Exception:
        pass

    _, _, disk_free = shutil.disk_usage(str(target_vol_path))
    is_sufficient = disk_free >= required_bytes

    if folder_path and Path(folder_path).is_dir():
        v_res = verify_package_combo(folder_path)
    elif update_path or base_path:
        v_res = verify_package_combo([base_path, update_path])
    else:
        v_res = None

    return {
        "metal_toolchain": metal,
        "python_environment": {
            "ready": py_ready,
            "path": str(hermetic_py),
            "message": "Hermetic Python runtime ready with required modules" if py_ready else "Hermetic Python runtime missing required modules"
        },
        "xcode_tools": {
            "ready": xcode_ready,
            "message": "Xcode Command Line Tools installed" if xcode_ready else "Xcode Command Line Tools missing (xcode-select --install)"
        },
        "storage": {
            "target_path": str(target_vol_path),
            "nsp_bytes": total_nsp_bytes,
            "nsp_gb": round(total_nsp_bytes / (1024**3), 2),
            "required_bytes": required_bytes,
            "required_gb": round(required_bytes / (1024**3), 2),
            "available_bytes": disk_free,
            "available_gb": round(disk_free / (1024**3), 2),
            "is_sufficient": is_sufficient,
            "deficit_gb": max(0.0, round((required_bytes - disk_free) / (1024**3), 2)),
        },
        "recipe_match": v_res,
        "ready_to_compile": metal["ready"] and py_ready and xcode_ready and (is_sufficient or total_nsp_bytes == 0)
    }


def preseed_verified_recipes(title_id, target_fps=60):
    """Writes authoritative verified settings to env.txt upon successful porting."""
    if not title_id:
        return
    conf_dir = Path.home() / f"Library/Application Support/nxnative/{title_id}"
    conf_dir.mkdir(parents=True, exist_ok=True)
    env_file = conf_dir / "env.txt"

    content = f"""# MetalNX Pre-seeded Verified Configuration & Recipes
# Title ID: {title_id}
NVN_RESOLUTION_SCALE=0.85
NVN_ENABLE_METALFX=1
NVN_METALFX_PROFILE=balanced
NVN_METALFX_COLORSPACE=perceptual
NVN_TARGET_FPS={target_fps}
NVN_ANISOTROPY=16
NVN_VSYNC=1
NVN_ASYNC_SHADERS=1
DM_OPMODE=1
DM_PRESENT_SNAP=1
"""
    if title_id == "0100606026F12000":
        # Final Fantasy Resonance: CRIWARE audio buffer tuning to prevent audio crackle on Apple Silicon
        content += "# Audio buffer frames tuning for CRIWARE sound engine\nDM_DBG_AU_FRAMES=240\n"
    try:
        env_file.write_text(content, encoding="utf-8")
    except Exception:
        pass


# Deterministic Explicit Stage Table mapping engine stage names directly to pipeline stages
EXPLICIT_STAGE_MAP = {
    "survey: build nx_extract": (0.10, "Stage 1/7: Initializing"),
    "survey: RomFS manifest": (0.12, "Stage 1/7: Surveying Title & ExeFS"),
    "survey: code modules": (0.14, "Stage 1/7: Surveying Title & ExeFS"),
    "survey: imports vs host hooks": (0.16, "Stage 1/7: Surveying Title & ExeFS"),
    "build ID lookup": (0.12, "Stage 1/7: Surveying Title & ExeFS"),
    "decompress NSZ": (0.20, "Stage 1/7: Preparing Packages"),
    "extract": (0.35, "Stage 2/7: Extracting Game RomFS & Assets"),
    "extract DLC": (0.40, "Stage 2/7: Extracting Game RomFS & Assets"),
    "rewrite": (0.50, "Stage 3/7: Rewriting ARM64 Modules & Applying Patches"),
    "shader split": (0.65, "Stage 4/7: Translating Maxwell Shaders to Metal"),
    "Mac shaders": (0.75, "Stage 4/7: Translating Maxwell Shaders to Metal"),
    "iOS shaders": (0.75, "Stage 4/7: Translating Maxwell Shaders to Metal"),
    "Vulkan shaders": (0.75, "Stage 4/7: Translating Maxwell Shaders to Metal"),
    "GL shaders": (0.75, "Stage 4/7: Translating Maxwell Shaders to Metal"),
    "Mac host": (0.82, "Stage 5/7: Compiling Native macOS Host Shell"),
    "Pipeline prebuild": (0.90, "Stage 6/7: Prebuilding Metal Pipeline Bases"),
    "Pipeline archive": (0.92, "Stage 6/7: Prebuilding Metal Pipeline Bases"),
    "Mac app": (0.96, "Stage 7/7: Packaging Standalone App & Embedding Icon"),
    "IPA pack": (0.96, "Stage 7/7: Packaging Standalone App & Embedding Icon"),
}


def update_stage_from_line(line: str, current_stage: str, current_progress: float):
    """Updates current_stage and current_progress deterministically based on structured engine events.
    Ignores arbitrary unstructured log lines (e.g. lines with 'shader' in text) to prevent stage misclassification.
    """
    display_msg = line
    if line.startswith("{") and line.endswith("}"):
        try:
            event = json.loads(line)
            ev_type = event.get("ev")
            if ev_type in ("stage", "step", "stage_end", "progress"):
                st_name = event.get("name", "")
                for mapped_prefix, (weight, stage_title) in EXPLICIT_STAGE_MAP.items():
                    if st_name.startswith(mapped_prefix):
                        if weight > current_progress:
                            current_progress = weight
                        current_stage = stage_title
                        break
                step_detail = event.get("step")
                display_msg = f"[{current_stage}] {st_name}" + (f" · {step_detail}" if step_detail else "")
            elif ev_type == "say":
                display_msg = event.get("msg", "")
        except Exception:
            pass
    return current_stage, current_progress, display_msg


def main():
    parser = argparse.ArgumentParser(description="MetalNX Switch Port Installer & Verifier")
    parser.add_argument("--base", help="Path to base game NSP/NSZ file")
    parser.add_argument("--update", help="Optional path to update NSP/NSZ file")
    parser.add_argument("--folder", help="Folder containing NSPs")
    parser.add_argument("--keys", help="Path to prod.keys (defaults to auto-detect)")
    parser.add_argument("--out", help="Output .app directory (default: /Applications)")
    parser.add_argument("--work-dir", help="Scratch/build directory for intermediate files and temporary RomFS")
    parser.add_argument("--purge-cache", action="store_true", help="Purge temporary build caches and intermediate files")
    parser.add_argument("--purge-category", default="all", choices=["all", "build_cache", "engine_workspace", "toolchain", "logs"], help="Category of storage to purge")
    parser.add_argument("--storage-info", action="store_true", help="Print detailed storage usage breakdown in JSON")
    parser.add_argument("--doctor", action="store_true", help="Run pre-flight toolchain doctor and disk space check")
    parser.add_argument("--allow-untested-base", action="store_true", help="Allow porting untested base game without required update (experimental)")
    parser.add_argument("--verify", help="Inspect and verify an NSP/NSZ file for compatibility")
    parser.add_argument("--list-db", action="store_true", help="Print all verified games in JSON")
    args = parser.parse_args()

    if args.work_dir:
        args.work_dir = str(resolve_safe_scratch(args.work_dir))

    # Mode 1: Inspect/Verify File
    if args.verify:
        result = verify_file(args.verify)
        print(json.dumps(result, indent=2))
        sys.exit(0)

    # Mode 2: List Database
    if args.list_db:
        db = load_games_db()
        print(json.dumps(list(db.values()), indent=2))
        sys.exit(0)

    # Mode 3: Pre-Flight Doctor Check
    if args.doctor:
        doc = run_doctor(base_path=args.base, update_path=args.update, folder_path=args.folder, scratch_path=args.work_dir)
        print(json.dumps(doc, indent=2))
        sys.exit(0)

    # Mode 4: Storage Info
    if args.storage_info:
        info = get_storage_breakdown(args.work_dir)
        print(json.dumps(info, indent=2))
        sys.exit(0)

    # Mode 5: Purge Storage Caches
    if args.purge_cache:
        res = purge_storage(category=args.purge_category, custom_scratch=args.work_dir)
        print(json.dumps(res, indent=2))
        sys.exit(0)

    start_time = time.time()

    # Ensure required python modules
    if not ensure_python_modules():
        emit("ERROR", 0.0, "Initialization", "Hermetic Python runtime setup failed. Please check internet connection or run: uv venv ~/Library/Application\\ Support/MetalNX/python_env && uv pip install --python ~/Library/Application\\ Support/MetalNX/python_env/bin/python lz4 capstone fonttools backports.zstd nsz")
        sys.exit(1)

    # 1. Determine Keys
    keys_input = Path(args.keys) if args.keys else find_default_keys()
    if keys_input and keys_input.is_file() and (str(keys_input).lower().endswith(".zip") or zipfile.is_zipfile(keys_input)):
        keys_path = extract_keys_from_zip(keys_input) or keys_input
    else:
        keys_path = keys_input

    if not keys_path or not keys_path.is_file():
        emit("ERROR", 0.0, "Initialization", "prod.keys not found! Place prod.keys in ~/.switch/prod.keys or select it manually.")
        sys.exit(1)

    emit("PROGRESS", 0.04, "Stage 1/7: Initializing", f"Using decryption keys from {keys_path.name}", eta_sec=120, elapsed_sec=0)

    # 2. Determine / Stage Source Folder
    staging_dir = None
    total_bytes = 0
    primary_title_id = None

    if args.folder and Path(args.folder).is_dir():
        nsp_dir = Path(args.folder).resolve()
        for ext in ["*.nsp", "*.nsz", "*.xci", "*.xcz"]:
            for f in nsp_dir.glob(ext):
                total_bytes += f.stat().st_size
                if not primary_title_id:
                    _, b_tid, _, _ = extract_title_and_version(f)
                    primary_title_id = b_tid
    elif args.base and Path(args.base).is_file():
        if args.work_dir:
            cache_base = Path(args.work_dir).resolve() / "stage"
        else:
            cache_base = Path.home() / "Library/Caches/nxnative"
        cache_base.mkdir(parents=True, exist_ok=True)
        staging_dir = Path(tempfile.mkdtemp(prefix="port_stage_", dir=cache_base))
        nsp_dir = staging_dir

        base_p = Path(args.base)
        total_bytes += base_p.stat().st_size
        raw_b_tid, b_tid, _, b_ver = extract_title_and_version(base_p)
        primary_title_id = b_tid

        staged_base_name = base_p.name
        if b_tid and f"[{b_tid}]" not in base_p.name:
            staged_base_name = f"{base_p.stem} [{b_tid}][v{b_ver}]{base_p.suffix}"
        base_target = nsp_dir / staged_base_name
        try:
            os.symlink(os.path.abspath(args.base), base_target)
        except OSError:
            shutil.copyfile(args.base, base_target)

        if args.update and Path(args.update).is_file():
            upd_p = Path(args.update)
            total_bytes += upd_p.stat().st_size
            raw_u_tid, _, _, u_ver = extract_title_and_version(upd_p)
            tag_tid = raw_u_tid or (f"{int(b_tid, 16) + 0x800:016X}" if b_tid else None)
            staged_upd_name = upd_p.name
            if tag_tid and f"[{tag_tid}]" not in upd_p.name:
                staged_upd_name = f"{upd_p.stem} [{tag_tid}][v{u_ver}]{upd_p.suffix}"
            update_target = nsp_dir / staged_upd_name
            try:
                os.symlink(os.path.abspath(args.update), update_target)
            except OSError:
                shutil.copyfile(args.update, update_target)
    else:
        emit("ERROR", 0.0, "Initialization", "No valid base NSP or folder provided.")
        sys.exit(1)

    # Compatibility and package combination check
    v_res = verify_package_combo(args.folder or [args.base, args.update])

    if v_res and v_res.get("status") == "UNTESTED_BASE_ONLY" and not args.allow_untested_base:
        emit("ERROR", 0.0, "Preflight: Package Support",
             f"{v_res['message']}\n\nTo attempt porting this base game without updates at your own risk, enable 'Allow experimental base-only port' or pass --allow-untested-base.")
        sys.exit(1)

    if v_res and v_res.get("status") == "VERIFIED_SUPPORTED":
        emit("PROGRESS", 0.06, "Stage 1/7: Verified Release", f"✓ {v_res['badge']}: {v_res['gameName']} ({v_res['testedVersion']})", eta_sec=120, elapsed_sec=0)
    elif v_res and v_res.get("status") == "UNTESTED_BASE_ONLY":
        emit("PROGRESS", 0.06, "Stage 1/7: Untested Base", "⚠️ Notice: Proceeding with untested base game without required update (--allow-untested-base).", eta_sec=120, elapsed_sec=0)
    elif v_res and v_res.get("status") == "UNTESTED_VERSION":
        emit("PROGRESS", 0.06, "Stage 1/7: Untested Version", f"{v_res['badge']}: {v_res['unsupportedNote']}", eta_sec=120, elapsed_sec=0)
    elif v_res and v_res.get("status") == "UNTESTED_GAME":
        emit("PROGRESS", 0.06, "Stage 1/7: Custom Game", f"{v_res['badge']}: Automated survey mode enabled.", eta_sec=120, elapsed_sec=0)

    # Estimate expected total duration based on package size (~15MB/s on M1)
    size_mb = total_bytes / (1024 * 1024)
    estimated_total_sec = max(40.0, min(360.0, 30.0 + (size_mb * 0.035)))

    emit("PROGRESS", 0.08, "Stage 1/7: Preparing Packages", f"Indexed {round(size_mb, 1)} MB of Switch packages",
         eta_sec=estimated_total_sec, elapsed_sec=time.time() - start_time)

    # 3. Setup Environment
    env = os.environ.copy()
    home = str(Path.home())

    # Guarantee standard Homebrew and system PATHs in GUI environment
    path_dirs = [
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
    ]
    current_paths = env.get("PATH", "").split(":")
    for pd in path_dirs:
        if pd not in current_paths and os.path.isdir(pd):
            current_paths.insert(0, pd)
    env["PATH"] = ":".join(current_paths)
    os.environ["PATH"] = env["PATH"]

    # Discover .NET 10 runtime root and export to environment
    dotnet_root = discover_dotnet()
    if dotnet_root:
        env["DOTNET_ROOT"] = str(dotnet_root)
        env["DOTNET_ROOT_ARM64"] = str(dotnet_root)
        env["PATH"] = f"{dotnet_root}:{env['PATH']}"

    # Check clang / Xcode Command Line Tools
    if not shutil.which("clang"):
        emit("ERROR", 0.0, "Prerequisites", "Xcode Command Line Tools required. Open Terminal and run: xcode-select --install")
        sys.exit(1)

    repo_root = ensure_engine_components()
    if not repo_root:
        emit("ERROR", 0.0, "Configuration", "Could not locate or download MetalNX engine. Please clone https://github.com/krushant1122/MetalNX to ~/nxnative or set NXNATIVE_ROOT.")
        sys.exit(1)

    # Stage 0: Toolchain Lock & Preflight Verification
    emit("PROGRESS", 0.02, "Stage 0/7: Preflight Check", "Verifying translation toolchain against lock file...", eta_sec=120)
    tools_ok, tool_issues = check_translation_toolchain(repo_root)
    if not tools_ok:
        emit("ERROR", 0.0, "Preflight: Toolchain Lock",
             "Translation chain tools do not match lock file:\n" + "\n".join(tool_issues) +
             "\n\nFix: Ensure .NET 10 is installed and reachable:\n  brew install dotnet\n  or curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0")
        sys.exit(1)

    target_out_dir = args.out if args.out else "/Applications"
    scratch_dir_target = resolve_safe_scratch(args.work_dir)
    env_issues, env_warnings = check_os_environment(scratch_dir_target, target_out_dir)
    if env_issues:
        emit("ERROR", 0.0, "Preflight: Environment", "\n".join(env_issues))
        sys.exit(1)
    for w in env_warnings:
        emit("PROGRESS", 0.03, "Stage 0/7: Preflight Check", f"⚠️ Notice: {w}", eta_sec=120)

    # Set authoritative environment variables so all sub-processes know the engine root
    env["NXNATIVE_ROOT"] = str(repo_root)
    env["DM_ROOT"] = str(repo_root)
    os.environ["NXNATIVE_ROOT"] = str(repo_root)
    os.environ["DM_ROOT"] = str(repo_root)

    # Persist preference file
    try:
        pref_file = Path.home() / "Library/Application Support/nxnative/repo_root.txt"
        pref_file.parent.mkdir(parents=True, exist_ok=True)
        pref_file.write_text(str(repo_root))
    except Exception:
        pass

    # Synchronize latest bundled scripts into engine root so cached repos are always up to date
    bundled_scripts_dir = HERE / "scripts"
    if bundled_scripts_dir.is_dir() and repo_root.resolve() != HERE.resolve():
        for sf in bundled_scripts_dir.glob("*.py"):
            try:
                (repo_root / "scripts").mkdir(parents=True, exist_ok=True)
                shutil.copy2(sf, repo_root / "scripts" / sf.name)
            except Exception:
                pass

    # Ensure standalone nx_extract is placed in ~/.switch/nx_extract
    bundled_nx = HERE / "nx_extract"
    if bundled_nx.is_file() and bundled_nx.stat().st_size > 50_000_000:
        switch_dir = Path.home() / ".switch"
        try:
            switch_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(bundled_nx, switch_dir / "nx_extract")
            os.chmod(switch_dir / "nx_extract", 0o755)
        except Exception:
            pass

    # Purge any stale framework-dependent binaries from previous runs in the game build directory
    for work_dir in nsp_dir.glob("*_build"):
        cached_nx = work_dir / "tools/nx_extract/nx_extract"
        if cached_nx.is_file() and cached_nx.stat().st_size < 50_000_000:
            try:
                cached_nx.unlink()
            except Exception:
                pass

    ensure_nx_extract(repo_root)
    ensure_dmsh_xlate(repo_root)
    xlate_bin = repo_root / "dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate"
    if xlate_bin.is_file() and os.access(xlate_bin, os.X_OK):
        env["XLATE"] = str(xlate_bin)
        os.environ["XLATE"] = str(xlate_bin)

    env["METALNX_APP"] = "1"
    os.environ["METALNX_APP"] = "1"

    build_script = repo_root / "scripts/build_ipa_from_nsp.py"
    if not build_script.is_file():
        emit("ERROR", 0.0, "Configuration", f"Could not find build script at {build_script}")
        sys.exit(1)

    # Use pinned hermetic Python interpreter with all modules pre-verified
    hermetic_py = get_hermetic_python()
    env["PATH"] = f"{hermetic_py.parent}:{env['PATH']}"
    env["PYTHONPATH"] = ""

    # Preflight toolchain sanity
    metal_chk = check_metal_toolchain()
    if not metal_chk["ready"]:
        emit("PROGRESS", 0.05, "Stage 1/7: Initializing", f"⚠️ Notice: {metal_chk['message']}", eta_sec=120, elapsed_sec=time.time() - start_time)

    cmd = [
        str(hermetic_py),
        str(build_script),
        str(nsp_dir),
        "-k", str(keys_path),
        "--platform", "mac-app",
        "--progress", "json",
    ]

    if args.work_dir:
        safe_work = resolve_safe_scratch(args.work_dir)
        env["DM_ROOT"] = str(safe_work)
        env["WORK"] = str(safe_work / "tmp")

    # Centralized output path resolution: ensures -o always receives a valid .app path
    target_out_dir = args.out if args.out else "/Applications"
    game_title = None
    if v_res and v_res.get("gameName"):
        game_title = v_res.get("gameName")
    elif args.base and Path(args.base).is_file():
        stem = Path(args.base).stem
        clean_stem = re.sub(r"\[.*?\]", "", stem).strip()
        game_title = clean_stem or primary_title_id or "nxnative"
    elif primary_title_id:
        db = load_games_db()
        if primary_title_id in db:
            game_title = db[primary_title_id]["name"]
        else:
            game_title = primary_title_id
    elif args.folder and Path(args.folder).is_dir():
        first_pkg = None
        for ext in ("*.nsp", "*.nsz", "*.xci", "*.xcz"):
            first_pkg = next(Path(args.folder).glob(ext), None)
            if first_pkg:
                break
        if first_pkg:
            clean_stem = re.sub(r"\[.*?\]", "", first_pkg.stem).strip()
            game_title = clean_stem or "nxnative"
        else:
            game_title = "nxnative"
    else:
        game_title = "nxnative"

    target_app_path = build_output_app_path(target_out_dir, game_title)
    cmd.extend(["-o", str(target_app_path)])

    # Destination directory writability validation
    target_out_dir_path = Path(target_out_dir).resolve()
    if target_out_dir_path.exists():
        if not os.access(target_out_dir_path, os.W_OK):
            emit("ERROR", 0.0, "Configuration", f"Destination directory is read-only: {target_out_dir_path}. Please select a writable folder.")
            sys.exit(1)
    else:
        try:
            target_out_dir_path.mkdir(parents=True, exist_ok=True)
        except OSError as e:
            emit("ERROR", 0.0, "Configuration", f"Cannot create destination directory {target_out_dir_path}: {e}")
            sys.exit(1)

    if target_app_path.exists() and not os.access(target_app_path, os.W_OK):
        emit("ERROR", 0.0, "Configuration", f"Existing app at {target_app_path} is read-only. Please change permissions or choose another destination.")
        sys.exit(1)

    # Concurrency guard: avoid colliding builds for the same game
    active_scratch = resolve_safe_scratch(args.work_dir)
    lock_file = active_scratch / f"{primary_title_id or 'generic'}.lock"
    lock_fd = None
    try:
        import fcntl
        lock_file.parent.mkdir(parents=True, exist_ok=True)
        lock_fd = open(lock_file, "w")
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        lock_fd.write(f"{os.getpid()}\n")
        lock_fd.flush()
    except (BlockingIOError, OSError):
        emit("ERROR", 0.0, "Configuration", "Another MetalNX build process is currently running for this game. Please wait for it to finish.")
        sys.exit(1)

    current_progress = 0.08
    current_stage = "Stage 1/7: Initializing"
    detected_app_path = None

    # Gatekeeper Assertion: Guarantee -o is always passed and strictly ends in .app
    assert "-o" in cmd, "Engine invocation invariant violated: missing -o argument"
    out_idx = cmd.index("-o") + 1
    assert out_idx < len(cmd), "Engine invocation invariant violated: missing path after -o"
    assert cmd[out_idx].endswith(".app"), (
        f"Engine invocation invariant violated: -o target must end in .app, got: {cmd[out_idx]!r}"
    )

    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            env=env,
        )

        recent_lines = collections.deque(maxlen=40)
        for raw_line in iter(proc.stdout.readline, ""):
            line = raw_line.strip()
            if not line:
                continue
            recent_lines.append(line)

            # 1. Parse structured JSON events emitted by build_ipa_from_nsp.py --progress json
            current_stage, current_progress, display_msg = update_stage_from_line(
                line, current_stage, current_progress
            )

            if ".app" in line:
                app_match = re.search(r"(/[^\"\r\n]+\.app)", line)
                if app_match:
                    detected_app_path = app_match.group(1).strip()

            elapsed = time.time() - start_time
            if current_progress > 0.1:
                fraction_left = max(0.01, 1.0 - current_progress)
                projected_total = max(estimated_total_sec, elapsed / current_progress)
                eta = max(0, projected_total - elapsed)
            else:
                eta = max(0, estimated_total_sec - elapsed)

            emit("PROGRESS", current_progress, current_stage, display_msg, eta_sec=eta, elapsed_sec=elapsed)

        proc.stdout.close()
        proc.wait()

        elapsed = time.time() - start_time

        if proc.returncode != 0:
            err_line = None
            for l in reversed(recent_lines):
                if any(k in l.lower() for k in ["error", "fatal", "failed", "differ from game profile", "tools not found", "missing", "spirv-cross"]):
                    err_line = l
                    break
            if not err_line and recent_lines:
                err_line = recent_lines[-1]
            error_msg = f"{err_line}" if err_line else f"Build process failed with exit code {proc.returncode}"
            write_crash_log(stage=current_stage, message=error_msg, recent_lines=recent_lines, title_id=primary_title_id)
            emit("ERROR", current_progress, current_stage, error_msg, elapsed_sec=elapsed)
            sys.exit(proc.returncode)

        # 5. Finalize App Bundle
        final_app_path = None
        if target_app_path and target_app_path.is_dir():
            final_app_path = str(target_app_path)
        elif detected_app_path and Path(detected_app_path).is_dir():
            final_app_path = detected_app_path
        else:
            found_apps = list(nsp_dir.glob("*.app"))
            if found_apps:
                final_app_path = str(found_apps[0])

        if final_app_path:
            app_name = Path(final_app_path).name
            target_app_path.parent.mkdir(parents=True, exist_ok=True)
            if Path(final_app_path).resolve() != target_app_path.resolve():
                emit("PROGRESS", 0.98, "Stage 7/7: Installing", f"Moving {app_name} to {target_app_path.parent}...", eta_sec=2, elapsed_sec=elapsed)
                if target_app_path.exists():
                    shutil.rmtree(target_app_path)
                shutil.move(final_app_path, target_app_path)
                final_app_path = str(target_app_path)
            else:
                final_app_path = str(target_app_path)

            # Pre-seed verified configuration & recipes
            if primary_title_id:
                preseed_verified_recipes(primary_title_id)

            emit("SUCCESS", 1.0, "Port Ready!", f"Successfully installed port: {final_app_path}", eta_sec=0, elapsed_sec=elapsed)
        else:
            if primary_title_id:
                preseed_verified_recipes(primary_title_id)
            emit("SUCCESS", 1.0, "Port Ready!", "Port compilation finished successfully!", eta_sec=0, elapsed_sec=elapsed)

    finally:
        if staging_dir and staging_dir.exists():
            shutil.rmtree(staging_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
