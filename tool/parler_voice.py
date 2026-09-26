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

if a.only:
    rows = [{'file': f'{i:02d}', 'kannada': t} for i, t in enumerate(a.only.split(','))]
else:
    rows = list(csv.DictReader(open('assets/audio/recording-list.csv', encoding='utf-8')))
    k, n = map(int, a.shard.split('/'))
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
    with torch.inference_mode():
        audio = model.generate(
            input_ids=desc_ids.input_ids,
            attention_mask=desc_ids.attention_mask,
            prompt_input_ids=prompt.input_ids,
            prompt_attention_mask=prompt.attention_mask,
            max_new_tokens=limit,
        )
    name = row['file'].removesuffix('.ogg')
    sf.write(os.path.join(a.out, f'{a.prefix}{name}.wav'), audio.cpu().numpy().squeeze(), rate)
    print(f'{i}/{len(rows)} {row["kannada"]}', flush=True)
