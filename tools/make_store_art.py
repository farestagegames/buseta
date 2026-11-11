#!/usr/bin/env python3
"""Draws the Google Play feature graphic and converts store screenshots.

The feature graphic (store/feature_graphic_1024x500.png) is a buseta on a
coastal street in Puerto Marisol at sunrise, with the title in hand-drawn block
letters. It reuses the palette and buseta from tools/make_icons.py, and draws the
lettering itself, so there are no fonts or third-party licences involved.

Screenshots: tools/store_shots.tscn saves raw captures to tools/screens/store/;
this script copies the chosen ones to store/screenshots/ as 24-bit PNGs (no alpha).

Needs Pillow. Run: python3 tools/make_store_art.py
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_icons as icons  # noqa: E402  (palette and the buseta drawing)

ROOT = Path(__file__).resolve().parent.parent
STORE = ROOT / "store"
RAW = ROOT / "tools" / "screens" / "store"
W, H = 1024, 500
K = 3  # supersampling for the feature graphic

# Raw capture name -> published name, in listing order.
SHOTS = [
    ("01_ciudad", "01_ciudad_malecon"),
    ("02d_pasajeros", "02_pasajeros_subiendo"),
    ("03_chiva", "03_chiva_atardecer"),
    ("04_articulado", "04_articulado_la_ola"),
    ("05_aguacero", "05_aguacero_noche"),
    ("06_cabina", "06_cabina_lluvia"),
    ("07_carrera", "07_carrera_express"),
    ("09_garaje", "08_garaje"),
]

FACADES = [(242, 120, 150), (90, 190, 200), (250, 214, 90), (150, 210, 120),
           (240, 160, 80), (180, 150, 220), (245, 240, 225), (110, 170, 230)]


def k(*v):
    return [round(x * K) for x in v]


# --- Lettering: a small rounded block alphabet, just the letters the title needs.
# Each glyph is a list of strokes in a box 0..w wide and 0..1 tall (y down).

def _arc(cx, cy, rx, ry, a0, a1, steps=24):
    pts = []
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        pts.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    return pts


GLYPHS = {
    "C": (0.78, [_arc(0.42, 0.5, 0.38, 0.5, 40, 320)]),
    "I": (0.22, [[(0.11, 0.0), (0.11, 1.0)]]),
    "T": (0.72, [[(0.0, 0.0), (0.72, 0.0)], [(0.36, 0.0), (0.36, 1.0)]]),
    "Y": (0.74, [[(0.0, 0.0), (0.37, 0.5), (0.74, 0.0)], [(0.37, 0.5), (0.37, 1.0)]]),
    "B": (0.70, [[(0.0, 0.0), (0.0, 1.0)],
                 [(0.0, 0.0), (0.34, 0.0)] + _arc(0.34, 0.235, 0.235, 0.235, 270, 450) + [(0.0, 0.47)],
                 [(0.0, 0.47), (0.38, 0.47)] + _arc(0.38, 0.735, 0.265, 0.265, 270, 450) + [(0.0, 1.0)]]),
    "S": (0.66, [_arc(0.33, 0.25, 0.30, 0.25, -25, -270) + _arc(0.33, 0.75, 0.30, 0.25, -90, 155)]),
    "H": (0.72, [[(0.0, 0.0), (0.0, 1.0)], [(0.72, 0.0), (0.72, 1.0)], [(0.0, 0.5), (0.72, 0.5)]]),
    "F": (0.60, [[(0.0, 1.0), (0.0, 0.0), (0.60, 0.0)], [(0.0, 0.48), (0.48, 0.48)]]),
    " ": (0.30, []),
}


def _u_strokes():
    """U: down the left, round the bottom, up the right."""
    pts = [(0.0, 0.0), (0.0, 0.64)]
    for i in range(25):
        a = math.radians(180 - 180 * i / 24)
        pts.append((0.36 + 0.36 * math.cos(a), 0.64 + 0.36 * math.sin(a)))
    pts.append((0.72, 0.0))
    return [pts]


GLYPHS["U"] = (0.72, _u_strokes())


def word_mask(text, cap, stroke, gap):
    """Draws `text` into an L mask. cap = letter height in px, stroke = line width."""
    pad = stroke
    width = sum(GLYPHS[c][0] * cap + gap for c in text) - gap + 2 * pad
    mask = Image.new("L", (round(width), round(cap + 2 * pad)), 0)
    d = ImageDraw.Draw(mask)
    x = pad
    r = stroke / 2
    for c in text:
        w, strokes = GLYPHS[c]
        for line in strokes:
            pts = [(x + px * cap, pad + py * cap) for px, py in line]
            d.line(pts, fill=255, width=round(stroke), joint="curve")
            for px, py in (pts[0], pts[-1]):
                d.ellipse((px - r, py - r, px + r, py + r), fill=255)
        x += w * cap + gap
    return mask


def paste_title(img, text, left, top, cap):
    """Cream letters with an ink outline and a soft shadow."""
    stroke = cap * 0.24
    mask = word_mask(text, cap, stroke, cap * 0.16)
    grow = round(cap * 0.10) | 1
    outline = mask.filter(ImageFilter.MaxFilter(grow if grow % 2 else grow + 1))
    outline = outline.filter(ImageFilter.MaxFilter(grow if grow % 2 else grow + 1))
    shadow = outline.filter(ImageFilter.GaussianBlur(cap * 0.08))
    off = round(cap * 0.07)
    img.paste((0, 0, 0), (left + off, top + off), shadow.point(lambda v: v * 0.45))
    img.paste(icons.INK, (left, top), outline)
    img.paste(icons.CREAM, (left, top), mask)
    return mask.size


# --- Scene

def sky(img):
    d = ImageDraw.Draw(img)
    top, low = (24, 150, 196), (255, 214, 130)
    horizon = 300
    for y in range(horizon * K):
        t = (y / (horizon * K)) ** 1.3
        d.line([(0, y), (W * K, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, low)))
    d.ellipse(k(700, 110, 820, 230), fill=(255, 236, 150))
    d.ellipse(k(720, 130, 800, 210), fill=(255, 250, 210))
    for cx, cy, s in ((180, 70, 1.0), (800, 52, 0.8), (430, 96, 0.6)):
        for dx, dy, r in ((0, 0, 26), (30, -10, 32), (62, 2, 24), (28, 10, 26)):
            d.ellipse(k(cx + (dx - r) * s, cy + (dy - r) * s, cx + (dx + r) * s, cy + (dy + r) * s),
                      fill=(255, 250, 240))


def sea(img):
    d = ImageDraw.Draw(img)
    d.rectangle(k(0, 262, W, 300), fill=(30, 130, 170))
    for i, y in enumerate(range(268, 298, 7)):
        for x in range(-40 + (i % 2) * 30, W, 90):
            d.line(k(x, y, x + 34, y), fill=(120, 200, 220), width=2 * K)


def buildings(img):
    d = ImageDraw.Draw(img)
    x = -10
    i = 0
    heights = [118, 92, 140, 104, 126, 86, 150, 110, 98, 132, 90, 120]
    while x < W:
        w = 74 + (i * 23) % 40
        h = heights[i % len(heights)]
        colour = FACADES[i % len(FACADES)]
        top = 352 - h
        d.rectangle(k(x, top, x + w, 352), fill=colour)
        d.rectangle(k(x - 3, top - 6, x + w + 3, top), fill=tuple(max(0, c - 40) for c in colour))
        for wy in range(top + 14, 330, 30):
            for wx in range(x + 10, x + w - 16, 24):
                d.rectangle(k(wx, wy, wx + 12, wy + 16), fill=icons.GLASS)
                d.rectangle(k(wx, wy, wx + 12, wy + 3), fill=(250, 246, 232))
        x += w + 6
        i += 1


def bunting(img):
    d = ImageDraw.Draw(img)
    colours = [icons.YELLOW, (40, 90, 200), (220, 40, 50), icons.GREEN, icons.ORANGE]
    for x0, x1, sag in ((0, 330, 26), (690, W, 22)):
        pts = []
        steps = 18
        for i in range(steps + 1):
            t = i / steps
            pts.append((x0 + (x1 - x0) * t, 206 + sag * 4 * t * (1 - t)))
        d.line([tuple(round(v * K) for v in p) for p in pts], fill=icons.INK, width=K)
        for i in range(0, steps):
            (ax, ay), (bx, by) = pts[i], pts[i + 1]
            mx, my = (ax + bx) / 2, (ay + by) / 2
            d.polygon(k(ax + 2, ay, bx - 2, by, mx, my + 16), fill=colours[i % len(colours)])


def palm(img, x, base, h, lean):
    d = ImageDraw.Draw(img)
    pts = []
    for i in range(11):
        t = i / 10
        pts.append((x + lean * t * t, base - h * t))
    d.line([tuple(round(v * K) for v in p) for p in pts], fill=(120, 84, 52), width=9 * K, joint="curve")
    tx, ty = pts[-1]
    leaf = (34, 140, 70)
    dark = (24, 104, 54)
    for ang, ln, col in ((-160, 70, dark), (-20, 70, dark), (-120, 64, leaf), (-60, 64, leaf),
                         (160, 58, leaf), (20, 58, leaf), (-90, 46, dark)):
        a = math.radians(ang)
        ex, ey = tx + ln * math.cos(a), ty + ln * math.sin(a) + 22
        mx, my = (tx + ex) / 2, (ty + ey) / 2 - 16
        nx, ny = -math.sin(a) * 9, math.cos(a) * 9
        d.polygon(k(tx, ty, mx + nx, my + ny, ex, ey, mx - nx, my - ny), fill=col)
    d.ellipse(k(tx - 9, ty - 4, tx + 9, ty + 12), fill=(110, 76, 40))


def street(img):
    d = ImageDraw.Draw(img)
    d.rectangle(k(0, 352, W, 372), fill=(196, 190, 176))  # pavement
    d.rectangle(k(0, 370, W, 376), fill=(140, 136, 128))  # kerb
    d.rectangle(k(0, 376, W, H), fill=(58, 58, 66))
    for x in range(-20, W, 96):
        d.rectangle(k(x, 436, x + 50, 444), fill=icons.YELLOW)


def buseta(scale_w):
    """The icon's buseta, cut out of its 432 px canvas and scaled to scale_w px wide."""
    img = icons.canvas()
    d = ImageDraw.Draw(img)
    icons.bus(d)
    icons.wheels(d)
    crop = img.crop(tuple(icons.s(80, 124, 356, 330)))
    h = round(crop.height * scale_w / crop.width)
    return crop.resize((scale_w, h), Image.LANCZOS)


