#!/usr/bin/env python3
"""Generate app icon for vox - a voice transcription app.

Creates a modern, minimal icon with a waveform design.
"""

import os
import subprocess
import tempfile
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Installing Pillow...")
    subprocess.run(["pip3", "install", "Pillow"], check=True)
    from PIL import Image, ImageDraw

import math


def create_icon(size: int) -> Image.Image:
    """Create a single icon at the specified size."""
    # Create image with transparency
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Calculate dimensions
    padding = size * 0.08
    circle_size = size - (padding * 2)

    # Colors - deep purple/blue gradient feel
    bg_color = (88, 86, 214)  # Purple-blue
    wave_color = (255, 255, 255)  # White

    # Draw circular background
    draw.ellipse(
        [padding, padding, padding + circle_size, padding + circle_size],
        fill=bg_color,
    )

    # Draw waveform bars in the center
    center_x = size / 2
    center_y = size / 2
    bar_width = size * 0.06
    bar_gap = size * 0.04
    num_bars = 5
    max_bar_height = size * 0.35
    min_bar_height = size * 0.12

    # Bar heights pattern (symmetric, taller in middle)
    heights = [0.4, 0.7, 1.0, 0.7, 0.4]

    total_width = (num_bars * bar_width) + ((num_bars - 1) * bar_gap)
    start_x = center_x - (total_width / 2)

    for i, height_factor in enumerate(heights):
        bar_height = min_bar_height + (max_bar_height - min_bar_height) * height_factor
        x = start_x + (i * (bar_width + bar_gap))
        y = center_y - (bar_height / 2)

        # Draw rounded rectangle for each bar
        radius = bar_width / 2
        draw.rounded_rectangle(
            [x, y, x + bar_width, y + bar_height],
            radius=radius,
            fill=wave_color,
        )

    return img


def main():
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent
    resources_dir = project_dir / "resources"
    iconset_dir = resources_dir / "AppIcon.iconset"

    # Create directories
    resources_dir.mkdir(exist_ok=True)
    iconset_dir.mkdir(exist_ok=True)

    # Icon sizes required for macOS
    sizes = [
        (16, "16x16"),
        (32, "16x16@2x"),
        (32, "32x32"),
        (64, "32x32@2x"),
        (128, "128x128"),
        (256, "128x128@2x"),
        (256, "256x256"),
        (512, "256x256@2x"),
        (512, "512x512"),
        (1024, "512x512@2x"),
    ]

    print("Generating icon images...")
    for size, name in sizes:
        img = create_icon(size)
        filepath = iconset_dir / f"icon_{name}.png"
        img.save(filepath, "PNG")
        print(f"  Created {name} ({size}x{size})")

    # Convert to .icns using iconutil
    icns_path = resources_dir / "AppIcon.icns"
    print(f"\nConverting to .icns...")

    result = subprocess.run(
        ["iconutil", "-c", "icns", str(iconset_dir), "-o", str(icns_path)],
        capture_output=True,
        text=True,
    )

    if result.returncode == 0:
        print(f"Created {icns_path}")
        # Clean up iconset directory
        import shutil
        shutil.rmtree(iconset_dir)
        print("\nIcon generation complete!")
    else:
        print(f"Error creating .icns: {result.stderr}")
        return 1

    return 0


if __name__ == "__main__":
    exit(main())
