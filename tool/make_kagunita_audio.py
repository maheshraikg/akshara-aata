"""Builds kagunita sounds (ಕಾ ಕಿ … ಳಃ) from the native speaker's letter
recordings (Wikimedia Commons, "Pronunciation of Kannada alphabet",
Surabhi18, CC BY-SA 4.0): the consonant's onset from its letter (ಕ = k + a)
is joined to the vowel letter's recording (ಈ), so ಕೀ = k + ee in the same
human voice.

  pip install numpy scipy
  python3 tool/make_kagunita_audio.py commons/ [out_dir]

The consonant is cut where its own 'a' vowel settles (voicing starts for
k, t, p…; the spectrum stops changing for g, m, l…), keeping a short piece
of the transition, and cross-faded into the vowel after the vowel's attack.
"""
import os
import subprocess
import sys

import numpy as np

SR = 22050
HOP = int(0.005 * SR)            # 5 ms frames
CONSONANTS = 'ಕಖಗಘಙಚಛಜಝಞಟಠಡಢಣತಥದಧನಪಫಬಭಮಯರಲವಶಷಸಹಳ'
SIGNS = {'ಾ': 'ಆ', 'ಿ': 'ಇ', 'ೀ': 'ಈ', 'ು': 'ಉ', 'ೂ': 'ಊ', 'ೃ': 'ಋ', 'ೆ': 'ಎ',
         'ೇ': 'ಏ', 'ೈ': 'ಐ', 'ೊ': 'ಒ', 'ೋ': 'ಓ', 'ೌ': 'ಔ', 'ಂ': 'ಅಂ', 'ಃ': 'ಅಃ'}
# Whole-syllable native recordings from Lingua Libre (import_commons.py)
# are kept.
RECORDED = {'ಗೆ', 'ದಿ', 'ಮೇ', 'ಹೇ', 'ಹೂ'}
KEEP_MS = 30      # of the consonant's own vowel transition
FADE_MS = 25
ATTACK_MS = 35    # skipped at the start of the vowel recording


def load(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', str(SR),
                          '-f', 'f32le', '-'], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).astype(np.float64)
    # Trim silence (-40 dB of the peak), keep 10 ms.
    env = np.convolve(np.abs(x), np.ones(HOP) / HOP, 'same')
    on = np.nonzero(env > env.max() * 0.01)[0]
    a, b = max(on[0] - HOP * 2, 0), min(on[-1] + HOP * 2, len(x))
    return x[a:b] / (np.abs(x[a:b]).max() + 1e-9)


def frames(x, n=512):
    idx = np.arange(0, max(len(x) - n, 1), HOP)
    win = np.hanning(n)
    return idx, np.array([x[i:i + n] * win for i in idx if i + n <= len(x)])


def voicing(fr):
    """Periodicity (0-1) of each frame from the autocorrelation peak."""
    out = []
    for f in fr:
        ac = np.correlate(f, f, 'full')[len(f) - 1:]
        if ac[0] <= 1e-9:
            out.append(0.0)
            continue
        ac /= ac[0]
        lo, hi = SR // 400, SR // 90     # 90–400 Hz pitch
        out.append(float(ac[lo:hi].max()))
    return np.array(out)


# Nasals, liquids, glides and ha: loud and steady before the vowel too.
SONORANTS = set('ಙಞಣನಮಯರಲವಳಹ')
# Voiced aspirates: keep their breathy start, the 'h' of gha.
BREATHY = set('ಘಝಢಧಭ')


def kind(c):
    return 'sonorant' if c in SONORANTS else 'breathy' if c in BREATHY else 'obstruent'


