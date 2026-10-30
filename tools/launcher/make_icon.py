#!/usr/bin/env python3
"""
Generates a minimal, high-resolution macOS AppIcon.icns for MetalNX
Aesthetic: macOS 27 Liquid Obsidian & Apple Pro Developer Utility.
"""

import os
import subprocess
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ICONSET = HERE / "AppIcon.iconset"
ICNS_OUT = HERE / "AppIcon.icns"

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    if ICNS_OUT.exists() and ICNS_OUT.stat().st_size > 0:
        print(f"-> Pillow not installed, but {ICNS_OUT.name} already exists. Reusing icon.")
        sys.exit(0)
    else:
        raise


def create_minimal_metalnx_icon():
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    margin = 80
    rect = [margin, margin, size - margin, size - margin]
    radius = 210

    # 1. Soft Ambient Drop Shadow behind squircle
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle([margin, margin + 28, size - margin, size - margin + 28], radius=radius, fill=(0, 0, 0, 180))
    shadow = shadow.filter(ImageFilter.GaussianBlur(38))
    img.paste(shadow, (0, 0), shadow)

    # 2. Base Squircle Substrate with Deep Liquid Obsidian Gradient
    substrate = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sub_draw = ImageDraw.Draw(substrate)

    for y in range(margin, size - margin):
        t = (y - margin) / (size - 2 * margin)
        # Deep Obsidian Charcoal to Dark Titanium Navy
        r = int(10 + t * 14)
        g = int(11 + t * 16)
        b = int(16 + t * 26)
        sub_draw.line([(margin, y), (size - margin, y)], fill=(r, g, b, 255))

    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(rect, radius=radius, fill=255)
    img.paste(substrate, (0, 0), mask)

    # 3. Specular Hairline Edges & Inner Glass Glow
    draw = ImageDraw.Draw(img)
    # 0.5pt subtle specular outline
    draw.rounded_rectangle(rect, radius=radius, outline=(255, 255, 255, 42), width=3)
    # Top arc specular highlight
    draw.arc(rect, start=180, end=0, fill=(255, 255, 255, 75), width=3)

    # 4. Subtle Ambient Backdrop Glow for the Glyph
    cx, cy = size // 2, size // 2
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([cx - 220, cy - 220, cx + 220, cy + 220], fill=(41, 151, 255, 45))
    glow = glow.filter(ImageFilter.GaussianBlur(80))
    img.paste(glow, (0, 0), glow)

    # 5. Minimalist MetalNX Monogram Glyph: Intersecting Chevrons / "M" & "NX"
    # Drawn with crisp vector geometric polygons
    glyph_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glyph_layer)

    # Geometric parameters
    # Left Pillar & Angled Blade (Apple Ice Blue: #2997FF)
    # A bold, sleek, angled chevron representing the "M" and left "N"
    p1 = [(280, 310), (355, 310), (355, 714), (280, 714)]
    # Diagonal crossbar of N / X (from top left to bottom center-right)
    p2 = [
        (355, 310),
        (435, 310),
        (665, 714),
        (585, 714)
    ]
    # Right Pillar (Apple Mint Green: #30D158)
    p3 = [(665, 310), (740, 310), (740, 714), (665, 714)]

    # Draw Left Wing (Ice Blue)
    g_draw.polygon(p1, fill=(41, 151, 255, 250))
    
    # Draw Right Wing (Mint Green)
    g_draw.polygon(p3, fill=(48, 209, 88, 250))

    # Draw Diagonal Beam (Gradient / Pure Crystalline White with Ice Blue rim)
    g_draw.polygon(p2, fill=(240, 246, 255, 255))

    # Counter-diagonal intersecting cut forming the "X" of "NX"
    # Crossing from top-right to bottom-left:
    p4 = [
        (665, 310),
        (585, 310),
        (355, 714),
        (435, 714)
    ]
    # Draw with subtle transparency so it intersects cleanly
    g_draw.polygon(p4, fill=(41, 151, 255, 200))

    # Center Specular Intersection Diamond
    core_w = 44
    diamond = [
        (cx, cy - core_w),
        (cx + core_w, cy),
        (cx, cy + core_w),
        (cx - core_w, cy)
    ]
    g_draw.polygon(diamond, fill=(255, 255, 255, 255))

    # Inner Core Dot (Titanium Obsidian)
    dot_r = 14
    g_draw.ellipse([cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r], fill=(12, 14, 20, 255))

    # Composite glyph onto base icon
    img.paste(glyph_layer, (0, 0), glyph_layer)

    return img


def main():
    print("-> Creating master 1024x1024 MetalNX minimal icon...")
    master = create_minimal_metalnx_icon()

    ICONSET.mkdir(exist_ok=True)

    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    print("-> Generating mipmap icons in iconset...")
    for sz, fname in sizes:
        resized = master.resize((sz, sz), Image.Resampling.LANCZOS)
        resized.save(ICONSET / fname)

    print("-> Compiling AppIcon.icns via iconutil...")
    if ICNS_OUT.exists():
        ICNS_OUT.unlink()
    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS_OUT)], check=True)

    shutil.rmtree(ICONSET)
    print(f"✓ Generated: {ICNS_OUT} ({ICNS_OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
