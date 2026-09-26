"""Turns the Wikimedia Commons Kannada writing animations (a pencil writes
each letter; Gopala Krishna A, CC BY-SA 4.0, "Animations of Kannada letters")
into data for the app's own writing animation.

  pip install pillow numpy
  python3 tool/make_writing_paths.py commons/

For every ink pixel it finds the moment the pencil laid it down, so the app
can redraw the letter in exactly the same stroke order, in its own style.
Writes:
  assets/writing/<key>.png  grey = when the pixel is drawn (0-254), alpha = ink
  assets/writing/strokes.json  per letter: pen path and where strokes start
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageSequence

# Commons file name → letter.
FILES = {
    'a': 'ಅ', 'aa': 'ಆ', 'e': 'ಇ', 'ee': 'ಈ', 'u': 'ಉ', 'uu': 'ಊ', 'ru': 'ಋ',
    'ae': 'ಎ', 'aee': 'ಏ', 'ai': 'ಐ', 'o': 'ಒ', 'oo': 'ಓ', 'ou': 'ಔ', 'am': 'ಅಂ',
    'ka': 'ಕ', 'kha': 'ಖ', 'ga': 'ಗ', 'gha': 'ಘ', 'knha': 'ಙ',
    'cha': 'ಚ', 'chha': 'ಛ', 'ja': 'ಜ', 'jha': 'ಝ', 'chna': 'ಞ',
    'ta': 'ಟ', 'tta': 'ಠ', 'da': 'ಡ', 'dda': 'ಢ', 'nna': 'ಣ',
    'tha': 'ತ', 'thha': 'ಥ', 'dha': 'ದ', 'dhha': 'ಧ', 'na': 'ನ',
    'pa': 'ಪ', 'pha': 'ಫ', 'ba': 'ಬ', 'bha': 'ಭ', 'ma': 'ಮ',
    'ya': 'ಯ', 'ra': 'ರ', 'la': 'ಲ', 'va': 'ವ', 'sha': 'ಶ', 'shha': 'ಷ',
    'sa': 'ಸ', 'ha': 'ಹ', 'lla': 'ಳ',
}
SCALE = 2          # output resolution relative to the GIF
PAD = 6            # GIF pixels of margin around the letter
DARK = 110         # luminance below this is ink


def frames_of(path):
    im = Image.open(path)
    out = []
    for f in ImageSequence.Iterator(im):
        rgba = f.convert('RGBA')
        bg = Image.new('RGB', rgba.size, 'white')
        bg.paste(rgba, mask=rgba)
        out.append(np.asarray(bg).astype(np.int16))
    return out


def touches(a, b):
    """True if any pixel of mask a is within 2 px of mask b."""
    d = b.copy()
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            d |= np.roll(np.roll(b, dy, 0), dx, 1)
    return bool((a & d).any())


def process(path):
    rgb = frames_of(path)
    lum = [f @ np.array([299, 587, 114]) // 1000 for f in rgb]
    red = [((f[..., 0] > 140) & (f[..., 1] < 90) & (f[..., 2] < 90)).sum() for f in rgb]
    dark = [l < DARK for l in lum]
    # The finished letter: the last frame without the pencil in it. The
    # pencil's dark outline can linger at the edge of a frame, so keep only
    # pixels that are dark in the frames around it too.
    clean = [i for i in range(len(rgb)) if red[i] == 0]
    final = clean[-1]
    ink = dark[final].copy()
    for i in clean[-3:]:
        ink &= dark[i]

    # Frame where each ink pixel appears and then stays.
    t = np.full(ink.shape, final, np.int32)
    stay = ink.copy()
    for f in range(final - 1, -1, -1):
        stay &= dark[f]
        t[stay] = f

    # Walk the frames in order; skip frames that add nothing, keep one beat
    # for pen lifts; order the pixels within a frame from the pen's last spot.
    time = np.zeros(ink.shape, np.float64)
    ys, xs = np.nonzero(ink)
    head, starts, beat = [], [], 0.0
    prev_new, prev_c = None, None
    for f in range(0, final + 1):
        new = ink & (t == f)
        if not new.any():
            continue
        ny, nx = np.nonzero(new)
        c = (nx.mean(), ny.mean())
        lift = prev_new is None or not touches(new, prev_new)
        if lift:
            if prev_new is not None:
                beat += 0.6
            # Start from the new ink's point nearest the previous pen spot,
            # or its top-left when there is none.
            ref = prev_c if prev_c is not None else (nx.min(), ny.min())
            d0 = (nx - ref[0]) ** 2 + (ny - ref[1]) ** 2
            s = int(np.argmin(d0))
            start = (nx[s], ny[s])
            starts.append([beat, float(start[0]), float(start[1])])
        else:
            start = prev_c
        dist = np.hypot(nx - start[0], ny - start[1])
        frac = dist / (dist.max() + 1e-6) * 0.999
        time[ny, nx] = beat + frac
        head.append([beat, float(start[0]), float(start[1])])
        # Pen spot after this frame: the newest ink, farthest from the start.
        far = dist >= np.percentile(dist, 85)
        prev_c = (nx[far].mean(), ny[far].mean())
        head.append([beat + 0.999, float(prev_c[0]), float(prev_c[1])])
        prev_new = new
        beat += 1.0
    total = beat

    # Crop around the letter and scale up.
    y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, ink.shape[0])
    x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, ink.shape[1])
    w, h = (x1 - x0) * SCALE, (y1 - y0) * SCALE
    alpha = Image.fromarray(np.clip((200 - lum[final][y0:y1, x0:x1]) * 255 / 120, 0, 255)
                            .astype(np.uint8)).resize((w, h), Image.BICUBIC)
    tn = np.where(ink, time / total * 254, 255)[y0:y1, x0:x1]
    # Nearest ink time for anti-aliased edge pixels just outside the mask.
    tn_img = Image.fromarray(tn.astype(np.uint8)).resize((w, h), Image.NEAREST)
    tn_big = np.asarray(tn_img).copy()
    a_big = np.asarray(alpha).copy()
    for _ in range(2):
        hole = (tn_big == 255) & (a_big > 0)
        if not hole.any():
            break
        grown = tn_big.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sh = np.roll(np.roll(tn_big, dy, 0), dx, 1)
            grown = np.where((grown == 255) & (sh < 255), sh, grown)
        tn_big = np.where(hole, grown, tn_big)
    a_big[tn_big == 255] = 0
    tn_big[tn_big == 255] = 0
    img = Image.merge('LA', (Image.fromarray(tn_big.astype(np.uint8)), Image.fromarray(a_big)))

    def norm(p):
        return [round(p[0] / total, 4), round((p[1] - x0) / (x1 - x0), 4),
                round((p[2] - y0) / (y1 - y0), 4)]

    return img, {'w': int(w), 'h': int(h), 'starts': [norm(s) for s in starts],
                 'head': [norm(p) for p in head]}


src = sys.argv[1]
os.makedirs('assets/writing', exist_ok=True)
names = {n: f'Kannada-alphabet-{n}.gif' for n in FILES}
names['aha'] = 'Kannada-Alphabet-Aha.gif'
letters = {**FILES, 'aha': 'ಅಃ'}
data = {}
for n, ch in letters.items():
    img, d = process(os.path.join(src, names[n]))
    key = '_'.join(f'{ord(c):x}' for c in ch)
    img.save(f'assets/writing/{key}.png', optimize=True)
    data[ch] = d
    print(ch, d['w'], d['h'], 'strokes', len(d['starts']))
with open('assets/writing/strokes.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
