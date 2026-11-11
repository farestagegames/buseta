#!/usr/bin/env python3
"""Draws the app icons: a Colombian buseta on a coastal street at sunrise.

Everything is drawn here, so there are no third-party licences. Writes to
assets/icons/ (Android launcher layers), assets/icon.png (project icon) and
store/icon_512.png (Play listing icon).
Needs Pillow. Run: python3 tools/make_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "icons"
STORE = ROOT / "store"  # Play Console listing art, kept out of the game
S = 4  # supersampling factor; the art is laid out on a 432 px adaptive-icon canvas
N = 432
VISIBLE = 288  # Android shows the centre 72 of 108 dp of an adaptive layer

INK = (28, 36, 56)
CREAM = (250, 246, 232)
GREEN = (22, 138, 96)
YELLOW = (255, 200, 40)
ORANGE = (240, 110, 40)
GLASS = (58, 108, 150)
GLASS_HI = (140, 190, 220)
TYRE = (34, 34, 40)
HUB = (196, 198, 204)


def s(*v):
    return [round(x * S) for x in v]


def canvas():
    return Image.new("RGBA", (N * S, N * S), (0, 0, 0, 0))


def finish(img, size=N):
    return img.resize((size, size), Image.LANCZOS)


def background():
    img = canvas()
    d = ImageDraw.Draw(img)
    top, low = (24, 150, 196), (255, 214, 130)
    horizon = 292
    for y in range(horizon * S):
        t = (y / (horizon * S)) ** 1.4
        c = tuple(round(a + (b - a) * t) for a, b in zip(top, low))
        d.line([(0, y), (N * S, y)], fill=c + (255,))
    d.ellipse(s(118, 88, 178, 148), fill=(255, 236, 150, 255))
    d.ellipse(s(128, 98, 168, 138), fill=(255, 250, 210, 255))
    d.rectangle(s(0, 292, N, N), fill=(58, 58, 66, 255))
    d.rectangle(s(0, 292, N, 298), fill=(90, 90, 98, 255))
    for x in range(-10, N, 64):
        d.rectangle(s(x, 334, x + 34, 340), fill=YELLOW + (255,))
    return img


def bus(d, colour=None):
    """Draws the buseta. With `colour`, draws a flat silhouette in that colour."""
    def c(rgb):
        return colour if colour else rgb + (255,)

    x0, y0, x1, y1 = 88, 148, 344, 292
    # Outline first, then the body inside it.
    d.rounded_rectangle(s(x0 - 5, y0 - 5, x1 + 5, y1 + 5), radius=26 * S, fill=c(INK))
    d.rounded_rectangle(s(x0, y0, x1, y1), radius=22 * S, fill=c(CREAM))
    if colour:
        return
    # Lower body and livery stripes.
    d.rounded_rectangle(s(x0, 232, x1, y1), radius=22 * S, fill=GREEN + (255,))
    d.rectangle(s(x0, 232, x1, 252), fill=GREEN + (255,))
    d.polygon(s(x0, 236, x1, 228, x1, 240, x0, 248), fill=YELLOW + (255,))
    d.polygon(s(x0, 250, x1, 242, x1, 252, x0, 260), fill=ORANGE + (255,))
    # Roof sign.
    d.rounded_rectangle(s(236, 128, 318, 152), radius=6 * S, fill=INK + (255,))
    d.rounded_rectangle(s(241, 133, 313, 147), radius=3 * S, fill=YELLOW + (255,))
    # Side windows.
    for wx in (102, 150, 198):
        d.rounded_rectangle(s(wx, 166, wx + 40, 216), radius=6 * S, fill=GLASS + (255,))
        d.polygon(s(wx + 4, 212, wx + 22, 170, wx + 30, 170, wx + 12, 212), fill=GLASS_HI + (255,))
    # Door.
    d.rounded_rectangle(s(248, 166, 280, 280), radius=5 * S, fill=INK + (255,))
    d.rounded_rectangle(s(252, 170, 276, 222), radius=4 * S, fill=GLASS + (255,))
    # Windscreen, raked at the front.
    d.polygon(s(290, 166, 326, 166, 338, 222, 290, 222), fill=GLASS + (255,))
    d.polygon(s(296, 218, 310, 170, 318, 170, 304, 218), fill=GLASS_HI + (255,))
    # Headlight and bumper.
    d.ellipse(s(324, 258, 340, 274), fill=(255, 244, 180, 255))
    d.rounded_rectangle(s(318, 280, 350, 292), radius=4 * S, fill=INK + (255,))


def wheels(d, colour=None):
    for cx in (140, 296):
        d.ellipse(s(cx - 34, 258, cx + 34, 326), fill=colour or INK + (255,))
        d.ellipse(s(cx - 27, 265, cx + 27, 319), fill=colour or TYRE + (255,))
        if not colour:
            d.ellipse(s(cx - 11, 281, cx + 11, 303), fill=HUB + (255,))


def shrink(img, k=0.8):
    """Scales the bus about the centre so it sits inside the launcher's safe circle."""
    small = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
    out = canvas()
    out.paste(small, ((img.width - small.width) // 2, (img.height - small.height) // 2))
    return out


def foreground():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.ellipse(s(84, 310, 352, 330), fill=(0, 0, 0, 70))
    bus(d)
    wheels(d)
    return shrink(img)


def monochrome():
    """Single-colour shape for Android 13 themed icons; only alpha is used."""
    img = canvas()
    d = ImageDraw.Draw(img)
    white = (255, 255, 255, 255)
    clear = (0, 0, 0, 0)
    bus(d, white)
    for wx in (102, 150, 198):
        d.rounded_rectangle(s(wx, 166, wx + 40, 216), radius=6 * S, fill=clear)
    d.rounded_rectangle(s(252, 170, 276, 222), radius=4 * S, fill=clear)
    d.polygon(s(290, 166, 326, 166, 338, 222, 290, 222), fill=clear)
    d.rectangle(s(88, 236, 344, 244), fill=clear)
    wheels(d, white)
    for cx in (140, 296):
        d.ellipse(s(cx - 11, 281, cx + 11, 303), fill=clear)
    return shrink(img)


def flat(size, rounded):
    """Background and foreground merged, cropped to what a launcher shows."""
    full = Image.alpha_composite(background(), foreground())
    m = (N - VISIBLE) // 2 * S
    img = full.crop((m, m, N * S - m, N * S - m)).resize((size, size), Image.LANCZOS)
    if rounded:
        mask = Image.new("L", (size * S, size * S), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, size * S, size * S), radius=size * S // 5, fill=255)
        img.putalpha(mask.resize((size, size), Image.LANCZOS))
    else:
        img = img.convert("RGB")
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    finish(background()).convert("RGB").save(OUT / "adaptive_background_432.png")
    finish(foreground()).save(OUT / "adaptive_foreground_432.png")
    finish(monochrome()).save(OUT / "adaptive_monochrome_432.png")
    flat(192, True).save(OUT / "main_192.png")
    STORE.mkdir(exist_ok=True)
    (STORE / ".gdignore").touch()
    flat(512, False).save(STORE / "icon_512.png")
    flat(512, True).save(ROOT / "assets" / "icon.png")
    print("icons written to", OUT)


if __name__ == "__main__":
    main()
