"""Builds the Wikimedia Commons Kannada writing animations (a pencil writes
each letter stroke by stroke; Gopala Krishna A, CC BY-SA 4.0, category
"Animations of Kannada letters") into assets/writing/<key>.webp.

  pip install pillow
  python3 tool/import_writing.py commons/

The last frame is held for a moment so children see the finished letter
before the animation starts again.
"""
import os
import sys

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
BOX = 280
HOLD_MS = 1500


def convert(src, dst):
    im = Image.open(src)
    frames, durations = [], []
    for f in ImageSequence.Iterator(im):
        rgba = f.convert('RGBA')
        bg = Image.new('RGB', rgba.size, 'white')
        bg.paste(rgba, mask=rgba)
        bg.thumbnail((BOX, BOX), Image.LANCZOS)
        frames.append(bg)
        durations.append(f.info.get('duration', 100) or 100)
    durations[-1] += HOLD_MS
    frames[0].save(dst, save_all=True, append_images=frames[1:], duration=durations,
                   loop=0, quality=70, method=6)


src = sys.argv[1]
os.makedirs('assets/writing', exist_ok=True)
names = {n: f'Kannada-alphabet-{n}.gif' for n in FILES}
names['aha'] = 'Kannada-Alphabet-Aha.gif'
letters = {**FILES, 'aha': 'ಅಃ'}
for n, ch in letters.items():
    key = '_'.join(f'{ord(c):x}' for c in ch)
    convert(os.path.join(src, names[n]), f'assets/writing/{key}.webp')
print('converted', len(letters))
