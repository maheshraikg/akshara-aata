"""Builds Sarvam (or Gemini) kagunita takes that the recogniser heard exactly
right into the app.

  python3 tool/import_sarvam.py dir/ [speaker …]   # dir holds out/report-*.json
  python3 tool/import_sarvam.py --first dir/        # also the rest (see below)

With --first, a syllable with no exact match gets its first Kavya take: the
recogniser rejected those, but the user listened to a sample of them and
found them all correct.

Only takes by the listed speakers are used (default: kavya, the voice the
user approved). Each is trimmed, loudness-normalised and saved as
assets/audio/<key>.ogg; the male AI clip is removed. Prints what is left.
"""
import glob
import json
import os
import subprocess
import sys

RECORDED = {'ಗೆ', 'ದಿ', 'ಮೇ', 'ಹೇ', 'ಹೂ'}


def key(t):
    return '_'.join(f'{ord(c):x}' for c in t)


args = sys.argv[1:]
first = '--first' in args
args = [a for a in args if a != '--first']
src = args[0]
speakers = set(args[1:]) or {'kavya'}
done, left = [], []
for f in glob.glob(os.path.join(src, '**', 'report-*.json'), recursive=True):
    for t, v in json.load(open(f, encoding='utf-8'))['items'].items():
        take = next((x for x in v['takes'] if x['heard'] == t and x['speaker'] in speakers), None)
        if take is None and first:
            take = next((x for x in v['takes'] if x['speaker'] == 'kavya'), None)
        wav = os.path.join(os.path.dirname(f), 'takes', f"{key(t)}_{take['n']}.wav") if take else ''
        if t in RECORDED or not take or not os.path.exists(wav):
            left.append(t)
            continue
        subprocess.run([
            'ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-af',
            'highpass=f=70,silenceremove=start_periods=1:start_threshold=-40dB,areverse,'
            'silenceremove=start_periods=1:start_threshold=-40dB,areverse,'
            'adelay=40,apad=pad_dur=0.12,loudnorm=I=-16:TP=-1.5',
            '-ac', '1', '-ar', '22050', '-c:a', 'libvorbis', '-q:a', '4',
            f'assets/audio/{key(t)}.ogg'], check=True)
        male = f'assets/audio_m/{key(t)}.ogg'
        if os.path.exists(male):
            os.remove(male)
        done.append(t)
print(f'imported {len(done)}; not imported {len(left)}:', ' '.join(sorted(left)))
