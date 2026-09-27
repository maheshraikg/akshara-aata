"""Builds the IndicF5 kagunita (tool/indicf5_kagunita.py) into the app.

  python3 tool/import_indicf5.py dir/     # dir holds out/report-*.json + wavs

Only syllables the recogniser heard exactly right are used: each is trimmed,
loudness-normalised and saved as assets/audio/<key>.ogg; the male AI clip is
removed. Prints the syllables that still need a good take.
"""
import glob
import json
import os
import subprocess
import sys

CONSONANTS = 'ಕಖಗಘಙಚಛಜಝಞಟಠಡಢಣತಥದಧನಪಫಬಭಮಯರಲವಶಷಸಹಳ'
SIGNS = ['ಾ', 'ಿ', 'ೀ', 'ು', 'ೂ', 'ೃ', 'ೆ', 'ೇ', 'ೈ', 'ೊ', 'ೋ', 'ೌ', 'ಂ', 'ಃ']
# The recogniser often hears a long vowel as short (ಕೀ as ಕಿ); listening
# showed those takes are right, so they count too.
SHORT = {'ೀ': 'ಿ', 'ೂ': 'ು', 'ೇ': 'ೆ', 'ೋ': 'ೊ', 'ಾ': ''}


def good(t, heard):
    return heard == t or (t[-1] in SHORT and heard == t[:-1] + SHORT[t[-1]])


# Whole-syllable native recordings (Lingua Libre) stay.
RECORDED = {'ಗೆ', 'ದಿ', 'ಮೇ', 'ಹೇ', 'ಹೂ'}


def key(t):
    return '_'.join(f'{ord(c):x}' for c in t)


src = sys.argv[1]
ok = {}
for f in glob.glob(os.path.join(src, '**', 'report-*.json'), recursive=True):
    r = json.load(open(f, encoding='utf-8'))
    for t, v in r['items'].items():
        if t in ok or not v['takes'] or 'seed' not in v['takes'][0]:
            continue
        # Exact matches first, then long vowels heard as short.
        for x in sorted(v['takes'], key=lambda x: (x['heard'] != t, x['n'])):
            wav = os.path.join(os.path.dirname(f), 'takes', f"{key(t)}_{x['n']}.wav")
            if good(t, x['heard']) and os.path.exists(wav):
                ok[t] = wav
                break
n = 0
for t, wav in sorted(ok.items()):
    if t in RECORDED:
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
    n += 1
missing = [c + s for c in CONSONANTS for s in SIGNS if c + s not in ok and c + s not in RECORDED]
print(f'imported {n}; still missing {len(missing)}:', ' '.join(missing))
if len(sys.argv) > 2:
    with open(sys.argv[2], 'w', encoding='utf-8') as f:
        f.write(' '.join(sorted(ok)) + '\n')
