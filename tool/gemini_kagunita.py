"""Speaks kagunita (ಕಾ … ಳಃ) with Google Gemini text-to-speech, told to say
each syllable slowly with its vowel length, and keeps only takes that
AI4Bharat's Kannada recogniser (IndicConformer) hears exactly right.

  GEMINI_API_KEY=… HF_TOKEN=… ONLY="ಕೀ ಕೂ" python3 tool/gemini_kagunita.py out/

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
KEY = os.environ.get('GEMINI_API_KEY', '')
MODELS = ['gemini-2.5-flash-preview-tts', 'gemini-2.5-pro-preview-tts', 'gemini-2.5-flash-tts']
LONG = {'ಾ': 'ಆ', 'ೀ': 'ಈ', 'ೂ': 'ಊ', 'ೇ': 'ಏ', 'ೋ': 'ಓ'}


def key(t):
    return '_'.join(f'{ord(c):x}' for c in t)


def clean(t):
    return ''.join(ch for ch in t if '\u0c80' <= ch <= '\u0cff')


def prompt(t, style):
    hint = f' The vowel is the long {LONG[t[-1]]}, so hold it long.' if t[-1] in LONG else ''
    if style == 0:
        return (f'Read this single Kannada syllable aloud once, slowly and clearly, like a '
                f'Kannada teacher saying it to a small child. Say only the syllable.{hint}\n{t}')
    return (f'ಈ ಕನ್ನಡ ಅಕ್ಷರವನ್ನು ಒಮ್ಮೆ ನಿಧಾನವಾಗಿ, ಸ್ಪಷ್ಟವಾಗಿ ಹೇಳಿ, ಬೇರೇನೂ ಹೇಳಬೇಡಿ.{hint}\n{t}')


# (voice, prompt style), tried in order until one is heard right.
TAKES = [(v, st) for v in (os.environ.get('VOICE', 'Kore'), 'Leda', 'Aoede') for st in (0, 1, 0)]
_model = [None]


def tts(text, voice):
    body = {'contents': [{'parts': [{'text': text}]}],
            'generationConfig': {'responseModalities': ['AUDIO'],
                                 'speechConfig': {'voiceConfig': {
                                     'prebuiltVoiceConfig': {'voiceName': voice}}}}}
    for model in ([_model[0]] if _model[0] else MODELS):
        url = f'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent'
        req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                     headers={'x-goog-api-key': KEY,
                                              'Content-Type': 'application/json'})
        for n in range(6):
            try:
                with urllib.request.urlopen(req, timeout=120) as r:
                    data = json.loads(r.read())
                part = data['candidates'][0]['content']['parts'][0]['inlineData']
                pcm = np.frombuffer(base64.b64decode(part['data']), np.int16)
                _model[0] = model
                return pcm.astype(np.float32) / 32768.0, 24000
            except urllib.error.HTTPError as e:
                msg = e.read().decode(errors='replace')[:300]
                if e.code == 404:
                    print('model not available:', model, flush=True)
                    break
                if e.code == 429 or e.code >= 500:
                    time.sleep(10 * (n + 1))
                    continue
                print('gemini error', e.code, msg, flush=True)
                return None, 0
            except (KeyError, IndexError) as e:
                print('no audio in reply', e, flush=True)
                return None, 0
    return None, 0


asr = None


def load_asr():
    global asr
    time.sleep(40 * int(os.environ.get('SHARD', 0)))   # shards share the HF rate limit
    for n in range(6):
        try:
            from huggingface_hub import snapshot_download
            # Fetch every file first: the model's own loader expects the
            # assets folder to be there already.
            snapshot_download('ai4bharat/indic-conformer-600m-multilingual')
            asr = AutoModel.from_pretrained('ai4bharat/indic-conformer-600m-multilingual',
                                            trust_remote_code=True)
            return
        except Exception as e:  # noqa: BLE001
            # Rate limits show up wrapped in other errors: wait and retry.
            if n == 5:
                raise
            print('download failed, waiting:', str(e)[:120], flush=True)
            time.sleep(90 * (n + 1))


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
        print('::warning::Add the GEMINI_API_KEY repository secret to run this.')
        sys.exit(0)
    load_asr()
    out = sys.argv[1]
    os.makedirs(os.path.join(out, 'takes'), exist_ok=True)
    shard, shards = int(os.environ.get('SHARD', 0)), int(os.environ.get('SHARDS', 1))
    only = os.environ.get('ONLY', '').split()
    texts = only or [c + s for c in CONSONANTS for s in SIGNS if c + s not in RECORDED]
    texts = texts[shard::shards]
    report = {'items': {}}
    for t in texts:
        takes = []
        for n, (voice, style) in enumerate(TAKES):
            a, sr = tts(prompt(t, style), voice)
            if a is None or not len(a):
                continue
            a = trim(a, sr)
            got = hear(a, sr)
            sf.write(os.path.join(out, 'takes', f'{key(t)}_{n}.wav'), a, sr)
            takes.append({'n': n, 'model': _model[0], 'speaker': voice, 'style': style,
                          'heard': got, 'secs': round(len(a) / sr, 2)})
            print(t, n, voice, style, repr(got), round(len(a) / sr, 2), flush=True)
            if got == t:
                sf.write(os.path.join(out, f'{key(t)}.wav'), a, sr)
                break
        report['items'][t] = {'ok': any(x['heard'] == t for x in takes), 'takes': takes}
        with open(os.path.join(out, f'report-{shard}.json'), 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=1)
    ok = sum(v['ok'] for v in report['items'].values())
    print(f'{ok}/{len(texts)} heard exactly right')