def feature_graphic():
    img = Image.new("RGB", (W * K, H * K))
    sky(img)
    sea(img)
    buildings(img)
    bunting(img)
    street(img)
    palm(img, 540, 372, 200, 18)
    palm(img, 978, 372, 230, -26)
    # Shadow, then the bus, on the near lane; kept well inside the edges.
    d = ImageDraw.Draw(img)
    bw = 350
    bus = buseta(bw * K)
    bh = bus.height / K
    bx, by = 590, 424 - bh
    d.ellipse(k(bx + 14, by + bh - 20, bx + bw - 8, by + bh + 4), fill=(36, 36, 42))
    img.paste(bus, (bx * K, round(by * K)), bus)
    # Title on the left, clear of the bus; stripes from the livery under the last word.
    cap = 66 * K
    paste_title(img, "CITY BUS", 64 * K, 120 * K, cap)
    w, h = paste_title(img, "SHIFT", 64 * K, 214 * K, cap)
    sx = 64 + w / K + 14
    d.rounded_rectangle(k(sx, 248, sx + 110, 262), radius=4 * K, fill=icons.YELLOW, outline=icons.INK, width=2 * K)
    d.rounded_rectangle(k(sx, 270, sx + 110, 284), radius=4 * K, fill=icons.ORANGE, outline=icons.INK, width=2 * K)
    out = img.resize((W, H), Image.LANCZOS).convert("RGB")
    out.save(STORE / "feature_graphic_1024x500.png", optimize=True)
    return out


def screenshots():
    out_dir = STORE / "screenshots"
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for raw, name in SHOTS:
        src = RAW / f"{raw}.png"
        if not src.exists():
            print("missing", src, "- run tools/store_shots.tscn first")
            continue
        img = Image.open(src).convert("RGB")
        w, h = img.size
        if max(w, h) > 2 * min(w, h):  # Play: long side at most twice the short side
            nw = 2 * h if w > h else w
            nh = h if w > h else 2 * w
            left, top = (w - nw) // 2, (h - nh) // 2
            img = img.crop((left, top, left + nw, top + nh))
        img.save(out_dir / f"{name}.png", optimize=True)
        written.append(name)
    return written


def main():
    STORE.mkdir(exist_ok=True)
    (STORE / ".gdignore").touch()
    feature_graphic()
    print("feature graphic written")
    print("screenshots:", ", ".join(screenshots()))


if __name__ == "__main__":
    main()
