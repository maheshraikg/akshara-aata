"""Builds the Wikimedia Commons native-speaker letter recordings
("Pronunciation of Kannada alphabet", Surabhi18, CC BY-SA 4.0) into the app.

  python3 tool/import_commons.py commons/

Takes the commons/ folder made by tool/fetch_commons.py. Each Kn-<letter>.oga
is trimmed, loudness-normalised and saved as assets/audio/<key>.ogg
(replacing the AI voice for that letter); the male AI clip is removed so both
voice settings use the human recording. Needs ffmpeg.
"""
import json
import os
import subprocess
import sys

src = sys.argv[1]
meta = json.load(open(os.path.join(src, 'meta.json')))
n = 0
for m in meta.values():
    name = m.get('file') or ''
    if not (name.startswith('Kn-') and name.endswith('.oga')):
        continue
    if m['license'] not in ('CC BY-SA 4.0', 'CC BY 4.0', 'CC0'):
        print('skipped (licence)', name, m['license'])
        continue
    text = name[3:-4]
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
    n += 1
print(f'imported {n} recordings')
