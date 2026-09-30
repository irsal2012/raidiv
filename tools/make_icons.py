"""Draws the game icon variants (doc/05 §3: one creature or diver face, high contrast,
readable at tiny size) and the hero thumbnail into assets/marketing/. Drawn at a larger size
and downsampled for smooth edges. Coordinates are in units of the canvas height, so x runs
0..1 on the square icons and 0..1.78 on the 16:9 thumbnail.

    pip install pillow numpy
    python tools/make_icons.py
"""

import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "marketing")
# Working canvas; set per image by canvas().
CW = CH = S = 2048
rng = np.random.default_rng(3)


def canvas(width, height):
    global CW, CH, S
    CW, CH, S = width, height, height


def P(x, y):
    """Canvas units (height = 1) to working pixels."""
    return (x * S, y * S)


def box(x0, y0, x1, y1):
    return [x0 * S, y0 * S, x1 * S, y1 * S]


def radial(center, inner, outer, radius=0.8, power=1.3):
    """RGB radial gradient image from `inner` at `center` to `outer` at `radius`."""
    yy, xx = np.mgrid[0:CH, 0:CW] / S
    d = np.sqrt((xx - center[0]) ** 2 + (yy - center[1]) ** 2) / radius
    t = np.clip(d, 0, 1) ** power
    img = np.zeros((CH, CW, 3))
    for c in range(3):
        img[..., c] = inner[c] * (1 - t) + outer[c] * t
    return Image.fromarray(img.astype(np.uint8), "RGB").convert("RGBA")


def layer():
    return Image.new("RGBA", (CW, CH), (0, 0, 0, 0))


def glow(base, draw_fn, blur, strength=1.0):
    """Draws with draw_fn on a black layer, blurs it and adds it (light adds up)."""
    light = Image.new("RGB", (CW, CH), (0, 0, 0))
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


def specks(base, count, area=None):
    area = area or (0, 0, CW / S, 1)

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
    yy, xx = np.mgrid[0:CH, 0:CW] / S
    d = np.sqrt(((xx - CW / S / 2) / (CW / CH)) ** 2 + (yy - 0.5) ** 2) / 0.72
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


def save(img, name, size, preview=False):
    os.makedirs(OUT, exist_ok=True)
    final = img.convert("RGB").resize(size, Image.LANCZOS)
    path = os.path.join(OUT, name)
    final.save(path)
    if preview:
        # A 50 px copy to judge readability at store-listing size.
        final.resize((50, 50), Image.LANCZOS).resize((150, 150), Image.NEAREST).save(path.replace(".png", "_50px.png"))
    print(path)


# --- A: the Warden -----------------------------------------------------------------------------

def warden():
    canvas(2048, 2048)
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
    save(vignette(img, 0.6), "icon_warden.png", (512, 512), True)


# --- B: the diver's helmet ---------------------------------------------------------------------

def helmet():
    canvas(2048, 2048)
    img = radial((0.5, 0.3), (24, 92, 112), (2, 6, 14), radius=0.95)
    img = light_rays(img, (0.7, -0.15), 4, (140, 220, 220), 22)
    img = specks(img, 120)

    cx, cy, r = 0.5, 0.52, 0.36
    # Brass dome, lit from the upper left.
    dome = radial((cx - 0.13, cy - 0.16), (246, 206, 118), (70, 44, 16), radius=r * 1.5, power=1.1)
    mask = Image.new("L", (CW, CH), 0)
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
    gmask = Image.new("L", (CW, CH), 0)
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
    save(vignette(img, 0.6), "icon_helmet.png", (512, 512), True)


# --- Hero thumbnail: a diver escaping with a Legendary as the Warden closes in ----------------

TITLE_FONT = "/System/Library/Fonts/Supplemental/Futura.ttc"
TITLE_FONT_INDEX = 4  # Condensed ExtraBold


def rotated(cx, cy, angle):
    """Maps local (x, y) around (cx, cy), rotated by `angle` degrees, to working pixels."""
    a = math.radians(angle)
    ca, sa = math.cos(a), math.sin(a)

    def T(x, y):
        return P(cx + x * ca - y * sa, cy + x * sa + y * ca)

    return T


def ellipse_poly(T, x, y, rx, ry, steps=36):
    return [T(x + rx * math.cos(i / steps * 2 * math.pi), y + ry * math.sin(i / steps * 2 * math.pi)) for i in range(steps)]


