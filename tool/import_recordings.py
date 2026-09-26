"""Builds a native speaker's recordings (the zip from the app's recording
studio, "Send recordings") into the app for everyone.

  python3 tool/import_recordings.py akshara-aata-recordings.zip

Each <key>.m4a is trimmed, loudness-normalised and saved as
assets/audio/<key>.ogg (replacing the AI voice). The male AI clip for the
same text is removed, so the male setting also uses the human recording.
Needs ffmpeg.
"""
import os
import subprocess
import sys
import tempfile
import zipfile

zip_path = sys.argv[1]
tmp = tempfile.mkdtemp()
zipfile.ZipFile(zip_path).extractall(tmp)
n = 0
for name in sorted(os.listdir(tmp)):
    if not name.endswith('.m4a'):
        continue
    key = name[:-4]
    subprocess.run([
        'ffmpeg', '-y', '-loglevel', 'error', '-i', os.path.join(tmp, name), '-af',
        'highpass=f=70,silenceremove=start_periods=1:start_threshold=-42dB,areverse,'
        'silenceremove=start_periods=1:start_threshold=-42dB,areverse,'
        'adelay=40,apad=pad_dur=0.12,loudnorm=I=-16:TP=-1.5',
        '-ac', '1', '-ar', '22050', '-c:a', 'libvorbis', '-q:a', '4',
        f'assets/audio/{key}.ogg',
    ], check=True)
    male = f'assets/audio_m/{key}.ogg'
    if os.path.exists(male):
        os.remove(male)
    n += 1
print(f'imported {n} recordings')
