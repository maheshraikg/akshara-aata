"""Imports the letter lines made by tool/gemini_content.py.

  python3 tool/import_lines.py path/to/out [--skip ಅ ಕ …]

Converts out/<key>.wav to assets/audio/<key>.ogg and writes lib/lines.dart.
Letters given after --skip (lines a Kannada speaker rejected) are left out.
"""
import json
import os
import subprocess
import sys


def key(t):
    return '_'.join(f'{ord(c):x}' for c in t)


def dart(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def main():
    src = sys.argv[1]
    skip = set(sys.argv[sys.argv.index('--skip') + 1:]) if '--skip' in sys.argv else set()
    lines = json.load(open(os.path.join(src, 'lines.json'), encoding='utf-8'))
    order = open('lib/data.dart', encoding='utf-8').read()
    kept = {}
    for ch, (kn, roman, en) in sorted(lines.items(), key=lambda e: order.index(f"Letter('{e[0]}'")
                                      if f"Letter('{e[0]}'" in order else 9999):
        wav = os.path.join(src, key(kn) + '.wav')
        if ch in skip or not os.path.exists(wav):
            continue
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav,
                        '-af', 'silenceremove=start_periods=1:start_threshold=-45dB,'
                        'areverse,silenceremove=start_periods=1:start_threshold=-45dB,'
                        'areverse,loudnorm=I=-16:TP=-1.5',
                        '-ar', '24000', '-ac', '1', '-c:a', 'libvorbis', '-q:a', '4',
                        f'assets/audio/{key(kn)}.ogg'], check=True)
        kept[ch] = (kn, roman, en)
    body = ''.join(f'  {dart(ch)}: ({dart(kn)}, {dart(r)}, {dart(en)}),\n'
                   for ch, (kn, r, en) in kept.items())
    head = open('lib/lines.dart', encoding='utf-8').read().split('const letterLines')[0]
    with open('lib/lines.dart', 'w', encoding='utf-8') as f:
        f.write(head + 'const letterLines = <String, (String, String, String)>{\n' + body + '};\n')
    print(f'imported {len(kept)} lines; skipped {sorted(skip)}')


if __name__ == '__main__':
    main()
