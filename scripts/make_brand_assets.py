#!/usr/bin/env python3
"""Regenerates the logo imagesets, app icons and top shelf art from Resources/Brand/logo-source.png.

    python3 scripts/make_brand_assets.py        (needs Pillow)

The source logo is only 300x104, so everything built from it is upscaled and a little soft.
Drop a larger or vector logo in as logo-source.png and re-run for crisper icons.
"""
import json, os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "Resources")
SRC = Image.open(os.path.join(RES, "Brand", "logo-source.png")).convert("RGBA")

BG = (11, 11, 16)
RED = (208, 64, 64)
RED_DEEP = (140, 26, 34)


def sharpen(im):
    return im.filter(ImageFilter.UnsharpMask(radius=2, percent=120, threshold=2))


def scaled(im, height=None, width=None):
    if height:
        width = round(im.width * height / im.height)
    else:
        height = round(im.height * width / im.width)
    return sharpen(im.resize((width, height), Image.LANCZOS))


def trimmed(im):
    return im.crop(im.getbbox())


# The "30" emblem is the left part of the wordmark, before the gap that precedes "NAMA".
MARK = trimmed(SRC.crop((0, 0, 86, SRC.height)))
WORD = trimmed(SRC)


def save(im, *path):
    p = os.path.join(RES, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)


def background(w, h, glow=True):
    im = Image.new("RGB", (w, h), BG)
    if glow:
        g = Image.new("RGB", (w, h), BG)
        d = ImageDraw.Draw(g)
        r = int(max(w, h) * 0.75)
        for i in range(24, 0, -1):
            t = i / 24
            c = tuple(round(BG[k] + (RED_DEEP[k] - BG[k]) * (1 - t) ** 2 * 0.9) for k in range(3))
            rr = int(r * t)
            d.ellipse((int(w * 0.15) - rr, int(h * 0.05) - rr, int(w * 0.15) + rr, int(h * 0.05) + rr), fill=c)
        im = g.filter(ImageFilter.GaussianBlur(max(w, h) // 40))
    return im.convert("RGBA")


def centered(canvas, logo, frac_w=None, frac_h=None, dx=0, dy=0):
    if frac_w:
        logo = scaled(logo, width=round(canvas.width * frac_w))
    else:
        logo = scaled(logo, height=round(canvas.height * frac_h))
    out = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    out.alpha_composite(logo, ((canvas.width - logo.width) // 2 + dx, (canvas.height - logo.height) // 2 + dy))
    return out


# ---- shared logo imagesets -------------------------------------------------------------
def imageset(name, im, base_w):
    d = os.path.join("Shared", "Assets.xcassets", name + ".imageset")
    images = []
    for scale in (1, 2, 3):
        fn = f"{name}{'' if scale == 1 else f'@{scale}x'}.png"
        save(scaled(im, width=base_w * scale), d, fn)
        images.append({"idiom": "universal", "filename": fn, "scale": f"{scale}x"})
    with open(os.path.join(RES, d, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)


imageset("Logo", WORD, 300)
imageset("LogoMark", MARK, 86)
with open(os.path.join(RES, "Shared", "Assets.xcassets", "Contents.json"), "w") as f:
    json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

# ---- iOS app icon ------------------------------------------------------------------------
icon = background(1024, 1024)
icon.alpha_composite(centered(icon, MARK, frac_w=0.48))
save(icon.convert("RGB"), "iOS", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")

# ---- tvOS layered icons (back opaque, middle glow, front mark) -------------------------------
STACKS = "tvOS/Assets.xcassets/App Icon & Top Shelf Image.brandassets"
for stack, (w, h), scales in (("App Icon", (400, 240), (1, 2)), ("App Icon - App Store", (1280, 768), (1,))):
    for scale in scales:
        W, H = w * scale, h * scale
        sfx = "" if scale == 1 else f"@{scale}x"
        back = background(W, H)
        mid = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse((W * 0.30, H * 0.18, W * 0.70, H * 0.82), fill=RED + (70,))
        mid = glow.filter(ImageFilter.GaussianBlur(H // 8))
        front = centered(back, MARK, frac_h=0.52)
        base = f"{STACKS}/{stack}.imagestack"
        save(back.convert("RGB"), base, "Back.imagestacklayer", "Content.imageset", f"back{sfx}.png")
        save(mid, base, "Middle.imagestacklayer", "Content.imageset", f"middle{sfx}.png")
        save(front, base, "Front.imagestacklayer", "Content.imageset", f"front{sfx}.png")

# ---- top shelf: wordmark on the brand background ---------------------------------------------
for name, (w, h), fn in (("Top Shelf Image", (1920, 720), "shelf"), ("Top Shelf Image Wide", (2320, 720), "shelfwide")):
    for scale in (1, 2):
        W, H = w * scale, h * scale
        im = background(W, H)
        im.alpha_composite(centered(im, WORD, frac_h=0.26))
        save(im.convert("RGB"), STACKS, f"{name}.imageset", f"{fn}{'' if scale == 1 else '@2x'}.png")
print("done")