def thumbnail():
    canvas(2880, 1620)
    W = CW / S  # canvas width in units (1.78)
    img = radial((0.75, -0.15), (40, 140, 150), (2, 8, 16), radius=1.5, power=1.1)
    img = light_rays(img, (0.7, -0.25), 7, (140, 225, 225), 24)
    img = specks(img, 260)

    # The Warden fills the right side, jaws open toward the diver.
    lure = (1.2, 0.2)
    img = glow(img, lambda d: d.ellipse(box(lure[0] - 0.5, lure[1] - 0.3, lure[0] + 0.5, lure[1] + 0.6), fill=(60, 30, 25)), 0.1)

    def body(d):
        d.ellipse(box(1.08, 0.1, 2.5, 1.5), fill=(120, 70, 70))
        d.ellipse(box(1.09, 0.115, 2.5, 1.5), fill=(46, 22, 28))

    img = paste(img, body)
    img = paste(img, lambda d: d.ellipse(box(1.3, 0.8, 2.4, 1.8), fill=(12, 4, 8, 160)), blur=0.06)
    mx, my, mrx, mry = 1.34, 0.77, 0.28, 0.35
    img = paste(img, lambda d: d.ellipse(box(mx - mrx, my - mry, mx + mrx, my + mry), fill=(8, 2, 4)))
    img = glow(img, lambda d: d.ellipse(box(1.25, 0.62, 1.6, 1.0), fill=(150, 20, 20)), 0.06)
    teeth = (236, 230, 212)

    def edge(x, top):
        """Point on the mouth outline at `x`, nudged inside so teeth grow from the lip."""
        t = max(0.0, 1 - ((x - mx) / mrx) ** 2)
        return my - mry * math.sqrt(t) * 0.97 if top else my + mry * math.sqrt(t) * 0.97

    def jaw_teeth(d, xs, top, height):
        for i, x in enumerate(xs):
            w = 0.034 + 0.01 * math.sin(i * 2.3)
            h = height * (0.75 + 0.35 * math.sin(i * 1.7 + 1)) * (0.5 + 0.5 * math.sqrt(max(0, 1 - ((x - mx) / mrx) ** 2)))
            y0, y1 = edge(x - w / 2, top), edge(x + w / 2, top)
            tip = edge(x, top) + (h if top else -h)
            d.polygon([P(x - w / 2, y0), P(x + w / 2, y1), P(x, tip)], fill=teeth)

    img = paste(img, lambda d: jaw_teeth(d, [mx - mrx + 0.05 + i * 0.066 for i in range(8)], True, 0.13))
    img = paste(img, lambda d: jaw_teeth(d, [mx - mrx + 0.08 + i * 0.066 for i in range(7)], False, 0.11))
    ex, ey = 1.7, 0.36
    img = glow(img, lambda d: d.ellipse(box(ex - 0.05, ey - 0.04, ex + 0.05, ey + 0.04), fill=(255, 40, 30)), 0.02, 1.2)
    img = paste(img, lambda d: d.ellipse(box(ex - 0.035, ey - 0.028, ex + 0.035, ey + 0.028), fill=(255, 90, 60)))
    img = paste(img, lambda d: d.ellipse(box(ex - 0.008, ey - 0.03, ex + 0.008, ey + 0.03), fill=(20, 0, 0)))
    stalk = bezier(P(1.62, 0.16), P(1.45, -0.05), P(*lure))

    def draw_stalk(d):
        for i in range(len(stalk) - 1):
            d.line([stalk[i], stalk[i + 1]], fill=(100, 56, 60), width=int((0.03 - 0.016 * i / len(stalk)) * S))

    img = paste(img, draw_stalk)
    img = glow(img, lambda d: d.ellipse(box(lure[0] - 0.12, lure[1] - 0.12, lure[0] + 0.12, lure[1] + 0.12), fill=(255, 80, 50)), 0.05, 1.3)
    img = paste(img, lambda d: d.ellipse(box(lure[0] - 0.028, lure[1] - 0.028, lure[0] + 0.028, lure[1] + 0.028), fill=(255, 245, 230)))

    # The diver, swimming up and left toward the light, crown held high.
    dx, dy, angle = 0.66, 0.46, -40
    T = rotated(dx, dy, angle)
    suit = (28, 44, 52)
    rim = (120, 200, 205)
    brass = (205, 160, 80)
    # Lamp beam ahead of the helmet.
    img = glow(img, lambda d: d.polygon([T(0, -0.22), T(-0.35, -1.1), T(0.35, -1.1)], fill=(70, 95, 85)), 0.05)

    def figure(d, color, grow):
        g = grow
        d.polygon(ellipse_poly(T, 0, 0, 0.07 + g, 0.15 + g), fill=color)  # torso
        for side in (-1, 1):  # legs and fins
            d.polygon(ellipse_poly(T, side * 0.035, 0.22, 0.03 + g, 0.1 + g), fill=color)
            d.polygon([T(side * 0.035 - 0.04 - g, 0.3), T(side * 0.035 + 0.04 + g, 0.3), T(side * 0.035 + side * 0.03, 0.42 + g)], fill=color)
        for (x0, y0), (x1, y1), r in (((-0.05, -0.1), (-0.12, -0.3), 0.021), ((0.055, -0.08), (0.13, 0.05), 0.018)):
            d.line([T(x0, y0), T(x1, y1)], fill=color, width=int(2 * (r + g) * S))  # arms
            for x, y in ((x0, y0), (x1, y1)):
                d.ellipse(box(*_circle(T, x, y, r + g)), fill=color)
        d.polygon(ellipse_poly(T, 0.075, 0.0, 0.035 + g, 0.11 + g), fill=color)  # tank on the back
        d.ellipse(box(*_circle(T, 0, -0.2, 0.065 + g)), fill=color)  # helmet

    img = paste(img, lambda d: figure(d, rim + (255,), 0.006))
    img = paste(img, lambda d: figure(d, suit + (255,), 0))
    hx, hy = T(0, -0.2)
    hx, hy = hx / S, hy / S
    img = paste(img, lambda d: d.ellipse(box(hx - 0.065, hy - 0.065, hx + 0.065, hy + 0.065), fill=brass))
    img = paste(img, lambda d: d.ellipse(box(hx - 0.033, hy - 0.04, hx + 0.027, hy + 0.02), fill=(20, 70, 80)))
    img = glow(img, lambda d: d.ellipse(box(hx - 0.02, hy - 0.035, hx + 0.02, hy + 0.005), fill=(110, 200, 190)), 0.01)

    # The Drowned Crown in the raised hand, blazing Legendary gold.
    cx, cy = T(-0.12, -0.36)
    cx, cy = cx / S, cy / S
    img = glow(img, lambda d: d.ellipse(box(cx - 0.2, cy - 0.2, cx + 0.2, cy + 0.2), fill=(255, 170, 40)), 0.07, 1.2)
    crown = [(-0.09, 0.05), (0.09, 0.05), (0.1, -0.06), (0.05, -0.01), (0.0, -0.08), (-0.05, -0.01), (-0.1, -0.06)]
    img = paste(img, lambda d: d.polygon([P(cx + x, cy + y) for x, y in crown], fill=(255, 200, 60)))
    img = paste(img, lambda d: d.rectangle(box(cx - 0.09, cy + 0.02, cx + 0.09, cy + 0.05), fill=(215, 150, 40)))
    for gx, color in ((-0.05, (90, 230, 220)), (0.0, (160, 90, 255)), (0.05, (90, 230, 220))):
        img = paste(img, lambda d, gx=gx, color=color: d.ellipse(box(cx + gx - 0.012, cy + 0.023, cx + gx + 0.012, cy + 0.047), fill=color))

    img = bubbles(img, [(hx + 0.02, hy - 0.12, 0.018), (hx + 0.05, hy - 0.22, 0.013), (hx + 0.01, hy - 0.3, 0.01), (hx + 0.06, hy - 0.38, 0.008)])
    img = vignette(img, 0.55)

    # Title, bottom left.
    from PIL import ImageFont

    font = ImageFont.truetype(TITLE_FONT, int(0.16 * S), index=TITLE_FONT_INDEX)
    title = "DEEP SALVAGE"
    tx, ty = 0.06 * S, 0.78 * S
    img = glow(img, lambda d: d.text((tx, ty), title, font=font, fill=(40, 160, 170)), 0.02, 1.0)
    img = paste(img, lambda d: d.text((tx, ty), title, font=font, fill=(245, 250, 250), stroke_width=int(0.008 * S), stroke_fill=(6, 20, 26)))
    save(img, "thumbnail_escape.png", (1920, 1080))


def _circle(T, x, y, r):
    px, py = T(x, y)
    return (px / S - r, py / S - r, px / S + r, py / S + r)


if __name__ == "__main__":
    warden()
    helmet()
    thumbnail()
