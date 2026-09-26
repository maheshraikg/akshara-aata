"""Builds stroke-order data for kagunita (consonant + vowel sign) writing.

  pip install pillow numpy scipy scikit-image
  python3 tool/make_kagunita_paths.py [consonants…]

The kagunita are drawn in the app's font (Baloo Tamma 2). The consonant part
keeps the real stroke order of the consonant (from assets/writing/, made by
make_writing_paths.py): the Commons letter is fitted onto the font's
consonant and each pixel takes the time of the nearest Commons ink. The
vowel sign is written afterwards: parts touching the consonant first, then
the others from left to right, each traced along its centre line from the
end nearest the consonant (or its top-left end).
Writes assets/writing/<key>.png (as for letters) and
assets/writing/kagunita.json (pen paths).
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage
from skimage.morphology import skeletonize

FONT = 'assets/fonts/BalooTamma2-ExtraBold.ttf'
SIZE = 150          # font size in px; the glyph ends up ~200 px tall
BODY = 0.62         # share of the time for the consonant part
CONSONANTS = 'ಕಖಗಘಙಚಛಜಝಞಟಠಡಢಣತಥದಧನಪಫಬಭಮಯರಲವಶಷಸಹಳ'
SIGNS = ['ಾ', 'ಿ', 'ೀ', 'ು', 'ೂ', 'ೃ', 'ೆ', 'ೇ', 'ೈ', 'ೊ', 'ೋ', 'ೌ', 'ಂ', 'ಃ']
font = ImageFont.truetype(FONT, SIZE, layout_engine=ImageFont.Layout.RAQM)


def key(text):
    return '_'.join(f'{ord(c):x}' for c in text)


def render(text):
    """Anti-aliased coverage (0-1) of text on a fixed canvas."""
    im = Image.new('L', (SIZE * 4, SIZE * 3), 0)
    ImageDraw.Draw(im).text((SIZE // 2, SIZE // 3), text, font=font, fill=255,
                            language='kn')
    return np.asarray(im) / 255.0


def letter_times(ch, shape):
    """Commons stroke times fitted onto the font's consonant mask."""
    la = np.asarray(Image.open(f'assets/writing/{key(ch)}.png').convert('LA'))
    t, a = la[..., 0] / 254.0, la[..., 1] > 110
    ys, xs = np.nonzero(a)
    fy, fx = np.nonzero(shape)
    # Scale the Commons ink box onto the font glyph's box.
    sx = (fx.max() - fx.min() + 1) / (xs.max() - xs.min() + 1)
    sy = (fy.max() - fy.min() + 1) / (ys.max() - ys.min() + 1)
    src = np.zeros(shape.shape, bool)
    tt = np.zeros(shape.shape)
    px = np.clip(((xs - xs.min()) * sx + fx.min()).round().astype(int), 0, shape.shape[1] - 1)
    py = np.clip(((ys - ys.min()) * sy + fy.min()).round().astype(int), 0, shape.shape[0] - 1)
    src[py, px] = True
    tt[py, px] = t[ys, xs]
    _, (iy, ix) = ndimage.distance_transform_edt(~src, return_indices=True)
    times = tt[iy, ix]
    return times, (xs.min(), ys.min(), sx, sy, fx.min(), fy.min(), la.shape)


