"""Speaks kagunita (ಕಾ … ಳಃ) with Sarvam AI's Bulbul Kannada voice and keeps
only takes that AI4Bharat's Kannada recogniser (IndicConformer) hears
exactly right, long vowels included.

  SARVAM_API_KEY=… HF_TOKEN=… SHARD=0 SHARDS=4 python3 tool/sarvam_kagunita.py out/

Writes out/<key>.wav (the chosen take), out/takes/, out/report-<shard>.json.
"""
import base64
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request

import numpy as np
import soundfile as sf
import torch
import torchaudio
from transformers import AutoModel

CONSONANTS = 'ಕಖಗಘಙಚಛಜಝಞಟಠಡಢಣತಥದಧನಪಫಬಭಮಯರಲವಶಷಸಹಳ'
SIGNS = ['ಾ', 'ಿ', 'ೀ', 'ು', 'ೂ', 'ೃ', 'ೆ', 'ೇ', 'ೈ', 'ೊ', 'ೋ', 'ೌ', 'ಂ', 'ಃ']
RECORDED = {'ಗೆ', 'ದಿ', 'ಮೇ', 'ಹೇ', 'ಹೂ'}
KEY = os.environ.get('SARVAM_API_KEY', '')
# (model, speaker, pace, text form): tried in order until one is heard right.
TAKES = [(m, sp, pace, form) for m, sp in (('bulbul:v3', os.environ.get('SPEAKER', 'kavya')),
                                            ('bulbul:v2', 'anushka'))
         for pace, form in ((0.75, '{t}'), (0.75, '{t}.'), (0.9, '{t}'), (0.65, '{t}.'))]


def key(t):
    return '_'.join(f'{ord(c):x}' for c in t)


def clean(t):
    return ''.join(ch for ch in t if 'ಀ' <= ch <= '೿')


def tts(text, model, speaker, pace):
    body = {'text': text, 'target_language_code': 'kn-IN', 'speaker': speaker,
            'model': model, 'pace': pace, 'speech_sample_rate': 24000}
    req = urllib.request.Request('https://api.sarvam.ai/text-to-speech',
                                 data=json.dumps(body).encode(),
                                 headers={'api-subscription-key': KEY,
                                          'Content-Type': 'application/json'})
    for n in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                data = json.loads(r.read())
            a, sr = sf.read(io.BytesIO(base64.b64decode(data['audios'][0])))
            return (a.mean(1) if a.ndim > 1 else a).astype(np.float32), sr
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors='replace')[:300]
            if e.code == 429 or e.code >= 500:
                time.sleep(5 * (n + 1))
                continue
            print('sarvam error', e.code, msg, flush=True)
            return None, 0
    return None, 0


asr = AutoModel.from_pretrained('ai4bharat/indic-conformer-600m-multilingual',
                                trust_remote_code=True)


def hear(a, sr):
    w = torch.tensor(a, dtype=torch.float32).reshape(1, -1)
    if sr != 16000:
        w = torchaudio.transforms.Resample(sr, 16000)(w)
    pad = torch.zeros(1, 4000)
    return clean(str(asr(torch.cat([pad, w, pad], 1), 'kn', 'ctc')))


def trim(a, sr):
    env = np.convolve(np.abs(a), np.ones(240) / 240, 'same')
    on = np.nonzero(env > env.max() * 0.02)[0]
    return a[max(on[0] - sr // 50, 0):on[-1] + sr // 20] if len(on) else a


if __name__ == '__main__':
    if not KEY:
        print('::warning::Add the SARVAM_API_KEY repository secret to run this.')
        sys.exit(0)
    out = sys.argv[1]
    os.makedirs(os.path.join(out, 'takes'), exist_ok=True)
    shard, shards = int(os.environ.get('SHARD', 0)), int(os.environ.get('SHARDS', 1))
    only = os.environ.get('ONLY', '').split()
    texts = only or [c + s for c in CONSONANTS for s in SIGNS if c + s not in RECORDED]
    texts = texts[shard::shards]
    report = {'items': {}}
    for t in texts:
        takes = []
        for n, (model, speaker, pace, form) in enumerate(TAKES):
            a, sr = tts(form.format(t=t), model, speaker, pace)
            if a is None:
                continue
            a = trim(a, sr)
            got = hear(a, sr)
            sf.write(os.path.join(out, 'takes', f'{key(t)}_{n}.wav'), a, sr)
            takes.append({'n': n, 'model': model, 'speaker': speaker, 'pace': pace,
                          'form': form, 'heard': got, 'secs': round(len(a) / sr, 2)})
            print(t, n, model, speaker, pace, repr(got), flush=True)
            if got == t:
                sf.write(os.path.join(out, f'{key(t)}.wav'), a, sr)
                break
        report['items'][t] = {'ok': any(x['heard'] == t for x in takes), 'takes': takes}
        with open(os.path.join(out, f'report-{shard}.json'), 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=1)
    ok = sum(v['ok'] for v in report['items'].values())
    print(f'{ok}/{len(texts)} heard exactly right')