def vowel_start(x, kind='obstruent'):
    """Sample where the consonant's 'a' has settled."""
    sonorant = kind == 'sonorant'
    idx, fr = frames(x)
    if len(fr) < 4:
        return len(x) // 3
    rms = np.sqrt((fr ** 2).mean(1))
    v = voicing(fr)
    spec = np.log(np.abs(np.fft.rfft(fr, axis=1))[:, :200] + 1e-6)
    flux = np.r_[0, np.linalg.norm(np.diff(spec, axis=0), axis=1)]
    loud = rms > rms.max() * 0.5
    # Stable, voiced, loud frames: the vowel.
    flux_s = np.convolve(flux, np.ones(5) / 5, 'same')
    stable = loud & (v > 0.5) & (flux_s < np.percentile(flux_s[loud], 50))
    # The consonant's release: the biggest spectral jump between sounding
    # frames in the first 60% (n, ṅ and l are loud and steady too, so
    # steadiness alone would cut them off).
    both = np.r_[False, (rms[1:] > rms.max() * 0.15) & (rms[:-1] > rms.max() * 0.15)]
    early = np.arange(len(fr)) < len(fr) * 0.6
    cand = np.where(both & early, flux_s, 0)
    release = int(np.argmax(cand)) if sonorant and cand.max() > 0 else 0
    if kind == 'obstruent':
        # Stops, affricates and fricatives: the vowel starts where steady
        # voicing starts (after the burst, aspiration or hiss).
        on = (v > 0.6) & (rms > rms.max() * 0.3)
        run = 0
        for i, s in enumerate(on):
            run = run + 1 if s else 0
            if run >= 6:
                return int(idx[i - 5])
    # First run of 6 stable frames (30 ms) after the release.
    run = 0
    for i, s in enumerate(stable):
        run = run + 1 if s and i >= release else 0
        if run >= 6:
            return int(idx[i - 5])
    return int(idx[max(release, int(np.argmax(rms)))])


def pitch(x):
    """Median pitch (Hz) of the clearly voiced frames, or 0."""
    _, fr = frames(x, 1024)
    out = []
    for f in fr:
        ac = np.correlate(f, f, 'full')[len(f) - 1:]
        if ac[0] <= 1e-9:
            continue
        ac /= ac[0]
        lo, hi = SR // 400, SR // 90
        i = int(np.argmax(ac[lo:hi])) + lo
        if ac[i] > 0.6:
            out.append(SR / i)
    return float(np.median(out)) if out else 0.0


def shift(x, ratio):
    """Pitch-shift keeping the formants (so the vowel still sounds the same)."""
    if abs(ratio - 1) < 0.02:
        return x
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-f', 'f64le', '-ar', str(SR), '-ac', '1',
                          '-i', '-', '-af', f'rubberband=pitch={ratio:.4f}:formant=preserved',
                          '-f', 'f64le', '-'], input=x.tobytes(), capture_output=True,
                         check=True).stdout
    return np.frombuffer(raw, np.float64).copy()


def join(cons, vowel, k):
    start = vowel_start(cons, k)
    # Say the vowel at the pitch the speaker used for this consonant.
    pc, pv = pitch(cons[start:start + int(0.15 * SR)]), pitch(vowel)
    if pc and pv:
        vowel = shift(vowel, float(np.clip(pc / pv, 0.7, 1.4)))
    cut = start + int(KEEP_MS / 1000 * SR)
    fade = int(FADE_MS / 1000 * SR)
    head = cons[:cut + fade].copy()
    tail = vowel[int(ATTACK_MS / 1000 * SR):].copy()
    # Match loudness around the join.
    a = np.sqrt((head[-fade * 3:] ** 2).mean()) + 1e-9
    b = np.sqrt((tail[:fade * 3] ** 2).mean()) + 1e-9
    tail *= a / b
    ramp = np.linspace(0, 1, fade)
    mid = head[-fade:] * (1 - ramp) + tail[:fade] * ramp
    y = np.concatenate([head[:-fade], mid, tail[fade:]])
    return y / (np.abs(y).max() + 1e-9) * 0.95


def save(y, path):
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f64le', '-ar', str(SR), '-ac', '1',
                    '-i', '-', '-af', 'highpass=f=70,adelay=40,apad=pad_dur=0.12,'
                    'loudnorm=I=-16:TP=-1.5', '-ar', '22050', '-c:a', 'libvorbis', '-q:a', '4',
                    path], input=y.astype(np.float64).tobytes(), check=True)


def key(t):
    return '_'.join(f'{ord(c):x}' for c in t)


if __name__ == '__main__':
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else 'assets/audio'
    only = os.environ.get('ONLY', CONSONANTS)
    vowels = {v: load(os.path.join(src, f'Kn-{v}.oga')) for v in set(SIGNS.values())}
    for c in only:
        cons = load(os.path.join(src, f'Kn-{c}.oga'))
        for s, v in SIGNS.items():
            if c + s in RECORDED and out == 'assets/audio':
                continue
            save(join(cons, vowels[v], kind(c)), os.path.join(out, key(c + s) + '.ogg'))
            male = os.path.join('assets/audio_m', key(c + s) + '.ogg')
            if out == 'assets/audio' and os.path.exists(male):
                os.remove(male)
        print(c, 'cut at', round(vowel_start(cons, kind(c)) / SR * 1000), 'ms of',
              round(len(cons) / SR * 1000), flush=True)
