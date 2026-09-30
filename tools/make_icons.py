"""Draws the game icon variants (doc/05 §3: one creature or diver face, high contrast,
readable at tiny size) into assets/marketing/. Drawn at 4x and downsampled for smooth edges.

    pip install pillow numpy
    python tools/make_icons.py
"""

import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "marketing")
SIZE = 512
S = SIZE * 4  # working resolution
rng = np.random.default_rng(3)


def P(x, y):
    """Normalized (0..1) to working pixels."""
    return (x * S, y * S)


def box(x0, y0, x1, y1):
    return [x0 * S, y0 * S, x1 * S, y1 * S]


def radial(center, inner, outer, radius=0.8, power=1.3):
    """RGB radial gradient image from `inner` at `center` to `outer` at `radius`."""
    yy, xx = np.mgrid[0:S, 0:S] / S
    d = np.sqrt((xx - center[0]) ** 2 + (yy - center[1]) ** 2) / radius
    t = np.clip(d, 0, 1) ** power
    img = np.zeros((S, S, 3))
    for c in range(3):
        img[..., c] = inner[c] * (1 - t) + outer[c] * t
    return Image.fromarray(img.astype(np.uint8), "RGB").convert("RGBA")


def layer():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def glow(base, draw_fn, blur, strength=1.0):
    """Draws with draw_fn on a black layer, blurs it and adds it (light adds up)."""
    light = Image.new("RGB", (S, S), (0, 0, 0))
    draw_fn(ImageDraw.Draw(light))
    light = light.filter(ImageFilter.GaussianBlur(blur * S))
    if strength != 1.0:
        light = Image.eval(light, lambda v: min(255, int(v * strength)))
    rgb = ImageChops.add(base.convert("RGB"), light)
    return rgb.convert("RGBA")


def paste(base, draw_fn, blur=0.0):
    top = layer()
    draw_fn(ImageDraw.Draw(top))
    if blur:
        top = top.filter(ImageFilter.GaussianBlur(blur * S))
    return Image.alpha_composite(base, top)


def light_rays(base, origin, count, color, alpha):
    def draw(d):
        for i in range(count):
            angle = math.radians(70 + i * (40 / max(1, count - 1)) + rng.uniform(-3, 3))
            spread = math.radians(rng.uniform(1.5, 3.5))
            length = 1.6
            p0 = P(*origin)
            p1 = P(origin[0] + math.cos(angle - spread) * length, origin[1] + math.sin(angle - spread) * length)
            p2 = P(origin[0] + math.cos(angle + spread) * length, origin[1] + math.sin(angle + spread) * length)
            d.polygon([p0, p1, p2], fill=color + (alpha,))

    return paste(base, draw, blur=0.02)


def specks(base, count, area=(0, 0, 1, 1)):
    def draw(d):
        for _ in range(count):
            x, y = rng.uniform(area[0], area[2]), rng.uniform(area[1], area[3])
            r = rng.uniform(0.0015, 0.004)
            d.ellipse(box(x - r, y - r, x + r, y + r), fill=(200, 230, 230, int(rng.uniform(60, 160))))

    return paste(base, draw)


def bubbles(base, spots):
    def draw(d):
        for x, y, r in spots:
            d.ellipse(box(x - r, y - r, x + r, y + r), outline=(210, 245, 250, 200), width=int(0.006 * S))
            h = r * 0.35
            d.ellipse(box(x - r * 0.5 - h / 2, y - r * 0.5 - h / 2, x - r * 0.5 + h / 2, y - r * 0.5 + h / 2), fill=(255, 255, 255, 220))

    return paste(base, draw)


def vignette(base, strength=0.75):
    yy, xx = np.mgrid[0:S, 0:S] / S
    d = np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2) / 0.72
    mask = (1 - np.clip(d, 0, 1) ** 2.2 * strength)
    arr = np.array(base.convert("RGB")).astype(float) * mask[..., None]
    return Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")


def bezier(p0, p1, p2, steps=40):
    return [
        ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t**2 * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t**2 * p2[1])
        for t in (i / steps for i in range(steps + 1))
    ]


