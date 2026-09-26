"""Downloads pronunciation recordings from Wikimedia Commons categories,
with each file's licence and author, into commons/ + commons/meta.json.

  python tool/fetch_commons.py "Pronunciation of Kannada alphabet" "Lingua Libre pronunciation-kan"
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

API = 'https://commons.wikimedia.org/w/api.php'
UA = {'User-Agent': 'AksharaAata/1.0 (Kannada learning app; build script)'}


def api(params):
    params = {**params, 'format': 'json', 'formatversion': '2'}
    req = urllib.request.Request(API + '?' + urllib.parse.urlencode(params), headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def members(cat):
    out, cont = [], {}
    while True:
        d = api({'action': 'query', 'list': 'categorymembers', 'cmtitle': 'Category:' + cat,
                 'cmtype': 'file', 'cmlimit': '500', **cont})
        out += [m['title'] for m in d['query']['categorymembers']]
        if 'continue' not in d:
            return out
        cont = d['continue']


def info(titles):
    d = api({'action': 'query', 'prop': 'imageinfo', 'titles': '|'.join(titles),
             'iiprop': 'url|extmetadata|size'})
    res = {}
    for p in d['query']['pages']:
        ii = (p.get('imageinfo') or [{}])[0]
        md = ii.get('extmetadata', {})
        g = lambda k: (md.get(k) or {}).get('value', '')
        res[p['title']] = {'url': ii.get('url'), 'license': g('LicenseShortName'),
                           'artist': g('Artist'), 'credit': g('Credit'),
                           'description': g('ImageDescription')}
    return res


os.makedirs('commons', exist_ok=True)
meta = {}
for cat in sys.argv[1:]:
    titles = members(cat)
    print(cat, len(titles), flush=True)
    for i in range(0, len(titles), 40):
        for t, m in info(titles[i:i + 40]).items():
            m['category'] = cat
            meta[t] = m
for n, (t, m) in enumerate(meta.items()):
    if not m['url']:
        continue
    name = t.removeprefix('File:')
    path = os.path.join('commons', name)
    if not os.path.exists(path):
        for attempt in range(3):
            try:
                req = urllib.request.Request(m['url'], headers=UA)
                with urllib.request.urlopen(req, timeout=60) as r, open(path, 'wb') as f:
                    f.write(r.read())
                break
            except Exception as e:  # noqa: BLE001
                print('retry', name, e, flush=True)
                time.sleep(3)
    m['file'] = name
    if n % 100 == 0:
        print(n, '/', len(meta), flush=True)
json.dump(meta, open('commons/meta.json', 'w'), ensure_ascii=False, indent=1)
print('done', len(meta))
