"""Builds native-speaker recordings from Wikimedia Commons into the app.

  python3 tool/import_commons.py commons/

Takes a commons/ folder made by tool/fetch_commons.py:
- "Pronunciation of Kannada alphabet" (Kn-<letter>.oga, Surabhi18) for the
  49 letters;
- "Lingua Libre pronunciation-kan" (LL-Q33673 (kan)-<speaker>-<word>.wav)
  for words and syllables. The 49 letters stay with the alphabet speaker, and
  when several people recorded a word, PREFERRED speakers win.
Each file is trimmed, loudness-normalised and saved as assets/audio/<key>.ogg
(replacing the AI voice); the male AI clip is removed so both voice settings
use the human recording. Needs ffmpeg.
"""
import json
import os
import subprocess
import sys

FREE = ('CC BY-SA 4.0', 'CC BY-SA 3.0', 'CC BY 4.0', 'CC BY 3.0', 'CC0')
PREFERRED = ['AnshulBhagwat', 'Brusquedandelion', 'Shilpa Bhat N H', 'Ashoka KG',
             'Shruthi D S']


def text_and_speaker(name):
    base = os.path.splitext(name)[0]
    if base.startswith('Kn-'):
        return base[3:], 'Surabhi18'
    if base.startswith('LL-'):
        # LL-Q33673 (kan)-<speaker>-<word>; the speaker may contain '-'.
        speaker, word = base.split(')-', 1)[1].rsplit('-', 1)
        return word.strip(), speaker
    return None, None


src = sys.argv[1]
meta = json.load(open(os.path.join(src, 'meta.json')))
chosen = {}
for m in meta.values():
    name = m.get('file') or ''
    text, speaker = text_and_speaker(name)
    if not text:
        continue
    if m['license'] not in FREE:
        print('skipped (licence)', name, m['license'])
        continue
    if speaker != 'Surabhi18' and (len(text) == 1 or text in ('ಅಂ', 'ಅಃ')):
        continue  # the 49 letters keep the alphabet speaker
    rank = -1 if speaker == 'Surabhi18' else (
        PREFERRED.index(speaker) if speaker in PREFERRED else len(PREFERRED))
    if text not in chosen or rank < chosen[text][0]:
        chosen[text] = (rank, name)

with open('assets/audio/recording-list.csv', encoding='utf-8') as f:
    texts = {line.split(',')[1] for line in f.read().splitlines()[1:] if line}

n = 0
for text, (_, name) in sorted(chosen.items()):
    if text not in texts:
        continue
    key = '_'.join(f'{ord(c):x}' for c in text)
    subprocess.run([
        'ffmpeg', '-y', '-loglevel', 'error', '-i', os.path.join(src, name), '-af',
        'highpass=f=70,silenceremove=start_periods=1:start_threshold=-45dB,areverse,'
        'silenceremove=start_periods=1:start_threshold=-45dB,areverse,'
        'adelay=40,apad=pad_dur=0.12,loudnorm=I=-16:TP=-1.5',
        '-ac', '1', '-ar', '22050', '-c:a', 'libvorbis', '-q:a', '4',
        f'assets/audio/{key}.ogg',
    ], check=True)
    male = f'assets/audio_m/{key}.ogg'
    if os.path.exists(male):
        os.remove(male)
    print(text, '←', name)
    n += 1
print(f'imported {n} recordings')
