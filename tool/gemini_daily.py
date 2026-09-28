"""Makes the online daily pack: a new short story for each of the next days,
written by Gemini and read by Sarvam's Kavya voice. Runs every day in
GitHub Actions with the developer's keys; the app downloads the pack when
it is online (lib/online.dart) and uses its built-in content when offline.
The app never calls an AI service itself.

  GEMINI_API_KEY=… SARVAM_API_KEY=… python3 tool/gemini_daily.py out/

Writes out/pack.json and out/<key>.ogg for every sentence.
"""
import datetime
import json
import os
import subprocess
import sys

import soundfile as sf

sys.path.insert(0, os.path.dirname(__file__))
from gemini_content import GEMINI, SARVAM, gemini, key, letters, sarvam  # noqa: E402

DAYS = 7

PROMPT = """You are a Kannada teacher writing for children aged 3 to 6.
Write {n} very short stories, one for each letter below. Each story has a
title and 3 or 4 short sentences (4 to 8 words each) in simple, correct,
everyday Kannada, uses the given picture word, and uses words with the
letter often. Happy and gentle: animals, family, food, play, nature. No
English words. Return JSON: a list of {{"letter", "title_kn", "title_en",
"sentences": [{{"kannada", "roman", "english"}}]}}.

{items}"""


def story_ok(s, word):
    sents = s.get('sentences') or []
    text = ' '.join(x.get('kannada', '') for x in sents)
    return (3 <= len(sents) <= 5 and word in text and s.get('title_kn')
            and all(x.get('kannada') and x.get('english') and len(x['kannada']) <= 90
                    for x in sents)
            and not any(c.isascii() and c.isalpha() for c in text))


def main():
    if not GEMINI:
        print('::warning::Add the GEMINI_API_KEY repository secret to run this.')
        return
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    all_letters = [(ch, w, wt, en) for ch, w, wt, en in letters()]
    today = datetime.date.today()
    days = []
    for d in range(DAYS):
        day = today + datetime.timedelta(days=d)
        ch, w, wt, en = all_letters[day.toordinal() % len(all_letters)]
        days.append((day.isoformat(), ch, w, wt, en))
    items = '\n'.join(f'- letter {ch}: picture word {w} ({wt}, {en})' for _, ch, w, wt, en in days)
    stories = {}
    for _ in range(3):
        for s in gemini(PROMPT.format(n=len(days), items=items)):
            for date, ch, w, _, _ in days:
                if s.get('letter', '').strip() == ch and date not in stories and story_ok(s, w):
                    stories[date] = {'letter': ch, 'title': [s['title_kn'], s.get('title_en', '')],
                                     'sentences': [[x['kannada'].strip(), x.get('roman', '').strip(),
                                                    x['english'].strip()] for x in s['sentences']]}
        if len(stories) == len(days):
            break
    print(f'{len(stories)} / {len(days)} stories', flush=True)
    if not SARVAM:
        print('::warning::No SARVAM_API_KEY: stories have no voice.')
    for date, st in stories.items():
        print(date, st['letter'], st['title'][0], flush=True)
        for kn, _, en in st['sentences']:
            print('   ', kn, '|', en, flush=True)
            if not SARVAM:
                continue
            a, sr = sarvam(kn)
            if a is None:
                continue
            wav = os.path.join(out, 'tmp.wav')
            sf.write(wav, a, sr)
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-af',
                            'loudnorm=I=-16:TP=-1.5', '-ac', '1', '-c:a', 'libvorbis',
                            '-q:a', '3', os.path.join(out, key(kn) + '.ogg')], check=True)
            os.remove(wav)
    json.dump({'made': today.isoformat(), 'stories': stories},
              open(os.path.join(out, 'pack.json'), 'w'), ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
