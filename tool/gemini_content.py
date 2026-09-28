"""Writes a short Kannada line for every letter with Google Gemini, and
speaks each line with Sarvam's Kavya voice. Runs in GitHub Actions with the
developer's keys, never in the app: the app only ships the finished lines
and recordings (Gemini's terms don't allow calling it from apps for
children).

  GEMINI_API_KEY=… SARVAM_API_KEY=… python3 tool/gemini_content.py out/

Writes out/lines.json ({letter: [kannada, roman, english]}) and
out/<key>.wav for each line. Import with tool/import_lines.py after a
Kannada speaker has read them.
"""
import base64
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(__file__))
GEMINI = os.environ.get('GEMINI_API_KEY', '')
SARVAM = os.environ.get('SARVAM_API_KEY', '')
MODELS = ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash', 'gemini-flash-latest']


def key(t):
    return '_'.join(f'{ord(c):x}' for c in t)


def letters():
    """(letter, word, romanised word, English) from lib/data.dart."""
    src = open('lib/data.dart', encoding='utf-8').read()
    body = src[src.index('const letters'):src.index('const vargas')]
    out = []
    for m in re.finditer(r"Letter\(\s*'([^']+)',\s*'[^']*',\s*Group\.\w+,\s*'[^']*',"
                         r"\s*'([^']+)',\s*'([^']+)',\s*'[^']+',\s*'([^']+)'", body):
        out.append(m.groups())
    assert len(out) == 49, len(out)
    return out


PROMPT = """You are a Kannada teacher writing for children aged 3 to 6.
For each letter below, write ONE short, simple, correct Kannada sentence
(4 to 8 words) that a small child enjoys hearing, using the given picture
word exactly as written, and repeating the letter's sound if you can. Use
everyday spoken Kannada with correct spelling and grammar, no English words,
nothing scary or sad, and end with a full stop or exclamation mark.
Return JSON: a list of objects {{"letter", "kannada", "roman", "english"}}
where roman is a simple romanisation and english the meaning.

{items}"""


def gemini(prompt):
    body = {'contents': [{'parts': [{'text': prompt}]}],
            'generationConfig': {'responseMimeType': 'application/json',
                                 'temperature': 0.6}}
    for model in MODELS:
        url = f'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent'
        req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                     headers={'x-goog-api-key': GEMINI,
                                              'Content-Type': 'application/json'})
        for n in range(5):
            try:
                with urllib.request.urlopen(req, timeout=180) as r:
                    data = json.loads(r.read())
                text = data['candidates'][0]['content']['parts'][0]['text']
                print('model', model, flush=True)
                return json.loads(text)
            except urllib.error.HTTPError as e:
                msg = e.read().decode(errors='replace')[:300]
                print('gemini', model, e.code, msg.replace('\n', ' ')[:200], flush=True)
                if e.code in (404, 400, 403):
                    break
                time.sleep(30 * (n + 1))
            except (KeyError, IndexError, ValueError) as e:
                print('bad reply', model, e, flush=True)
                time.sleep(10)
    return []


def good(line, word):
    kn = line.get('kannada', '')
    return (word in kn and 8 <= len(kn) <= 90
            and not re.search('[A-Za-z]', kn)
            and line.get('roman') and line.get('english'))


def sarvam(text):
    body = {'text': text, 'target_language_code': 'kn-IN', 'speaker': 'kavya',
            'model': 'bulbul:v3', 'pace': 0.9, 'speech_sample_rate': 24000}
    req = urllib.request.Request('https://api.sarvam.ai/text-to-speech',
                                 data=json.dumps(body).encode(),
                                 headers={'api-subscription-key': SARVAM,
                                          'Content-Type': 'application/json'})
    for n in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                data = json.loads(r.read())
            a, sr = sf.read(io.BytesIO(base64.b64decode(data['audios'][0])))
            return (a.mean(1) if a.ndim > 1 else a).astype(np.float32), sr
        except urllib.error.HTTPError as e:
            print('sarvam', e.code, e.read().decode(errors='replace')[:200], flush=True)
            if e.code == 429 or e.code >= 500:
                time.sleep(5 * (n + 1))
                continue
            return None, 0
    return None, 0


def main():
    if not GEMINI:
        print('::warning::Add the GEMINI_API_KEY repository secret to run this.')
        return
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    todo = {ch: (w, wt, en) for ch, w, wt, en in letters()}
    lines = {}
    for attempt in range(4):
        left = [ch for ch in todo if ch not in lines]
        if not left:
            break
        for i in range(0, len(left), 25):
            batch = left[i:i + 25]
            items = '\n'.join(f'- letter {ch}: picture word {todo[ch][0]} '
                              f'({todo[ch][1]}, {todo[ch][2]})' for ch in batch)
            for line in gemini(PROMPT.format(items=items)):
                ch = line.get('letter', '').strip()
                if ch in batch and ch not in lines and good(line, todo[ch][0]):
                    lines[ch] = [line['kannada'].strip(), line['roman'].strip(),
                                 line['english'].strip()]
        print(f'after try {attempt + 1}: {len(lines)} / {len(todo)} lines', flush=True)
    json.dump(lines, open(os.path.join(out, 'lines.json'), 'w'), ensure_ascii=False, indent=1)
    for ch, (kn, roman, en) in lines.items():
        print(ch, kn, '|', en, flush=True)
    if not SARVAM:
        print('::warning::No SARVAM_API_KEY: lines written without voice.')
        return
    for ch, (kn, _, _) in lines.items():
        a, sr = sarvam(kn)
        if a is not None:
            sf.write(os.path.join(out, key(kn) + '.wav'), a, sr)
    print('spoken', len([f for f in os.listdir(out) if f.endswith('.wav')]), flush=True)


if __name__ == '__main__':
    main()
