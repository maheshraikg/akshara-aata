"""Generates assets/audio/*.ogg with a natural Kannada neural voice.

Voice: AI4Bharat Indic-TTS Kannada FastPitch + HiFi-GAN (MIT license),
trained on native-speaker studio recordings (IIT Madras IndicTTS data).
https://github.com/AI4Bharat/Indic-TTS

Setup (once, ~10 GB with PyTorch):
  python3 -m venv venv && venv/bin/pip install TTS==0.22.0
  curl -L -o kn.zip https://github.com/AI4Bharat/Indic-TTS/releases/download/v1-checkpoints-release/kn.zip
  unzip kn.zip

Run from akshara_aata/:
  /path/venv/bin/python tool/generate_voice.py --model /path/kn [--speaker female|male]

Reads assets/audio/recording-list.csv (written by tool/generate_audio.dart) and
overwrites every listed .ogg. Needs ffmpeg.
"""
import argparse
import csv
import json
import os
import subprocess
import tempfile

from TTS.utils.synthesizer import Synthesizer

p = argparse.ArgumentParser()
p.add_argument('--model', required=True, help='unzipped kn/ folder')
p.add_argument('--speaker', default='female')
p.add_argument('--out', default='assets/audio')
a = p.parse_args()

fp = os.path.join(a.model, 'fastpitch')
speakers = os.path.join(fp, 'speakers.pth')
cfg = json.load(open(os.path.join(fp, 'config.json')))
cfg['speakers_file'] = speakers
cfg.setdefault('model_args', {})['speakers_file'] = speakers
local_cfg = os.path.join(tempfile.gettempdir(), 'kn_fastpitch_config.json')
json.dump(cfg, open(local_cfg, 'w'))

synth = Synthesizer(
    tts_checkpoint=os.path.join(fp, 'best_model.pth'),
    tts_config_path=local_cfg,
    tts_speakers_file=speakers,
    vocoder_checkpoint=os.path.join(a.model, 'hifigan', 'best_model.pth'),
    vocoder_config=os.path.join(a.model, 'hifigan', 'config.json'),
    use_cuda=False,
)

rows = list(csv.DictReader(open(os.path.join(a.out, 'recording-list.csv'), encoding='utf-8')))
for i, row in enumerate(rows, 1):
    text = row['kannada']
    # A single akshara is too short for the model; a full stop makes it a
    # complete utterance and gives it a natural falling tone.
    single = len(text) <= 3
    if single:
        text += '.'
    wav = os.path.join(tempfile.gettempdir(), 'akshara_voice.wav')
    synth.save_wav(synth.tts(text, speaker_name=a.speaker), wav)
    out = os.path.join(a.out, row['file'])
    subprocess.run([
        'ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-af',
        # Single letters play a little slower (pitch kept) for small children.
        ('atempo=0.85,' if single else '') +
        'silenceremove=start_periods=1:start_threshold=-50dB,areverse,'
        'silenceremove=start_periods=1:start_threshold=-50dB,areverse,'
        'adelay=40,apad=pad_dur=0.1,loudnorm=I=-16:TP=-1.5',
        '-ac', '1', '-ar', '22050', '-c:a', 'libvorbis', '-q:a', '4', out,
    ], check=True)
    if i % 50 == 0:
        print(f'{i}/{len(rows)}', flush=True)
print(f'done: {len(rows)} files')
