#!/usr/bin/env python3
"""Generates the game's tiling textures as PNG files in assets/textures.

Everything is drawn by this script, so there are no third-party licences. Each
texture tiles seamlessly, and is near white where the mesh should tint it.
"""
import math
import random
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"


def save(name, width, height, pixels):
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            r, g, b = pixels[y * width + x]
            rows += bytes((clamp(r), clamp(g), clamp(b)))

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    png += chunk(b"IEND", b"")
    (OUT / name).write_bytes(png)


def clamp(v):
    return max(0, min(255, int(v * 255)))


def tiling_noise(size, cells, seed):
    """Smooth value noise that wraps at the edges."""
    random.seed(seed)
    grid = [[random.random() for _ in range(cells)] for _ in range(cells)]
    out = [0.0] * (size * size)
    for y in range(size):
        fy = y / size * cells
        y0 = int(fy)
        ty = fy - y0
        ty = ty * ty * (3 - 2 * ty)
        for x in range(size):
            fx = x / size * cells
            x0 = int(fx)
            tx = fx - x0
            tx = tx * tx * (3 - 2 * tx)
            a = grid[y0 % cells][x0 % cells]
            b = grid[y0 % cells][(x0 + 1) % cells]
            c = grid[(y0 + 1) % cells][x0 % cells]
            d = grid[(y0 + 1) % cells][(x0 + 1) % cells]
            out[y * size + x] = (a + (b - a) * tx) * (1 - ty) + (c + (d - c) * tx) * ty
    return out


def layers(size, seed, cells_list):
    total = [0.0] * (size * size)
    weight = 0.0
    for i, cells in enumerate(cells_list):
        share = 0.6 ** i
        noise = tiling_noise(size, cells, seed + i)
        total = [t + n * share for t, n in zip(total, noise)]
        weight += share
    return [t / weight for t in total]


def asphalt():
    size = 256
    soft = layers(size, 1, [4, 9])
    random.seed(2)
    pixels = []
    for i in range(size * size):
        grain = random.random()
        value = 0.72 + (soft[i] - 0.5) * 0.3 + (grain - 0.5) * 0.34
        if grain > 0.985:
            value += 0.22
        pixels.append((value, value, value * 1.01))
    save("asphalt.png", size, size, pixels)


def pavement():
    size = 256
    soft = layers(size, 3, [5, 12])
    random.seed(4)
    joint = 4
    slab_tones = [[random.uniform(0.88, 1.0) for _ in range(2)] for _ in range(2)]
    pixels = []
    half = size // 2
    for y in range(size):
        row = y // half
        offset = half // 2 if row % 2 else 0
        for x in range(size):
            column = ((x + offset) % size) // half
            on_joint = y % half < joint or (x + offset) % half < joint
            speck = random.uniform(-0.03, 0.03)
            value = slab_tones[row][column] + (soft[y * size + x] - 0.5) * 0.14 + speck
            if on_joint:
                value *= 0.62
            pixels.append((value, value, value * 0.98))
    save("pavement.png", size, size, pixels)


def grass():
    size = 256
    soft = layers(size, 5, [3, 7, 17])
    random.seed(6)
    pixels = []
    for i in range(size * size):
        blade = random.uniform(-0.09, 0.09)
        value = soft[i]
        r = 0.34 + value * 0.2 + blade
        g = 0.47 + value * 0.2 + blade
        b = 0.22 + value * 0.08 + blade * 0.6
        pixels.append((r, g, b))
    save("grass.png", size, size, pixels)


def brick_value(x, y, size, seed_tones):
    course = size // 16
    row = y // course
    offset = course if row % 2 else 0
    brick = (x + offset) // (course * 2)
    tone = seed_tones[(row * 17 + brick * 31) % len(seed_tones)]
    if y % course < 2 or (x + offset) % (course * 2) < 2:
        return 0.72
    return tone


def facade_flats():
    size = 256
    random.seed(7)
    tones = [random.uniform(0.82, 1.0) for _ in range(61)]
    noise = layers(size, 8, [6, 13])
    pixels = []
    left, right = 70, 186
    top, bottom = 46, 186
    for y in range(size):
        for x in range(size):
            value = brick_value(x, y, size, tones) + (noise[y * size + x] - 0.5) * 0.16
            pixel = (value, value, value)
            frame = left - 8 <= x <= right + 8 and top - 8 <= y <= bottom + 8
            if frame:
                pixel = (0.93, 0.92, 0.9)
            if bottom + 8 < y <= bottom + 16 and left - 14 <= x <= right + 14:
                pixel = (0.8, 0.79, 0.77)
            if left <= x <= right and top <= y <= bottom:
                sky = 0.3 + 0.28 * (bottom - y) / (bottom - top)
                pixel = (sky * 0.75, sky * 0.9, sky * 1.1)
                if abs(x - (left + right) // 2) < 4 or abs(y - 96) < 3:
                    pixel = (0.9, 0.89, 0.87)
            pixels.append(pixel)
    save("facade_flats.png", size, size, pixels)


def facade_office():
    size = 256
    pixels = []
    noise = layers(size, 9, [4])
    for y in range(size):
        for x in range(size):
            value = 0.9 + (noise[y * size + x] - 0.5) * 0.1
            pixel = (value, value, value)
            if 16 <= y <= 196 and x % 128 > 8:
                reflect = 0.3 + 0.3 * ((x + y * 0.5) % 256) / 256 + 0.1 * noise[y * size + x]
                pixel = (reflect * 0.72, reflect * 0.9, reflect * 1.08)
            pixels.append(pixel)
    save("facade_office.png", size, size, pixels)


def facade_shops():
    width, height = 512, 256
    random.seed(10)
    pixels = []
    for y in range(height):
        for x in range(width):
            pixel = (0.93, 0.92, 0.9)
            if y < 58:
                pixel = (0.78, 0.76, 0.72)
                if 14 <= y <= 44 and 40 <= x <= 470 and (x // 14 + y // 10) % 3 == 0:
                    pixel = (0.3, 0.28, 0.27)
            elif y > 232:
                pixel = (0.45, 0.45, 0.47)
            elif 40 <= x < 320 or 340 <= x < 420 or 440 <= x < 500:
                glow = 0.46 + 0.2 * math.sin(x * 0.025 + y * 0.012)
                pixel = (glow * 0.8, glow * 0.9, glow)
                if 340 <= x < 420:
                    pixel = (0.2, 0.26, 0.3)
                if y > 195 and x < 320:
                    pixel = (0.68, 0.58, 0.44)
            else:
                pixel = (0.3, 0.3, 0.33)
            pixels.append(pixel)
    save("facade_shops.png", width, height, pixels)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    asphalt()
    pavement()
    grass()
    facade_flats()
    facade_office()
    facade_shops()


if __name__ == "__main__":
    main()
