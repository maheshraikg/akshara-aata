"""Speaks kagunita (ಕಾ … ಳಃ) with AI4Bharat IndicF5 (MIT) and keeps only
takes that AI4Bharat's Kannada speech recogniser (IndicConformer, MIT)
hears as the right syllable.

  HF_TOKEN=… SHARD=0 SHARDS=1 TEXTS="ಕ ಖ" python3 tool/indicf5_kagunita.py out/

For every syllable several takes are made (different seeds, with and
without a full stop). Each take is transcribed; the take whose transcript
matches the syllable (or is closest) is saved as out/<key>.wav, all takes
as out/takes/<key>_<n>.wav, and out/report-<shard>.json lists them.
The voice is IndicF5's Kannada reference speaker (prompts/KAN_F_HAPPY_00001.wav).
"""
import json
import os
import sys
import time

import numpy as np
import soundfile as sf
import torch
import torchaudio
from transformers import AutoModel

# Parallel shards share the Hugging Face rate limit: start them apart.
time.sleep(45 * int(os.environ.get('SHARD', 0)))


def retry(fn, *a, **k):
    for n in range(6):
        try:
            return fn(*a, **k)
        except Exception as e:  # noqa: BLE001
            if '429' not in str(e) or n == 5:
                raise
            print('rate limited, waiting', flush=True)
            time.sleep(90 * (n + 1))


def offline():
    """Models are cached now: stop asking Hugging Face on every call."""
    os.environ['HF_HUB_OFFLINE'] = '1'
    os.environ['TRANSFORMERS_OFFLINE'] = '1'
    import huggingface_hub.constants as hc
    hc.HF_HUB_OFFLINE = True

CONSONANTS = 'ಕಖಗಘಙಚಛಜಝಞಟಠಡಢಣತಥದಧನಪಫಬಭಮಯರಲವಶಷಸಹಳ'
SIGNS = ['ಾ', 'ಿ', 'ೀ', 'ು', 'ೂ', 'ೃ', 'ೆ', 'ೇ', 'ೈ', 'ೊ', 'ೋ', 'ೌ', 'ಂ', 'ಃ']
REF = os.environ.get('REF', 'KAN_F_HAPPY_00001.wav')
TAKES = [('', 1), ('', 2), ('.', 3), ('.', 4), ('', 5), ('.', 6)]


def key(t):
    return '_'.join(f'{ord(c):x}' for c in t)


def clean(t):
    return ''.join(ch for ch in t if 'ಀ' <= ch <= '೿')


def dist(a, b):
    d = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        prev, d[0] = d[0], i
        for j, cb in enumerate(b, 1):
            prev, d[j] = d[j], min(d[j] + 1, d[j - 1] + 1, prev + (ca != cb))
    return d[-1]


# IndicConformer is gated on Hugging Face; without access, use the open
# Vakyansh Kannada wav2vec2 model.
try:
    _conf = retry(AutoModel.from_pretrained, 'ai4bharat/indic-conformer-600m-multilingual',
                  trust_remote_code=True)
    ASR = 'ai4bharat/indic-conformer-600m-multilingual'

    def _run(w):
        return str(_conf(w, 'kn', 'ctc'))
except Exception as e:  # noqa: BLE001
    print('IndicConformer not available:', str(e)[:120], flush=True)
    from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor
    ASR = os.environ.get('ASR', 'Harveenchadha/vakyansh-wav2vec2-kannada-knm-560')
    _proc = retry(Wav2Vec2Processor.from_pretrained, ASR)
    _w2v = retry(Wav2Vec2ForCTC.from_pretrained, ASR).eval()

    def _run(w):
        inp = _proc(w[0].numpy(), sampling_rate=16000, return_tensors='pt')
        with torch.no_grad():
            ids = _w2v(inp.input_values).logits.argmax(-1)
        return _proc.batch_decode(ids)[0]
print('recogniser:', ASR, flush=True)


def hear(wav, sr):
    w = torch.tensor(wav, dtype=torch.float32).reshape(1, -1)
    if sr != 16000:
        w = torchaudio.transforms.Resample(sr, 16000)(w)
    # Pad: the recogniser needs some context around a short syllable.
    pad = torch.zeros(1, 4000)
    return _run(torch.cat([pad, w, pad], 1)).strip()


def trim(a, sr):
    env = np.convolve(np.abs(a), np.ones(240) / 240, 'same')
    on = np.nonzero(env > env.max() * 0.02)[0]
    if not len(on):
        return a
    return a[max(on[0] - sr // 50, 0):on[-1] + sr // 20]


if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(os.path.join(out, 'takes'), exist_ok=True)
    shard, shards = int(os.environ.get('SHARD', 0)), int(os.environ.get('SHARDS', 1))
    cons = (os.environ.get('TEXTS') or CONSONANTS).replace(' ', '')
    texts = [c + s for c in cons for s in SIGNS][shard::shards]

    ref_wav, ref_sr = sf.read(REF)
    ref_text = os.environ.get('REF_TEXT') or hear(ref_wav if ref_wav.ndim == 1
                                                  else ref_wav.mean(1), ref_sr)
    print('reference text:', ref_text, flush=True)
    try:
        tts = retry(AutoModel.from_pretrained, 'ai4bharat/IndicF5', trust_remote_code=True)
    except OSError as e:
        if 'gated' not in str(e):
            raise
        # Needs one click by the Hugging Face account behind HF_TOKEN.
        print('::warning::ai4bharat/IndicF5 is gated: request access at '
              'https://huggingface.co/ai4bharat/IndicF5 with the HF_TOKEN account')
        sys.exit(0)

    offline()
    report = {'ref_text': ref_text, 'asr': ASR, 'items': {}}
    for t in texts:
        takes = []
        for n, (end, seed) in enumerate(TAKES):
            torch.manual_seed(seed)
            t0 = time.time()
            a = tts(t + end, ref_audio_path=REF, ref_text=ref_text)
            print(f'  took {time.time() - t0:.0f}s', flush=True)
            a = np.asarray(a)
            if a.dtype == np.int16:
                a = a.astype(np.float32) / 32768.0
            a = trim(a.astype(np.float32), 24000)
            got = clean(hear(a, 24000))
            d = dist(got, t)
            sf.write(os.path.join(out, 'takes', f'{key(t)}_{n}.wav'), a, 24000)
            takes.append({'n': n, 'heard': got, 'dist': d, 'secs': round(len(a) / 24000, 2)})
            print(t, n, repr(got), d, flush=True)
            if d == 0 and sum(x['dist'] == 0 for x in takes) >= 2:
                break
        best = min(takes, key=lambda x: (x['dist'], x['n']))
        a, _ = sf.read(os.path.join(out, 'takes', f"{key(t)}_{best['n']}.wav"))
        sf.write(os.path.join(out, f'{key(t)}.wav'), a, 24000)
        report['items'][t] = {'best': best['n'], 'ok': best['dist'] == 0, 'takes': takes}
        # Save progress after every syllable so partial results can be used.
        with open(os.path.join(out, f'report-{shard}.json'), 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=1)
        if os.environ.get('PROGRESS_CMD'):
            os.system(os.environ['PROGRESS_CMD'])
    with open(os.path.join(out, f'report-{shard}.json'), 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=1)
    ok = sum(v['ok'] for v in report['items'].values())
    print(f'{ok}/{len(texts)} heard exactly right')
