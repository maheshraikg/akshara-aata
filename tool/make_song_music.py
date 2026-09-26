"""Synthesises the alphabet song's backing loop (assets/music/song_loop.ogg).

A bright 120 BPM I–V–vi–IV progression in C: plucked bass, soft chord pad,
bell melody and a light shaker, 8 bars (16 s) that loop seamlessly.
The app sings one letter every beat-pair (1 s) over it. Needs ffmpeg.
"""
import math
import struct
import subprocess
import wave

RATE = 22050
BPM = 120
BEAT = 60 / BPM
BARS = 8
LEN = int(RATE * BEAT * 4 * BARS)
buf = [0.0] * LEN


def note_hz(n):
    return 440 * 2 ** ((n - 69) / 12)


def add(start, dur, hz, vol, kind):
    s0 = int(start * RATE)
    n = int(dur * RATE)
    for i in range(n):
        if s0 + i >= LEN:
            break
        t = i / RATE
        if kind == 'bell':
            env = math.exp(-5 * t)
            v = math.sin(2 * math.pi * hz * t) + .35 * math.sin(2 * math.pi * hz * 2.76 * t) * math.exp(-9 * t)
        elif kind == 'bass':
            env = min(1, t / .01) * math.exp(-3.5 * t)
            v = math.sin(2 * math.pi * hz * t) + .3 * math.sin(2 * math.pi * hz * 2 * t)
        elif kind == 'pad':
            env = min(1, t / .08) * min(1, (dur - t) / .15)
            v = math.sin(2 * math.pi * hz * t) + .2 * math.sin(2 * math.pi * hz * 3 * t)
        else:  # shaker
            env = math.exp(-40 * t)
            v = (hash((s0 + i) * 2654435761) % 2000 / 1000 - 1)
        buf[s0 + i] += v * env * vol


# C, G, Am, F  (MIDI roots)
chords = [(48, [60, 64, 67]), (43, [59, 62, 67]), (45, [60, 64, 69]), (41, [60, 65, 69])]
melody = [72, 76, 79, 76, 74, 79, 74, 71, 72, 76, 81, 76, 77, 76, 74, 72]
for bar in range(BARS):
    root, tones = chords[bar % 4]
    t0 = bar * 4 * BEAT
    for b in range(4):
        add(t0 + b * BEAT, BEAT * .9, note_hz(root), .32, 'bass')
        add(t0 + b * BEAT + BEAT / 2, .08, 0, .05, 'shaker')
        add(t0 + b * BEAT, .06, 0, .035, 'shaker')
    for tn in tones:
        add(t0, BEAT * 4, note_hz(tn), .06, 'pad')
    for k in range(2):
        m = melody[(bar * 2 + k) % len(melody)]
        add(t0 + k * 2 * BEAT, BEAT * 1.8, note_hz(m), .16, 'bell')

peak = max(abs(x) for x in buf) or 1
with wave.open('/tmp/song_loop.wav', 'w') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(b''.join(struct.pack('<h', int(x / peak * .8 * 32767)) for x in buf))
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', '/tmp/song_loop.wav',
                '-c:a', 'libvorbis', '-q:a', '4', 'assets/music/song_loop.ogg'], check=True)
print('assets/music/song_loop.ogg', LEN / RATE, 's')
