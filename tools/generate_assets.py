#!/usr/bin/env python3
"""Procedural pixel-art generator for the Metropolis demo assets.

The art is intentionally simple (flat shaded pixel art, 2:1 isometric diamonds)
so that the whole asset set can be regenerated from source with no binary
tooling and no external image libraries. Run it from the repository root:

    python3 tools/generate_assets.py

It writes:
    assets/sprites/terrain/terrain_tileset.png  (+ terrain_tileset.tres)
    assets/sprites/props/{bush,rock_cluster,tree}.png
    assets/sprites/buildings/{house,workshop}_stage{0,1,2}.png
    assets/sprites/buildings/overdue_decal.png
    assets/sprites/characters/villager.png
    assets/sprites/ui/{icon_create,icon_confirm,icon_cancel}.png
    assets/sprites/effects/dot.png
    icon.png
"""

from __future__ import annotations

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Art is authored at "logical" resolution and upscaled with nearest-neighbour so
# the pixel grid stays perfectly square in-engine.
SCALE = 2

# Logical tile size for the 2:1 isometric diamond grid.
TILE_W = 32
TILE_H = 16

TRANSPARENT = (0, 0, 0, 0)


# --------------------------------------------------------------------------- #
# Tiny RGBA image buffer + PNG writer
# --------------------------------------------------------------------------- #
class Img:
    def __init__(self, w: int, h: int):
        self.w = w
        self.h = h
        self.px = [[TRANSPARENT] * w for _ in range(h)]

    def set(self, x: int, y: int, c) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            if c[3] == 0:
                return
            if c[3] < 255:
                self.px[y][x] = self.blend_pixel(self.px[y][x], c)
            else:
                self.px[y][x] = c

    @staticmethod
    def blend_pixel(dst, src):
        sa = src[3] / 255.0
        da = dst[3] / 255.0
        oa = sa + da * (1 - sa)
        if oa <= 0:
            return TRANSPARENT
        out = []
        for i in range(3):
            out.append(int(round((src[i] * sa + dst[i] * da * (1 - sa)) / oa)))
        return (out[0], out[1], out[2], int(round(oa * 255)))

    def get(self, x: int, y: int):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return TRANSPARENT

    def fill_rect(self, x0, y0, x1, y1, c, outline=None) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                edge = x in (x0, x1) or y in (y0, y1)
                self.set(x, y, outline if (edge and outline) else c)

    def fill_poly(self, pts, c, outline=None) -> None:
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            n = len(pts)
            for i in range(n):
                x1, y1 = pts[i]
                x2, y2 = pts[(i + 1) % n]
                if (y1 <= y < y2) or (y2 <= y < y1):
                    xs.append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                a = int(round(xs[i]))
                b = int(round(xs[i + 1]))
                for x in range(a, b + 1):
                    self.set(x, y, c)
        if outline:
            n = len(pts)
            for i in range(n):
                x1, y1 = pts[i]
                x2, y2 = pts[(i + 1) % n]
                steps = max(abs(x2 - x1), abs(y2 - y1), 1)
                for s in range(steps + 1):
                    x = x1 + (x2 - x1) * s / steps
                    y = y1 + (y2 - y1) * s / steps
                    self.set(int(round(x)), int(round(y)), outline)

    def upscale(self, n: int) -> "Img":
        out = Img(self.w * n, self.h * n)
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                for dy in range(n):
                    for dx in range(n):
                        out.px[y * n + dy][x * n + dx] = c
        return out

    def blit(self, other: "Img", ox: int, oy: int) -> None:
        for y in range(other.h):
            for x in range(other.w):
                self.set(ox + x, oy + y, other.get(x, y))

    def save(self, path: str, n: int = SCALE) -> None:
        img = self.upscale(n) if n != 1 else self
        full = os.path.join(ROOT, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        write_png(full, img)


def write_png(path: str, img: Img) -> None:
    raw = bytearray()
    for row in img.px:
        raw.append(0)  # filter type: none
        for (r, g, b, a) in row:
            raw += bytes((r, g, b, a))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", img.w, img.h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as fh:
        fh.write(png)
    print("  %-52s %dx%d" % (os.path.relpath(path, ROOT), img.w, img.h))


# --------------------------------------------------------------------------- #
# Palette
# --------------------------------------------------------------------------- #
GRASS_LIGHT = (134, 189, 99, 255)
GRASS_MID = (106, 168, 79, 255)
GRASS_DARK = (78, 130, 58, 255)
GRASS_DEEP = (58, 100, 44, 255)

DIRT_LIGHT = (196, 155, 106, 255)
DIRT_MID = (176, 139, 90, 255)
DIRT_DARK = (138, 106, 66, 255)

SAND_LIGHT = (226, 205, 155, 255)
SAND_MID = (203, 180, 128, 255)

WATER_LIGHT = (127, 184, 232, 255)
WATER_MID = (74, 144, 217, 255)
WATER_DARK = (47, 111, 168, 255)

STONE_LIGHT = (169, 169, 169, 255)
STONE_MID = (141, 141, 141, 255)
STONE_DARK = (105, 105, 105, 255)

WOOD_LIGHT = (160, 110, 66, 255)
WOOD_MID = (128, 86, 48, 255)
WOOD_DARK = (94, 62, 34, 255)

WALL_LIGHT = (233, 222, 191, 255)
WALL_MID = (207, 194, 160, 255)
WALL_DARK = (170, 157, 126, 255)

ROOF_RED_LIGHT = (206, 106, 92, 255)
ROOF_RED_MID = (181, 69, 58, 255)
ROOF_RED_DARK = (140, 51, 43, 255)

ROOF_BLUE_LIGHT = (108, 143, 194, 255)
ROOF_BLUE_MID = (74, 111, 165, 255)
ROOF_BLUE_DARK = (54, 82, 126, 255)

GLASS = (129, 190, 214, 255)
GLASS_DARK = (78, 133, 163, 255)
SMOKE = (206, 206, 206, 200)
DUST = (150, 138, 118, 190)
CRACK = (74, 66, 58, 210)
SHADOW = (0, 0, 0, 60)


def noise(x: int, y: int, seed: int) -> float:
    """Deterministic 0..1 value noise (no RNG state, fully reproducible)."""
    h = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def speckle(img: Img, x0, y0, x1, y1, color, chance: float, seed: int) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if noise(x, y, seed) < chance:
                img.set(x, y, color)


# --------------------------------------------------------------------------- #
# Terrain tiles
# --------------------------------------------------------------------------- #
def diamond(cx: float, cy: float, w: int, h: int):
    hw = w / 2.0
    hh = h / 2.0
    return [
        (cx, cy - hh),
        (cx + hw, cy),
        (cx, cy + hh),
        (cx - hw, cy),
    ]


def new_tile() -> Img:
    return Img(TILE_W, TILE_H)


def base_tile(img: Img, light, mid, dark, deep, seed: int) -> None:
    """Fill the tile diamond with top-lit banding plus a little texture."""
    cx = TILE_W / 2.0
    hw = TILE_W / 2.0
    hh = TILE_H / 2.0
    for y in range(TILE_H):
        t = y / float(TILE_H - 1)
        if t < 0.3:
            c = light
        elif t < 0.65:
            c = mid
        elif t < 0.9:
            c = dark
        else:
            c = deep
        # Row half-width of a 2:1 isometric diamond, widest at the tile centre.
        half = (1.0 - abs(y + 0.5 - hh) / hh) * hw
        if half < 0:
            half = 0.0
        for x in range(TILE_W):
            if abs(x + 0.5 - cx) <= half - 0.5:
                img.set(int(x), y, c)
    speckle(img, 4, 3, TILE_W - 5, TILE_H - 4, c_darken(c, 0.08), 0.16, seed)


def c_darken(c, amount: float):
    return (
        max(0, min(255, int(c[0] * (1 - amount)))),
        max(0, min(255, int(c[1] * (1 - amount)))),
        max(0, min(255, int(c[2] * (1 - amount)))),
        c[3],
    )


def c_lighten(c, amount: float):
    return (
        max(0, min(255, int(c[0] + (255 - c[0]) * amount))),
        max(0, min(255, int(c[1] + (255 - c[1]) * amount))),
        max(0, min(255, int(c[2] + (255 - c[2]) * amount))),
        c[3],
    )


def tile_grass(seed=1) -> Img:
    img = new_tile()
    base_tile(img, GRASS_LIGHT, GRASS_MID, GRASS_DARK, GRASS_DEEP, seed)
    for y in (3, 4):
        for x in range(6, 12):
            img.set(x, y, c_lighten(GRASS_LIGHT, 0.18))
    for x, y in ((24, 9), (27, 7), (7, 11)):
        img.set(x, y, c_darken(GRASS_DARK, 0.15))
    return img


def tile_path(seed=2) -> Img:
    img = new_tile()
    base_tile(img, DIRT_LIGHT, DIRT_MID, DIRT_DARK, (110, 84, 52, 255), seed)
    speckle(img, 3, 2, TILE_W - 4, TILE_H - 3, SAND_LIGHT, 0.12, seed + 7)
    for x, y in ((10, 5), (18, 9), (24, 6)):
        img.set(x, y, c_darken(DIRT_DARK, 0.2))
    return img


def tile_water_fill(seed=3) -> Img:
    img = new_tile()
    base_tile(img, WATER_LIGHT, WATER_MID, WATER_DARK, (34, 88, 140, 255), seed)
    for y in (4, 7, 10):
        for x in range(4, TILE_W - 4):
            if noise(x, y, seed + 3) < 0.5:
                img.set(x, y, c_lighten(WATER_MID, 0.22))
    return img


def tile_water_edge(seed=4) -> Img:
    """Shallow water: a sand rim with a water body inset inside the diamond."""
    img = new_tile()
    base_tile(img, SAND_LIGHT, SAND_MID, SAND_LIGHT, DIRT_MID, seed)
    img.fill_poly(diamond(TILE_W / 2.0, 9, 24, 11), WATER_DARK)
    img.fill_poly(diamond(TILE_W / 2.0, 8, 22, 10), WATER_MID)
    img.fill_poly(diamond(TILE_W / 2.0, 7, 18, 8), WATER_LIGHT)
    for y in (8, 11):
        for x in range(6, TILE_W - 6):
            if noise(x, y, seed + 3) < 0.5:
                img.set(x, y, c_lighten(WATER_MID, 0.2))
    return img


def tile_hill(seed=5) -> Img:
    img = tile_grass(seed)
    img.fill_poly(diamond(16, 6, 24, 10), c_lighten(GRASS_MID, 0.22))
    img.fill_poly(diamond(16, 8, 16, 7), GRASS_LIGHT)
    for x in range(6, 26):
        img.set(x, 12, c_darken(GRASS_DEEP, 0.2))
    speckle(img, 8, 3, 24, 9, c_darken(GRASS_DARK, 0.12), 0.14, seed + 11)
    return img


def tile_rock(seed=6) -> Img:
    img = tile_grass(seed)
    img.fill_poly([(6, 11), (10, 5), (16, 3), (22, 6), (25, 11), (16, 13)], STONE_MID)
    img.fill_poly([(10, 10), (13, 6), (18, 6), (21, 10), (16, 12)], STONE_LIGHT)
    img.fill_poly([(13, 10), (15, 7), (18, 7), (20, 10), (16, 11)], STONE_DARK)
    for x, y in ((8, 12), (24, 12), (16, 14)):
        img.set(x, y, c_darken(GRASS_DEEP, 0.25))
    return img


def tile_forest(seed=7) -> Img:
    img = tile_grass(seed)
    for cx, cy in ((9, 8), (16, 5), (23, 8), (13, 12), (20, 12)):
        img.fill_poly(diamond(cx, cy, 11, 7), GRASS_DEEP)
        img.fill_poly(diamond(cx, cy - 1, 8, 5), c_darken(GRASS_DEEP, 0.25))
        img.fill_poly(diamond(cx, cy - 2, 4, 2), c_darken(GRASS_DEEP, 0.4))
    return img


def tile_dirt(seed=8) -> Img:
    img = new_tile()
    base_tile(img, DIRT_MID, DIRT_MID, DIRT_DARK, (110, 84, 52, 255), seed)
    speckle(img, 3, 2, TILE_W - 4, TILE_H - 3, WOOD_DARK, 0.1, seed + 5)
    return img


TILE_ORDER = [
    ("grass", tile_grass),
    ("path", tile_path),
    ("water", tile_water_fill),
    ("hill", tile_hill),
    ("water_edge", tile_water_edge),
    ("rock", tile_rock),
    ("forest", tile_forest),
    ("dirt", tile_dirt),
]

TILE_COLS = 4


def build_tileset() -> None:
    rows = (len(TILE_ORDER) + TILE_COLS - 1) // TILE_COLS
    sheet = Img(TILE_W * TILE_COLS, TILE_H * rows)
    coords = []
    for i, (_name, fn) in enumerate(TILE_ORDER):
        col = i % TILE_COLS
        row = i // TILE_COLS
        sheet.blit(fn(seed=i + 1), col * TILE_W, row * TILE_H)
        coords.append((col, row))
    sheet.save("assets/sprites/terrain/terrain_tileset.png")
    write_tileset_tres(coords)


def write_tileset_tres(coords) -> None:
    lines = [
        '[gd_resource type="TileSet" load_steps=3 format=3]',
        "",
        '[ext_resource type="Texture2D" path="res://assets/sprites/terrain/terrain_tileset.png" id="1_terrain"]',
        "",
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_terrain"]',
        'texture = ExtResource("1_terrain")',
        "texture_region_size = Vector2i(%d, %d)" % (TILE_W * SCALE, TILE_H * SCALE),
    ]
    for (col, row) in coords:
        lines.append("%d:%d/0 = 0" % (col, row))
    lines += [
        "",
        "[resource]",
        "tile_shape = 0",
        "tile_layout = 0",
        "tile_offset_axis = 0",
        "tile_size = Vector2i(%d, %d)" % (TILE_W * SCALE, TILE_H * SCALE),
        'sources/0 = SubResource("TileSetAtlasSource_terrain")',
        "",
    ]
    path = os.path.join(ROOT, "assets/sprites/terrain/terrain_tileset.tres")
    with open(path, "w") as fh:
        fh.write("\n".join(lines))
    print("  assets/sprites/terrain/terrain_tileset.tres")


# --------------------------------------------------------------------------- #
# Decorative props
# --------------------------------------------------------------------------- #
def iso_ground_shadow(img: Img, cx: int, cy: int, w: int) -> None:
    img.fill_poly(diamond(cx, cy, w, max(3, w // 2)), SHADOW)


def prop_bush() -> Img:
    img = Img(16, 14)
    iso_ground_shadow(img, 8, 12, 12)
    img.fill_poly(diamond(8, 9, 12, 8), GRASS_DEEP)
    img.fill_poly(diamond(8, 8, 11, 7), GRASS_MID)
    img.fill_poly(diamond(8, 7, 8, 5), GRASS_LIGHT)
    for x, y in ((5, 6), (11, 6), (8, 4)):
        img.set(x, y, c_lighten(GRASS_LIGHT, 0.2))
    return img


def prop_rock_cluster() -> Img:
    img = Img(18, 14)
    iso_ground_shadow(img, 9, 12, 13)
    for cx, cy, w, h in ((7, 9, 9, 6), (12, 10, 7, 5)):
        img.fill_poly(diamond(cx, cy, w, h), STONE_MID)
        img.fill_poly(diamond(cx, cy - 1, w - 3, h - 3), STONE_LIGHT)
    img.fill_poly(diamond(9, 11, 6, 4), STONE_DARK)
    return img


def prop_tree() -> Img:
    img = Img(16, 24)
    iso_ground_shadow(img, 8, 22, 11)
    img.fill_rect(7, 16, 8, 21, WOOD_MID)
    img.set(7, 21, WOOD_DARK)
    img.set(8, 21, WOOD_LIGHT)
    img.fill_poly(diamond(8, 11, 15, 13), GRASS_DEEP)
    img.fill_poly(diamond(8, 10, 12, 10), GRASS_MID)
    img.fill_poly(diamond(8, 8, 8, 7), GRASS_LIGHT)
    for x, y in ((4, 12), (12, 12), (8, 5)):
        img.set(x, y, c_lighten(GRASS_LIGHT, 0.15))
    return img


# --------------------------------------------------------------------------- #
# Buildings (32x32 logical art, base sits on the tile centre)
# --------------------------------------------------------------------------- #
BLD = 32


def _scaffold(img: Img, x0, y0, x1, y1, color=WOOD_LIGHT) -> None:
    img.fill_rect(x0, y0, x0 + 1, y1, color)
    img.fill_rect(x1 - 1, y0, x1, y1, color)
    for y in range(y0, y1 + 1, 4):
        img.fill_rect(x0, y, x1, y + 1, WOOD_MID)


def _foundation(img: Img, cx: int, cy: int, w: int, stone: bool) -> None:
    base = STONE_MID if stone else DIRT_MID
    light = STONE_LIGHT if stone else DIRT_LIGHT
    img.fill_poly(diamond(cx, cy, w, 10), c_darken(base, 0.25))
    img.fill_poly(diamond(cx, cy - 1, w - 2, 8), base)
    img.fill_poly(diamond(cx, cy - 2, w - 6, 5), light)
    for dx in (-w // 2 + 1, w // 2 - 2):
        img.set(cx + dx, cy - 7, WOOD_MID)


def house_stage0() -> Img:
    img = Img(BLD, BLD)
    iso_ground_shadow(img, 16, 28, 20)
    _foundation(img, 16, 27, 20, False)
    _scaffold(img, 7, 16, 25, 27)
    img.fill_rect(12, 24, 14, 26, WOOD_MID)
    img.fill_rect(18, 24, 20, 26, WOOD_MID)
    return img


def house_stage1() -> Img:
    img = Img(BLD, BLD)
    iso_ground_shadow(img, 16, 28, 20)
    _foundation(img, 16, 27, 20, False)
    # Half-height walls.
    img.fill_rect(9, 15, 23, 26, WALL_MID)
    img.fill_rect(9, 15, 9, 26, WALL_LIGHT)
    img.fill_rect(23, 15, 23, 26, WALL_DARK)
    for y in range(17, 25, 3):
        img.fill_rect(10, y, 22, y, c_darken(WALL_MID, 0.12))
    # Roof trusses started.
    img.fill_poly([(16, 6), (25, 15), (7, 15)], ROOF_RED_MID)
    img.fill_poly([(16, 6), (25, 15), (16, 15)], ROOF_RED_DARK)
    _scaffold(img, 6, 14, 25, 27, WOOD_LIGHT)
    return img


def house_stage2() -> Img:
    img = Img(BLD, BLD)
    iso_ground_shadow(img, 16, 28, 20)
    img.fill_rect(9, 14, 23, 27, WALL_MID)
    img.fill_rect(9, 14, 9, 27, WALL_LIGHT)
    img.fill_rect(23, 14, 23, 27, WALL_DARK)
    for y in range(16, 26, 3):
        img.fill_rect(10, y, 22, y, c_darken(WALL_MID, 0.1))
    # Door + window.
    img.fill_rect(14, 22, 18, 27, WOOD_DARK)
    img.fill_rect(15, 23, 17, 26, WOOD_MID)
    img.set(17, 25, ROOF_RED_LIGHT)
    img.fill_rect(10, 17, 13, 20, GLASS)
    img.fill_rect(19, 17, 22, 20, GLASS)
    img.fill_rect(11, 18, 12, 19, GLASS_DARK)
    img.fill_rect(20, 18, 21, 19, GLASS_DARK)
    # Roof.
    img.fill_poly([(16, 3), (26, 14), (6, 14)], ROOF_RED_MID, ROOF_RED_DARK)
    img.fill_poly([(16, 3), (16, 14), (6, 14)], ROOF_RED_LIGHT)
    img.fill_poly([(16, 3), (26, 14), (16, 14)], ROOF_RED_DARK)
    for y in range(6, 14, 3):
        img.fill_rect(9 + y - 3, y, 23 - (y - 3), y, c_darken(ROOF_RED_MID, 0.1))
    return img


def workshop_stage0() -> Img:
    img = Img(BLD, BLD)
    iso_ground_shadow(img, 16, 29, 26)
    _foundation(img, 16, 28, 26, True)
    _scaffold(img, 3, 12, 29, 28, WOOD_LIGHT)
    img.fill_rect(6, 24, 10, 27, STONE_MID)
    img.fill_rect(22, 24, 26, 27, STONE_MID)
    return img


def workshop_stage1() -> Img:
    img = Img(BLD, BLD)
    iso_ground_shadow(img, 16, 29, 26)
    _foundation(img, 16, 28, 26, True)
    img.fill_rect(4, 12, 28, 28, WALL_MID)
    img.fill_rect(4, 12, 4, 28, WALL_LIGHT)
    img.fill_rect(28, 12, 28, 28, WALL_DARK)
    for x in range(6, 28, 4):
        img.fill_rect(x, 13, x, 27, c_darken(WALL_MID, 0.1))
    img.fill_rect(12, 20, 20, 28, WOOD_DARK)
    for y in range(16, 19):
        img.fill_rect(7, y, 11, y, c_darken(WALL_MID, 0.18))
    # Partial roof: flat deck with a couple of trusses.
    img.fill_rect(4, 11, 28, 13, WOOD_MID)
    _scaffold(img, 2, 10, 29, 28, WOOD_LIGHT)
    return img


def workshop_stage2() -> Img:
    img = Img(BLD, BLD)
    iso_ground_shadow(img, 16, 29, 26)
    img.fill_rect(4, 11, 28, 28, WALL_MID)
    img.fill_rect(4, 11, 4, 28, WALL_LIGHT)
    img.fill_rect(28, 11, 28, 28, WALL_DARK)
    for x in range(6, 28, 4):
        img.fill_rect(x, 12, x, 27, c_darken(WALL_MID, 0.1))
    for y in range(14, 20, 4):
        for x in range(7, 27, 5):
            img.fill_rect(x, y, x + 3, y + 3, GLASS)
            img.fill_rect(x, y, x + 3, y, GLASS_DARK)
    img.fill_rect(12, 19, 20, 28, WOOD_DARK)
    img.fill_rect(13, 20, 19, 27, WOOD_MID)
    img.set(18, 24, ROOF_BLUE_LIGHT)
    # Gabled roof + chimney.
    img.fill_poly([(16, 1), (30, 12), (2, 12)], ROOF_BLUE_MID, ROOF_BLUE_DARK)
    img.fill_poly([(16, 1), (16, 12), (2, 12)], ROOF_BLUE_LIGHT)
    img.fill_poly([(16, 1), (30, 12), (16, 12)], ROOF_BLUE_DARK)
    for y in range(4, 12, 3):
        img.fill_rect(6 + (y - 4), y, 26 - (y - 4), y, c_darken(ROOF_BLUE_MID, 0.12))
    img.fill_rect(22, 0, 25, 6, STONE_MID)
    img.fill_rect(22, 0, 22, 6, STONE_LIGHT)
    img.fill_rect(25, 0, 25, 6, STONE_DARK)
    return img


BUILDINGS = {
    "house": [house_stage0, house_stage1, house_stage2],
    "workshop": [workshop_stage0, workshop_stage1, workshop_stage2],
}


def overdue_decal() -> Img:
    """Cracks + dust overlaid on top of any building stage."""
    img = Img(BLD, BLD)
    cracks = [
        [(9, 20), (12, 24), (10, 28), (14, 30)],
        [(12, 24), (18, 23), (22, 26)],
        [(14, 30), (13, 31)],
        [(20, 12), (18, 17), (21, 20)],
    ]
    for pts in cracks:
        for i in range(len(pts) - 1):
            (x1, y1), (x2, y2) = pts[i], pts[i + 1]
            steps = max(abs(x2 - x1), abs(y2 - y1), 1)
            for s in range(steps + 1):
                img.set(
                    int(round(x1 + (x2 - x1) * s / steps)),
                    int(round(y1 + (y2 - y1) * s / steps)),
                    CRACK,
                )
    for i in range(26):
        x = 5 + int(noise(i, 1, 99) * 22)
        y = 22 + int(noise(i, 2, 99) * 8)
        img.set(x, y, DUST)
    return img


# --------------------------------------------------------------------------- #
# Villager: 5 frames of 8x12 (idle, walk 1-3, build)
# --------------------------------------------------------------------------- #
VILL_W = 8
VILL_H = 12
VILL_FRAMES = 5


def villager_frame(index: int) -> Img:
    img = Img(VILL_W, VILL_H)
    skin = (232, 190, 150, 255)
    skin_dark = (196, 150, 112, 255)
    shirt = (86, 132, 200, 255)
    shirt_dark = (62, 100, 160, 255)
    pants = (70, 74, 88, 255)
    # Ground shadow.
    img.fill_poly(diamond(4, 11, 7, 3), SHADOW)
    # Legs.
    if index in (1, 3):
        img.fill_rect(2, 8, 3, 10, pants)
        img.fill_rect(5, 8, 5, 10, pants)
    else:
        img.fill_rect(3, 8, 4, 10, pants)
    # Torso.
    img.fill_rect(2, 4, 5, 8, shirt)
    img.fill_rect(2, 4, 2, 8, c_lighten(shirt, 0.2))
    img.fill_rect(5, 4, 5, 8, shirt_dark)
    # Head.
    img.fill_rect(2, 1, 5, 4, skin)
    img.fill_rect(2, 1, 5, 1, c_darken(skin_dark, 0.3))  # hat brim
    img.set(5, 3, skin_dark)
    # Arms.
    if index == 4:  # building: one arm raised
        img.fill_rect(1, 3, 1, 4, shirt)
        img.fill_rect(6, 2, 7, 3, skin)
    elif index in (1, 3):
        img.fill_rect(1, 5, 1, 6, shirt)
        img.fill_rect(6, 5, 6, 6, shirt)
    else:
        img.fill_rect(1, 5, 1, 7, shirt)
        img.fill_rect(6, 5, 6, 7, shirt)
        img.set(1, 8, skin)
        img.set(6, 8, skin)
    return img


def villager_sheet() -> Img:
    img = Img(VILL_W * VILL_FRAMES, VILL_H)
    for i in range(VILL_FRAMES):
        img.blit(villager_frame(i), i * VILL_W, 0)
    return img


# --------------------------------------------------------------------------- #
# UI icons + particle dot
# --------------------------------------------------------------------------- #
def icon_create() -> Img:
    img = Img(16, 16)
    c = (240, 240, 240, 255)
    d = (120, 120, 120, 255)
    img.fill_rect(7, 3, 8, 12, c, d)
    img.fill_rect(3, 7, 12, 8, c, d)
    return img


def icon_confirm() -> Img:
    img = Img(16, 16)
    c = (240, 240, 240, 255)
    d = (120, 120, 120, 255)
    pts = [(3, 8), (6, 12), (12, 4)]
    for i in range(len(pts) - 1):
        (x1, y1), (x2, y2) = pts[i], pts[i + 1]
        steps = max(abs(x2 - x1), abs(y2 - y1)) * 2
        for s in range(steps + 1):
            x = int(round(x1 + (x2 - x1) * s / steps))
            y = int(round(y1 + (y2 - y1) * s / steps))
            img.fill_rect(x, y, x + 1, y + 1, c if (x + y) % 3 else d)
    return img


def icon_cancel() -> Img:
    img = Img(16, 16)
    c = (240, 240, 240, 255)
    d = (120, 120, 120, 255)
    for i in range(10):
        img.fill_rect(3 + i, 3 + i, 4 + i, 4 + i, c, d)
        img.fill_rect(12 - i, 3 + i, 13 - i, 4 + i, c, d)
    return img


def dot() -> Img:
    img = Img(4, 4)
    for y in range(4):
        for x in range(4):
            d = abs(x - 1.5) + abs(y - 1.5)
            a = int(max(0, min(255, 255 * (1.5 - d / 3.0))))
            img.px[y][x] = (255, 255, 255, a)
    return img


# --------------------------------------------------------------------------- #
# App icon
# --------------------------------------------------------------------------- #
def app_icon() -> Img:
    img = Img(64, 64)
    for y in range(64):
        t = y / 63.0
        c = (
            int(38 + (86 - 38) * t),
            int(58 + (140 - 58) * t),
            int(96 + (92 - 96) * t),
            255,
        )
        img.fill_rect(0, y, 63, y, c)
    grass = Img(TILE_W, TILE_H)
    base_tile(grass, GRASS_LIGHT, GRASS_MID, GRASS_DARK, GRASS_DEEP, 21)
    for col in range(3):
        for row in range(3):
            img.blit(grass, 6 + col * 18 + row * 9, 30 + row * 7)
    house = house_stage2()
    for dx, dy in ((0, 0), (22, 6), (11, 16)):
        img.blit(house, 3 + dx, 2 + dy)
    workshop = workshop_stage2()
    img.blit(workshop, 2, 2)
    return img


# --------------------------------------------------------------------------- #
def main() -> None:
    print("Generating Metropolis demo assets...")
    build_tileset()
    for name, fn in (
        ("assets/sprites/props/bush.png", prop_bush),
        ("assets/sprites/props/rock_cluster.png", prop_rock_cluster),
        ("assets/sprites/props/tree.png", prop_tree),
        ("assets/sprites/buildings/overdue_decal.png", overdue_decal),
        ("assets/sprites/characters/villager.png", villager_sheet),
        ("assets/sprites/ui/icon_create.png", icon_create),
        ("assets/sprites/ui/icon_confirm.png", icon_confirm),
        ("assets/sprites/ui/icon_cancel.png", icon_cancel),
        ("assets/sprites/effects/dot.png", dot),
        ("icon.png", app_icon),
    ):
        fn().save(name)
    for bname, stages in BUILDINGS.items():
        for i, fn in enumerate(stages):
            fn().save("assets/sprites/buildings/%s_stage%d.png" % (bname, i))
    print("Done.")


if __name__ == "__main__":
    main()