def teeth_row(d, xs, y, height, down, color):
    for i, x in enumerate(xs):
        w = 0.035 + 0.012 * math.sin(i * 2.3)
        h = height * (0.75 + 0.35 * math.sin(i * 1.7 + 1))
        tip = y + h if down else y - h
        d.polygon([P(x - w / 2, y), P(x + w / 2, y), P(x + rng.uniform(-0.006, 0.006), tip)], fill=color)


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    final = img.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    path = os.path.join(OUT, name)
    final.save(path)
    # A 50 px copy to judge readability at store-listing size.
    final.resize((50, 50), Image.LANCZOS).resize((150, 150), Image.NEAREST).save(path.replace(".png", "_50px.png"))
    print(path)


# --- A: the Warden -----------------------------------------------------------------------------

def warden():
    img = radial((0.35, 0.18), (28, 110, 118), (2, 8, 14), radius=1.0)
    img = light_rays(img, (0.35, -0.1), 5, (120, 210, 210), 26)
    img = specks(img, 140)

    # Light from the lure washes over the upper head.
    lure = (0.27, 0.16)
    img = glow(img, lambda d: d.ellipse(box(lure[0] - 0.45, lure[1] - 0.3, lure[0] + 0.45, lure[1] + 0.5), fill=(70, 40, 30)), 0.12)

    head = box(-0.12, 0.3, 1.12, 1.45)
    rim = box(-0.13, 0.285, 1.13, 1.45)

    def body(d):
        d.ellipse(rim, fill=(120, 70, 70))  # rim light on the upper edge
        d.ellipse(head, fill=(46, 22, 28))

    img = paste(img, body)
    # Soft shading: darker toward the bottom and edges.
    img = paste(img, lambda d: d.ellipse(box(0.05, 0.62, 0.95, 1.6), fill=(12, 4, 8, 150)), blur=0.06)

    # Open maw with a red inner glow.
    mouth = box(0.1, 0.56, 0.9, 1.08)
    img = paste(img, lambda d: d.ellipse(mouth, fill=(8, 2, 4)))
    img = glow(img, lambda d: d.ellipse(box(0.3, 0.78, 0.7, 1.05), fill=(150, 20, 20)), 0.07)
    teeth = (236, 230, 212)
    img = paste(img, lambda d: teeth_row(d, [0.17 + i * 0.066 for i in range(11)], 0.585, 0.12, True, teeth))
    img = paste(img, lambda d: teeth_row(d, [0.22 + i * 0.07 for i in range(9)], 1.02, 0.1, False, teeth))

    # Small, mean eyes with a red glow.
    for ex in (0.24, 0.76):
        img = glow(img, lambda d, ex=ex: d.ellipse(box(ex - 0.05, 0.43, ex + 0.05, 0.51), fill=(255, 40, 30)), 0.02, 1.2)
        img = paste(img, lambda d, ex=ex: d.ellipse(box(ex - 0.035, 0.445, ex + 0.035, 0.495), fill=(255, 90, 60)))
        img = paste(img, lambda d, ex=ex: d.ellipse(box(ex - 0.008, 0.442, ex + 0.008, 0.498), fill=(20, 0, 0)))

    # The lure: a tapering stalk arcing from the forehead to a blazing orb.
    stalk = bezier(P(0.5, 0.34), P(0.5, 0.06), P(*lure))

    def draw_stalk(d):
        for i in range(len(stalk) - 1):
            w = int((0.036 - 0.02 * i / len(stalk)) * S)
            d.line([stalk[i], stalk[i + 1]], fill=(100, 56, 60), width=w)

    img = paste(img, draw_stalk)
    img = glow(img, lambda d: d.ellipse(box(lure[0] - 0.16, lure[1] - 0.16, lure[0] + 0.16, lure[1] + 0.16), fill=(255, 80, 50)), 0.06, 1.3)
    img = glow(img, lambda d: d.ellipse(box(lure[0] - 0.06, lure[1] - 0.06, lure[0] + 0.06, lure[1] + 0.06), fill=(255, 190, 150)), 0.02, 1.5)
    img = paste(img, lambda d: d.ellipse(box(lure[0] - 0.035, lure[1] - 0.035, lure[0] + 0.035, lure[1] + 0.035), fill=(255, 245, 230)))

    img = bubbles(img, [(0.85, 0.2, 0.025), (0.9, 0.12, 0.015), (0.81, 0.08, 0.012)])
    save(vignette(img, 0.6), "icon_warden.png")


