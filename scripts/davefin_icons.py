#!/usr/bin/env python3
"""Recolors Moonfin's app icons into Davefin's, so the two apps can be told
apart on a launcher, dock or taskbar when installed side by side.

The artwork stays Moonfin's; only its hue turns, from Moonfin's purple and
cyan to orange and magenta. Greys, black and white are left alone. The
Android TV banner also gets its wordmark redrawn.

Run once from the repository root on the upstream icons:

    python3 scripts/davefin_icons.py [--font /path/to/serif.ttf]

Needs Pillow. Running it twice turns the hue twice, so restore the upstream
icons first (git checkout upstream/main -- <paths>) before re-running.
"""

import argparse
import colorsys
import glob
import os

from PIL import Image, ImageDraw, ImageFont

HUE_SHIFT = 100 / 360

ICONS = [
    "assets/icons/app_icon.png",
    "assets/icons/moonfin.png",
    "android/app/src/main/res/mipmap-*/ic_launcher*.png",
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png",
    "macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png",
    "web/favicon.png",
    "web/icons/*.png",
    "windows/runner/resources/app_icon.ico",
]
TV_BANNER = "android/app/src/main/res/drawable-nodpi/moonfin_tv_banner.png"


def _shift_pixel(r, g, b):
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if s < 0.08:
        return r, g, b
    r, g, b = colorsys.hls_to_rgb((h + HUE_SHIFT) % 1.0, l, s)
    return round(r * 255), round(g * 255), round(b * 255)


def recolor(image):
    rgba = image.convert("RGBA")
    cache = {}
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            key = (r, g, b)
            if key not in cache:
                cache[key] = _shift_pixel(r, g, b)
            pixels[x, y] = (*cache[key], a)
    return rgba if image.mode == "RGBA" else rgba.convert(image.mode)


def recolor_file(path):
    image = Image.open(path)
    if path.endswith(".ico"):
        sizes = sorted(image.ico.sizes())
        largest = recolor(image.ico.getimage(sizes[-1]))
        largest.save(path, format="ICO", sizes=sizes)
    else:
        recolor(image).save(path)
    print("recolored", path)


def redraw_banner(path, font_path):
    banner = recolor(Image.open(path))
    width, height = banner.size
    background = banner.getpixel((2, 2))
    draw = ImageDraw.Draw(banner)
    # The wordmark sits right of the logo; paint it out and set the new name
    # at the same size and baseline.
    text_left = int(width * 0.27)
    draw.rectangle([text_left, 0, width, height], fill=background)
    font = ImageFont.truetype(font_path, int(height * 0.30))
    box = draw.textbbox((0, 0), "Davefin", font=font)
    text_height = box[3] - box[1]
    draw.text(
        (text_left, (height - text_height) / 2 - box[1]),
        "Davefin",
        font=font,
        fill=(255, 255, 255),
    )
    banner.save(path)
    print("redrew", path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--font",
        default="/app/node_modules/.pnpm/katex@0.16.47/node_modules/katex/"
        "dist/fonts/KaTeX_Main-Regular.ttf",
        help="a serif TrueType font for the TV banner wordmark",
    )
    args = parser.parse_args()
    for pattern in ICONS:
        for path in sorted(glob.glob(pattern)):
            recolor_file(path)
    if os.path.exists(TV_BANNER):
        redraw_banner(TV_BANNER, args.font)


if __name__ == "__main__":
    main()
