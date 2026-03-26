"""
Generate 4-frame animated sprite sheets for each of the 5 glitch debris shapes.
Extracts shapes from glitch_animation.png via BFS connected-component analysis,
then applies per-shape animation effects.

Each shape gets its own distinct animation style, but all effects are toned down
compared to the original — no aggressive line deletion or heavy corruption.

Usage:
    python tools/generate_glitch_frames.py
"""

from PIL import Image, ImageChops
import math
import random
import os

# ── Config ──────────────────────────────────────────────────────────────────
INPUT_IMAGE = os.path.join(os.path.dirname(__file__), "..", "scenes", "effects", "glitch_animation.png")
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "scenes", "effects", "glitch_frames")
PICK_COUNT = 5
DOWNSAMPLE = 4
BRIGHTNESS_THRESH = 0.08
CROP_PAD = 2
MIN_COMPONENT_AREA = 2000
FRAME_COUNT = 4
ANIM_NAMES = [
    "horizontal_glitch",
    "vertical_tear",
    "vortex_circular",
    "diagonal_slash",
    "checkerboard_corruption",
]

random.seed(42)

# ── BFS shape extraction ────────────────────────────────────────────────────

def extract_shapes(img: Image.Image) -> list[tuple[Image.Image, str]]:
    w, h = img.size
    ds = DOWNSAMPLE
    mw = max(w // ds, 1)
    mh = max(h // ds, 1)

    pixels = img.load()
    mask = [[False] * mw for _ in range(mh)]
    for my in range(mh):
        for mx in range(mw):
            r, g, b, a = pixels[mx * ds, my * ds]
            lum = (r + g + b) / (3.0 * 255.0)
            if a / 255.0 > 0.1 and lum > BRIGHTNESS_THRESH:
                mask[my][mx] = True

    visited = [[False] * mw for _ in range(mh)]
    rects = []

    for sy in range(mh):
        for sx in range(mw):
            if visited[sy][sx] or not mask[sy][sx]:
                continue
            q = [(sx, sy)]
            visited[sy][sx] = True
            minx, miny, maxx, maxy = sx, sy, sx, sy
            while q:
                cx, cy = q.pop()
                minx, miny = min(minx, cx), min(miny, cy)
                maxx, maxy = max(maxx, cx), max(maxy, cy)
                for nx, ny in [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)]:
                    if 0 <= nx < mw and 0 <= ny < mh and not visited[ny][nx] and mask[ny][nx]:
                        visited[ny][nx] = True
                        q.append((nx, ny))
            rx0 = max(minx * ds - CROP_PAD, 0)
            ry0 = max(miny * ds - CROP_PAD, 0)
            rx1 = min((maxx + 1) * ds + CROP_PAD, w)
            ry1 = min((maxy + 1) * ds + CROP_PAD, h)
            area = (rx1 - rx0) * (ry1 - ry0)
            if area < MIN_COMPONENT_AREA:
                continue
            rects.append((area, (rx0, ry0, rx1, ry1)))

    rects.sort(key=lambda t: t[0], reverse=True)
    rects = rects[:PICK_COUNT]

    results = []
    for i, (_, (x0, y0, x1, y1)) in enumerate(rects):
        crop = img.crop((x0, y0, x1, y1)).copy()
        name = ANIM_NAMES[i] if i < len(ANIM_NAMES) else f"glitch_{i}"
        results.append((crop, name))
    return results


# ── Common helpers ──────────────────────────────────────────────────────────

def rgb_split(image: Image.Image, offset: int = 2) -> Image.Image:
    """RGB channel offset — color fringing."""
    r, g, b, a = image.split()
    r = ImageChops.offset(r, -offset, 0)
    b = ImageChops.offset(b, offset, 0)
    return Image.merge("RGBA", (r, g, b, a))


def pixel_noise(image: Image.Image, amount: float = 0.03) -> Image.Image:
    """Sparse bright pixel noise — glitch sparkle."""
    img = image.copy()
    px = img.load()
    w, h = img.size
    for x in range(w):
        for y in range(h):
            if random.random() < amount:
                c = random.choice([
                    (0, 255, 255, 200),
                    (255, 0, 255, 200),
                    (255, 255, 255, 220),
                    (255, 255, 0, 180),
                ])
                px[x, y] = c
    return img


# ── 1. Horizontal Glitch ────────────────────────────────────────────────────
# Horizontal slice offsets + ghost trail (like vertical tear but sideways)

def h_slice_offset(image: Image.Image, num_slices: int = 4, max_shift: int = 3) -> Image.Image:
    """Split into horizontal slices, offset some left/right."""
    w, h = image.size
    new_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    slice_h = max(h // num_slices, 1)
    for i in range(num_slices):
        y0 = i * slice_h
        y1 = min(y0 + slice_h, h)
        shift = random.randint(-max_shift, max_shift) if random.random() > 0.3 else 0
        strip = image.crop((0, y0, w, y1))
        new_img.paste(strip, (shift, y0), strip)
    return new_img


def anim_horizontal_glitch(base: Image.Image) -> list[Image.Image]:
    """base → h-slices offset → ghost + more offset → settle"""
    frames = [base.copy()]
    # Frame 2: horizontal slices + ghost trail to the right
    f = h_slice_offset(base, num_slices=4, max_shift=3)
    ghost = diagonal_offset(base, 3, 0)
    f = ghost_overlay(f, ghost, 0.25)
    f = rgb_split(f, 1)
    frames.append(f)
    # Frame 3: more slices + noise + stronger ghost
    f = h_slice_offset(base, num_slices=5, max_shift=4)
    ghost = diagonal_offset(base, 4, 0)
    f = ghost_overlay(f, ghost, 0.35)
    f = pixel_noise(f, 0.03)
    f = rgb_split(f, 2)
    frames.append(f)
    # Frame 4: settle back, slight offset
    f = h_slice_offset(base, num_slices=4, max_shift=1)
    f = rgb_split(f, 1)
    frames.append(f)
    return frames


# ── 2. Vertical Tear ────────────────────────────────────────────────────────
# Column slices offset up/down, small faded gaps

def v_slice_offset(image: Image.Image, num_slices: int = 4, max_shift: int = 3) -> Image.Image:
    """Split into vertical slices, offset some up/down."""
    w, h = image.size
    new_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    slice_w = max(w // num_slices, 1)
    for i in range(num_slices):
        x0 = i * slice_w
        x1 = min(x0 + slice_w, w)
        shift = random.randint(-max_shift, max_shift) if random.random() > 0.3 else 0
        strip = image.crop((x0, 0, x1, h))
        new_img.paste(strip, (x0, shift), strip)
    return new_img


def anim_vertical_tear(base: Image.Image) -> list[Image.Image]:
    """clean → slices offset + ghost → more offset + noise → reassemble"""
    frames = [base.copy()]
    # Frame 2: 4 slices + ghost trail downward
    f = v_slice_offset(base, num_slices=4, max_shift=3)
    ghost = diagonal_offset(base, 0, 3)
    f = ghost_overlay(f, ghost, 0.25)
    f = rgb_split(f, 1)
    frames.append(f)
    # Frame 3: more offset + noise + ghost
    f = v_slice_offset(base, num_slices=5, max_shift=4)
    ghost = diagonal_offset(base, 0, 4)
    f = ghost_overlay(f, ghost, 0.35)
    f = pixel_noise(f, 0.03)
    f = rgb_split(f, 2)
    frames.append(f)
    # Frame 4: reassemble slightly misaligned
    f = v_slice_offset(base, num_slices=4, max_shift=1)
    f = rgb_split(f, 1)
    frames.append(f)
    return frames


# ── 3. Vortex / Circular Glitch ─────────────────────────────────────────────
# Concentric ring slices offset outward + ghost overlay (like vertical tear but radial)

def radial_shards(image: Image.Image, num_rings: int = 4, max_shift: int = 3) -> Image.Image:
    """Split into concentric ring bands, offset each outward/inward."""
    w, h = image.size
    cx, cy = w / 2.0, h / 2.0
    max_r = math.sqrt(cx * cx + cy * cy)
    ring_size = max_r / num_rings

    new_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    src, dst = image.load(), new_img.load()

    # Pre-compute per-ring offsets (dx, dy pointing outward from center)
    ring_shifts = []
    for r in range(num_rings):
        if random.random() > 0.3:
            angle = random.uniform(0, 2 * math.pi)
            dist = random.randint(1, max_shift)
            ring_shifts.append((int(dist * math.cos(angle)), int(dist * math.sin(angle))))
        else:
            ring_shifts.append((0, 0))

    for y in range(h):
        for x in range(w):
            dx, dy = x - cx, y - cy
            dist = math.sqrt(dx * dx + dy * dy)
            ring_idx = min(int(dist / ring_size), num_rings - 1)
            ox, oy = ring_shifts[ring_idx]
            nx, ny = x + ox, y + oy
            if 0 <= nx < w and 0 <= ny < h:
                dst[nx, ny] = src[x, y]
            else:
                dst[x, y] = src[x, y]
    return new_img


def anim_vortex_circular(base: Image.Image) -> list[Image.Image]:
    """base → radial shards + ghost → more shards + noise → settle"""
    frames = [base.copy()]
    # Frame 2: radial shards + ghost outward
    f = radial_shards(base, num_rings=4, max_shift=2)
    ghost = diagonal_offset(base, 2, -2)
    f = ghost_overlay(f, ghost, 0.25)
    f = rgb_split(f, 1)
    frames.append(f)
    # Frame 3: stronger shards + noise + ghost
    f = radial_shards(base, num_rings=5, max_shift=4)
    ghost = diagonal_offset(base, -2, 2)
    f = ghost_overlay(f, ghost, 0.35)
    f = pixel_noise(f, 0.03)
    f = rgb_split(f, 2)
    frames.append(f)
    # Frame 4: settle
    f = radial_shards(base, num_rings=4, max_shift=1)
    f = rgb_split(f, 1)
    frames.append(f)
    return frames


# ── 4. Diagonal Slash ───────────────────────────────────────────────────────
# Ghost duplicate along diagonal, shard movement, snap back

def diagonal_offset(image: Image.Image, dx: int, dy: int) -> Image.Image:
    """Shift entire image diagonally."""
    w, h = image.size
    new_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    src, dst = image.load(), new_img.load()
    for y in range(h):
        for x in range(w):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                dst[nx, ny] = src[x, y]
    return new_img


def ghost_overlay(base: Image.Image, ghost: Image.Image, alpha: float = 0.35) -> Image.Image:
    ghost_faded = ghost.copy()
    r, g, b, a = ghost_faded.split()
    a = a.point(lambda p: int(p * alpha))
    ghost_faded = Image.merge("RGBA", (r, g, b, a))
    result = base.copy()
    return Image.alpha_composite(result, ghost_faded)


def diagonal_shards(image: Image.Image, num_shards: int = 5, max_move: int = 3) -> Image.Image:
    """Split along diagonal bands, move each band slightly along the diagonal."""
    w, h = image.size
    new_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    band_size = max((w + h) // num_shards, 1)
    src = image.load()
    dst = new_img.load()
    for y in range(h):
        for x in range(w):
            band = (x + y) // band_size
            offset = (band % 3 - 1) * random.randint(1, max_move) if band % 2 == 0 else 0
            nx = x + offset
            ny = y + offset
            if 0 <= nx < w and 0 <= ny < h:
                dst[nx, ny] = src[x, y]
            else:
                dst[x, y] = src[x, y]
    return new_img


def anim_diagonal_slash(base: Image.Image) -> list[Image.Image]:
    """base → ghost duplicate → shards along diagonal → snap back offset"""
    frames = [base.copy()]
    # Frame 2: diagonal ghost (duplicate + offset)
    ghost = diagonal_offset(base, 2, 2)
    f = ghost_overlay(base, ghost, 0.35)
    f = rgb_split(f, 1)
    frames.append(f)
    # Frame 3: shards move along diagonal + noise
    f = diagonal_shards(base, num_shards=6, max_move=3)
    f = pixel_noise(f, 0.03)
    f = rgb_split(f, 2)
    frames.append(f)
    # Frame 4: snap back with slight ghost
    ghost = diagonal_offset(base, 1, 1)
    f = ghost_overlay(base, ghost, 0.2)
    f = rgb_split(f, 1)
    frames.append(f)
    return frames


# ── 5. Checkerboard Corruption ──────────────────────────────────────────────
# Grid-based shard offsets — each tile shifts independently + ghost overlay

def grid_shard_offset(image: Image.Image, tile_size: int = 8, max_shift: int = 3, move_chance: float = 0.5) -> Image.Image:
    """Offset random grid tiles in random directions — shard scatter."""
    w, h = image.size
    new_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for ty in range(0, h, tile_size):
        for tx in range(0, w, tile_size):
            tw = min(tile_size, w - tx)
            th = min(tile_size, h - ty)
            tile = image.crop((tx, ty, tx + tw, ty + th))
            if random.random() < move_chance:
                ox = random.randint(-max_shift, max_shift)
                oy = random.randint(-max_shift, max_shift)
            else:
                ox, oy = 0, 0
            px = max(0, min(tx + ox, w - tw))
            py = max(0, min(ty + oy, h - th))
            new_img.paste(tile, (px, py), tile)
    return new_img


def anim_checkerboard_corruption(base: Image.Image) -> list[Image.Image]:
    """base → grid shards scatter + ghost → more scatter + noise → settle"""
    tile_sz = max(base.size[0] // 8, 4)
    frames = [base.copy()]
    # Frame 2: grid shards + ghost
    f = grid_shard_offset(base, tile_sz, max_shift=2, move_chance=0.4)
    ghost = diagonal_offset(base, -2, 2)
    f = ghost_overlay(f, ghost, 0.25)
    f = rgb_split(f, 1)
    frames.append(f)
    # Frame 3: more scatter + noise + ghost
    f = grid_shard_offset(base, tile_sz, max_shift=4, move_chance=0.5)
    ghost = diagonal_offset(base, 2, -1)
    f = ghost_overlay(f, ghost, 0.35)
    f = pixel_noise(f, 0.03)
    f = rgb_split(f, 2)
    frames.append(f)
    # Frame 4: settle
    f = grid_shard_offset(base, tile_sz, max_shift=1, move_chance=0.3)
    f = rgb_split(f, 1)
    frames.append(f)
    return frames


# ── Animation dispatch ──────────────────────────────────────────────────────

ANIM_FUNCS = [
    anim_horizontal_glitch,
    anim_vertical_tear,
    anim_vortex_circular,
    anim_diagonal_slash,
    anim_checkerboard_corruption,
]

# ── Main ────────────────────────────────────────────────────────────────────

def main():
    input_path = os.path.abspath(INPUT_IMAGE)
    output_dir = os.path.abspath(OUTPUT_DIR)
    os.makedirs(output_dir, exist_ok=True)

    print(f"Loading {input_path} ...")
    img = Image.open(input_path).convert("RGBA")
    print(f"  Image size: {img.size}")

    shapes = extract_shapes(img)
    print(f"  Extracted {len(shapes)} shapes")

    sheet_paths = []

    for i, (crop, name) in enumerate(shapes):
        anim_func = ANIM_FUNCS[i] if i < len(ANIM_FUNCS) else anim_horizontal_glitch
        frames = anim_func(crop)
        print(f"  [{i}] {name}: {crop.size}, {len(frames)} frames")

        for fi, frame in enumerate(frames):
            frame.save(os.path.join(output_dir, f"{name}_frame{fi}.png"))

        w, h = crop.size
        sheet = Image.new("RGBA", (w * FRAME_COUNT, h), (0, 0, 0, 0))
        for fi, frame in enumerate(frames):
            sheet.paste(frame, (fi * w, 0))
        sheet_path = os.path.join(output_dir, f"{name}_sheet.png")
        sheet.save(sheet_path)
        sheet_paths.append(sheet_path)
        print(f"    -> {sheet_path}")

    if sheet_paths:
        sheets = [Image.open(p) for p in sheet_paths]
        max_w = max(s.size[0] for s in sheets)
        total_h = sum(s.size[1] for s in sheets)
        atlas = Image.new("RGBA", (max_w, total_h), (0, 0, 0, 0))
        y_off = 0
        for s in sheets:
            atlas.paste(s, (0, y_off))
            y_off += s.size[1]
        atlas_path = os.path.join(output_dir, "combined_atlas.png")
        atlas.save(atlas_path)
        print(f"\n  Combined atlas: {atlas_path} ({atlas.size})")

    print("\nDone!")


if __name__ == "__main__":
    main()