def trace_order(comp, start):
    """Orders a stroke's pixels along its centre line from start."""
    sk = skeletonize(comp)
    if not sk.any():
        sk = comp.copy()
    pts = set(zip(*np.nonzero(sk)))
    # Nearest skeleton pixel to the start.
    s = min(pts, key=lambda p: (p[0] - start[0]) ** 2 + (p[1] - start[1]) ** 2)
    order, seen, stack = [], {s}, [s]
    # Depth-first walk that prefers going straight on.
    prev = None
    cur = s
    while True:
        order.append(cur)
        nbrs = [(cur[0] + dy, cur[1] + dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                if (dy or dx) and (cur[0] + dy, cur[1] + dx) in pts
                and (cur[0] + dy, cur[1] + dx) not in seen]
        if nbrs:
            if prev is not None:
                d = (cur[0] - prev[0], cur[1] - prev[1])
                nbrs.sort(key=lambda n: -((n[0] - cur[0]) * d[0] + (n[1] - cur[1]) * d[1]))
            nxt = nbrs[0]
            for n in nbrs[1:]:
                stack.append(n)
            seen.add(nxt)
            prev, cur = cur, nxt
            continue
        # Dead end: jump to the nearest unvisited branch.
        rest = [p for p in stack if p not in seen]
        if not rest:
            break
        nxt = min(rest, key=lambda p: (p[0] - cur[0]) ** 2 + (p[1] - cur[1]) ** 2)
        seen.add(nxt)
        prev, cur = None, nxt
    rank = np.full(comp.shape, -1.0)
    for i, p in enumerate(order):
        rank[p] = i / max(len(order) - 1, 1)
    mask = rank >= 0
    _, (iy, ix) = ndimage.distance_transform_edt(~mask, return_indices=True)
    return np.where(comp, rank[iy, ix], 0), [(p[1], p[0]) for p in order]


def build(ch, sign):
    base = render(ch) > 0.5
    text = ch + sign
    cov = render(text)
    ink = cov > 0.5
    ctime, _ = letter_times(ch, base)
    near = ndimage.binary_dilation(base, iterations=2)
    body = ink & near
    time = np.zeros(ink.shape)
    # Consonant part: keep its order, spread evenly over the remaining pixels.
    bt = ctime[body]
    ranks = np.searchsorted(np.sort(bt), bt, side='right') / max(len(bt), 1)
    time[body] = ranks * BODY
    head = []
    by, bx = np.nonzero(body)
    order_idx = np.argsort(time[body])
    for q in np.linspace(0, len(order_idx) - 1, 24).astype(int):
        i = order_idx[q]
        # Pen near the newest ink: average of pixels drawn around that time.
        head.append((time[body][i], bx[i], by[i]))

    rest = ink & ~body
    lab, n = ndimage.label(rest, structure=np.ones((3, 3)))
    comps = []
    for i in range(1, n + 1):
        c = lab == i
        if c.sum() < 25:
            time[c] = BODY
            continue
        touch = (c & ndimage.binary_dilation(body, iterations=2)).any()
        ys, xs = np.nonzero(c)
        comps.append((not touch, xs.min(), c))
    comps.sort(key=lambda c: (c[0], c[1]))
    lengths = [max(skeletonize(c[2]).sum(), 1) for c in comps]
    total = sum(lengths) or 1
    t0 = BODY + (0.03 if comps else 0)
    span = 1 - t0 - 0.02 * max(len(comps) - 1, 0)
    for (detached, _, c), ln in zip(comps, lengths):
        ys, xs = np.nonzero(c)
        if not detached:
            # Start where the sign meets the consonant.
            d = ndimage.distance_transform_edt(~body)
            i = np.argmin(np.where(c, d, np.inf))
            start = np.unravel_index(i, c.shape)
        else:
            i = np.argmin(np.where(c, np.indices(c.shape)[0] + np.indices(c.shape)[1] * 0.6, np.inf))
            start = np.unravel_index(i, c.shape)
        r, path = trace_order(c, start)
        dur = span * ln / total
        time[c] = t0 + r[c] * dur
        for q in np.linspace(0, len(path) - 1, max(4, min(20, len(path) // 6))).astype(int):
            head.append((t0 + q / max(len(path) - 1, 1) * dur, path[q][0], path[q][1]))
        t0 += dur + 0.02
    # Crop and write.
    ys, xs = np.nonzero(cov > 0.02)
    y0, y1, x0, x1 = ys.min() - 4, ys.max() + 5, xs.min() - 4, xs.max() + 5
    a = (np.clip(cov[y0:y1, x0:x1], 0, 1) * 255).astype(np.uint8)
    tn = time.copy()
    # Edge pixels take the time of the nearest solid ink.
    _, (iy, ix) = ndimage.distance_transform_edt(~ink, return_indices=True)
    tn = tn[iy, ix]
    tg = (np.clip(tn[y0:y1, x0:x1], 0, 1) * 254).astype(np.uint8)
    tg[a == 0] = 0
    img = Image.merge('LA', (Image.fromarray(tg), Image.fromarray(a)))
    head.sort()
    w, h = x1 - x0, y1 - y0
    return img, [[round(float(t), 3), round((x - x0) / w, 3), round((y - y0) / h, 3)]
                 for t, x, y in head]


if __name__ == '__main__':
    only = sys.argv[1:] or list(CONSONANTS)
    path = 'assets/writing/kagunita.json'
    data = json.load(open(path, encoding='utf-8')) if os.path.exists(path) else {}
    for ch in only:
        for s in SIGNS:
            img, head = build(ch, s)
            img.save(f'assets/writing/{key(ch + s)}.png', optimize=True)
            data[ch + s] = {'head': head}
        print(ch, flush=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