# --- B: the diver's helmet ---------------------------------------------------------------------

def helmet():
    img = radial((0.5, 0.3), (24, 92, 112), (2, 6, 14), radius=0.95)
    img = light_rays(img, (0.7, -0.15), 4, (140, 220, 220), 22)
    img = specks(img, 120)

    cx, cy, r = 0.5, 0.52, 0.36
    # Brass dome, lit from the upper left.
    dome = radial((cx - 0.13, cy - 0.16), (246, 206, 118), (70, 44, 16), radius=r * 1.5, power=1.1)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse(box(cx - r, cy - r, cx + r, cy + r), fill=255)
    img.paste(dome, (0, 0), mask)
    img = paste(img, lambda d: d.ellipse(box(cx - r * 0.72, cy - r * 0.88, cx - r * 0.3, cy - r * 0.55), fill=(255, 245, 210, 110)), blur=0.02)

    # Collar at the bottom.
    img = paste(img, lambda d: d.polygon([P(0.2, 0.83), P(0.8, 0.83), P(0.92, 1.02), P(0.08, 1.02)], fill=(120, 82, 34)))
    img = paste(img, lambda d: d.rectangle(box(0.16, 0.83, 0.84, 0.87), fill=(170, 124, 56)))
    for i in range(7):
        bx = 0.22 + i * 0.094
        img = paste(img, lambda d, bx=bx: d.ellipse(box(bx - 0.015, 0.905, bx + 0.015, 0.935), fill=(200, 160, 80)))

    # Front window: thick frame, dark glass, a glint, and two red eyes reflected in it.
    wr = 0.19
    img = paste(img, lambda d: d.ellipse(box(cx - wr - 0.035, cy - wr - 0.035, cx + wr + 0.035, cy + wr + 0.035), fill=(96, 64, 24)))
    img = paste(img, lambda d: d.ellipse(box(cx - wr - 0.02, cy - wr - 0.02, cx + wr + 0.02, cy + wr + 0.02), fill=(205, 160, 80)))
    for i in range(8):
        a = i / 8 * math.pi * 2 + math.pi / 8
        bx, by = cx + math.cos(a) * (wr + 0.005), cy + math.sin(a) * (wr + 0.005)
        img = paste(img, lambda d, bx=bx, by=by: d.ellipse(box(bx - 0.012, by - 0.012, bx + 0.012, by + 0.012), fill=(120, 84, 30)))
    glass = radial((cx, cy + 0.05), (18, 70, 80), (4, 18, 24), radius=wr * 1.3)
    gmask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(gmask).ellipse(box(cx - wr, cy - wr, cx + wr, cy + wr), fill=255)
    img.paste(glass, (0, 0), gmask)
    for ex in (cx - 0.055, cx + 0.055):
        img = glow(img, lambda d, ex=ex: d.ellipse(box(ex - 0.03, cy + 0.02, ex + 0.03, cy + 0.06), fill=(255, 40, 30)), 0.015, 1.3)
        img = paste(img, lambda d, ex=ex: d.ellipse(box(ex - 0.018, cy + 0.028, ex + 0.018, cy + 0.052), fill=(255, 120, 90)))
    img = paste(img, lambda d: d.arc(box(cx - wr * 0.8, cy - wr * 0.8, cx + wr * 0.8, cy + wr * 0.8), 200, 250, fill=(220, 250, 255, 200), width=int(0.014 * S)))

    # Lamp on top with a beam.
    img = glow(img, lambda d: d.polygon([P(0.62, 0.17), P(1.2, -0.3), P(1.2, 0.25)], fill=(150, 175, 150)), 0.05, 1.0)
    img = paste(img, lambda d: d.rounded_rectangle(box(0.52, 0.12, 0.66, 0.2), radius=0.02 * S, fill=(80, 56, 24)))
    img = glow(img, lambda d: d.ellipse(box(0.6, 0.12, 0.68, 0.2), fill=(255, 240, 190)), 0.015, 1.4)

    img = bubbles(img, [(0.12, 0.35, 0.03), (0.09, 0.24, 0.02), (0.14, 0.16, 0.013)])
    save(vignette(img, 0.6), "icon_helmet.png")


if __name__ == "__main__":
    warden()
    helmet()
