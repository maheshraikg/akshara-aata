"""Builds the handwriting checker's letter shapes.

  pip install pillow numpy scipy scikit-image
  python3 tool/make_shapes.py

For every letter and kagunita with a writing guide (assets/writing/<key>.png,
made by make_writing_paths.py and make_kagunita_paths.py) it takes the centre
line of the ink, scales it into a square (keeping its shape) and stores, for
each centre-line point: its position, the direction of the line there and
when it is written. The app compares a child's writing with these shapes
(lib/handwriting.dart), all on the phone.

Writes assets/writing/shapes.json: {text: [x, y, angle, time, ...]} with
x, y in 0-GRID, angle in degrees (0-179) and time in 0-99.
"""
import json

import numpy as np
from PIL import Image
from scipy import ndimage
from skimage.morphology import skeletonize

W = 'assets/writing/'
GRID = 48          # must match Handwriting.grid in lib/handwriting.dart
RADIUS = 2.5       # neighbourhood for the line direction, in grid cells


def key(text):
    return '_'.join(f'{ord(c):x}' for c in text)


def shape(text):
    a = np.array(Image.open(W + key(text) + '.png').convert('LA'))
    ink = ndimage.binary_opening(a[..., 1] > 128)
    ys, xs = np.nonzero(skeletonize(ink))
    t = a[ys, xs, 0] / 254
    p = np.stack([xs, ys], 1).astype(float)
    lo, hi = p.min(0), p.max(0)
    p = (p - (lo + hi) / 2) / max(hi - lo) + .5
    # One point per grid cell (the earliest written).
    cells = {}
    for (x, y), ti in sorted(zip(np.round(p * GRID).astype(int).tolist(), t),
                             key=lambda c: c[1]):
        cells.setdefault((x, y), ti)
    pts = np.array(list(cells), float)
    out = []
    for (x, y), ti in cells.items():
        near = pts[((pts - (x, y)) ** 2).sum(1) <= RADIUS ** 2]
        near = near - near.mean(0)
        v = np.linalg.eigh(near.T @ near)[1][:, 1]
        angle = int(round(np.degrees(np.arctan2(v[1], v[0])))) % 180
        out += [x, y, angle, int(round(ti * 99))]
    return out


def main():
    texts = list(json.load(open(W + 'strokes.json')))
    texts += list(json.load(open(W + 'kagunita.json')))
    shapes = {t: shape(t) for t in texts}
    with open(W + 'shapes.json', 'w') as f:
        json.dump(shapes, f, ensure_ascii=False, separators=(',', ':'))
    n = [len(s) // 4 for s in shapes.values()]
    print(f'{len(shapes)} shapes, {min(n)}-{max(n)} points each')


if __name__ == '__main__':
    main()
