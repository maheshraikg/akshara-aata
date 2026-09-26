"""Natural Kannada voice with AI4Bharat Indic Parler-TTS (Apache-2.0).

https://huggingface.co/ai4bharat/indic-parler-tts

  pip install git+https://github.com/huggingface/parler-tts.git soundfile
  python tool/parler_voice.py --speaker Anu --shard 0/6 --out out/

Reads assets/audio/recording-list.csv and writes <file>.wav for its shard.
--only takes a comma-separated list of Kannada texts (for samples).
"""
import argparse
import csv
import os

import soundfile as sf
import torch
from parler_tts import ParlerTTSForConditionalGeneration
from transformers import AutoTokenizer

p = argparse.ArgumentParser()
p.add_argument('--speaker', default='Anu')
p.add_argument('--shard', default='0/1')
p.add_argument('--only', default='')
p.add_argument('--redo', default='', help='comma-separated texts to regenerate')
p.add_argument('--out', required=True)
p.add_argument('--prefix', default='')
a = p.parse_args()

MODEL = 'ai4bharat/indic-parler-tts'
torch.manual_seed(7)
model = ParlerTTSForConditionalGeneration.from_pretrained(MODEL).eval()
tok = AutoTokenizer.from_pretrained(MODEL)
desc_tok = AutoTokenizer.from_pretrained(model.config.text_encoder._name_or_path)
rate = model.config.sampling_rate

description = (
    f'{a.speaker} speaks in a clear, warm and friendly voice at a slow pace, '
    'like a kind teacher talking to small children. The recording is of very '
    'high quality, with the speaker sounding clear and very close up, and no '
    'background noise.'
)
desc_ids = desc_tok(description, return_tensors='pt')

all_rows = list(csv.DictReader(open('assets/audio/recording-list.csv', encoding='utf-8')))
if a.redo:
    # Regenerate chosen texts, keeping their app file names.
    wanted = set(a.redo.split(','))
    rows = [r for r in all_rows if r['kannada'] in wanted]
elif a.only:
    rows = [{'file': f'{i:02d}', 'kannada': t} for i, t in enumerate(a.only.split(','))]
else:
    rows = all_rows
k, n = map(int, a.shard.split('/'))
if not a.only:
    rows = rows[k::n]

os.makedirs(a.out, exist_ok=True)
for i, row in enumerate(rows, 1):
    text = row['kannada']
    # A lone akshara is very short; a full stop makes it a complete utterance.
    if len(text) <= 3:
        text += '.'
    prompt = tok(text, return_tensors='pt')
    # Cap the length (~86 audio tokens per second) so a single letter can't
    # run on into extra sounds: ~2.3 s for one akshara, ~5 s for words.
    limit = 200 if len(row['kannada']) <= 3 else 430
    name = row['file'].removesuffix('.ogg')
    # Sampling occasionally returns an empty clip; retry with a new seed and
    # never let one bad clip end the whole run.
    wav = None
    best = None
    for attempt in range(6):
        torch.manual_seed(7 + attempt * 101)
        try:
            with torch.inference_mode():
                audio = model.generate(
                    input_ids=desc_ids.input_ids,
                    attention_mask=desc_ids.attention_mask,
                    prompt_input_ids=prompt.input_ids,
                    prompt_attention_mask=prompt.attention_mask,
                    max_new_tokens=limit,
                )
            data = audio.cpu().numpy().reshape(-1)
        except Exception as e:  # noqa: BLE001
            print(f'  attempt {attempt}: {e}', flush=True)
            continue
        # Reject empty clips and clips that ran to the length cap (usually
        # extra sounds after the letter).
        seconds = data.size / rate
        cap = limit / 86
        if 0.3 <= seconds < cap * 0.85:
            wav = data
            break
        print(f'  attempt {attempt}: {seconds:.2f}s rejected', flush=True)
        if seconds >= 0.3 and (best is None or data.size < best.size):
            best = data
    if wav is None:
        wav = best
    if wav is None:
        print(f'SKIPPED {row["kannada"]}', flush=True)
        continue
    sf.write(os.path.join(a.out, f'{a.prefix}{name}.wav'), wav, rate)
    print(f'{i}/{len(rows)} {row["kannada"]}', flush=True)
