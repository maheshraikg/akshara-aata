"""Downloads pronunciation recordings from Wikimedia Commons categories,
with each file's licence and author, into commons/ + commons/meta.json.

  python tool/fetch_commons.py "Pronunciation of Kannada alphabet" "Lingua Libre pronunciation-kan"
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = 'https://commons.wikimedia.org/w/api.php'
# Wikimedia throttles requests without a contact URL in the User-Agent.
UA = {'User-Agent': 'AksharaAata/1.0 (https://github.com/maheshraikg/Pdf_Tools; '
                    'Kannada learning app build script) python-urllib'}


def fetch(url):
    # Wikimedia rate-limits bursts (HTTP 429): go slowly and back off.
    for attempt in range(8):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                data = r.read()
            time.sleep(0.4)
            return data
        except urllib.error.HTTPError as e:
            if e.code != 429 and e.code < 500:
                raise
            wait = int(e.headers.get('Retry-After') or 0) or 5 * (attempt + 1)
            print('waiting', wait, 's after', e.code, url, flush=True)
            time.sleep(min(wait, 60))
        except Exception as e:  # noqa: BLE001
            print('retry', e, flush=True)
            time.sleep(5)
    raise RuntimeError('gave up on ' + url)


def api(params):
    params = {**params, 'format': 'json', 'formatversion': '2'}
    return json.loads(fetch(API + '?' + urllib.parse.urlencode(params)))


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
        try:
            data = fetch(m['url'])
        except Exception as e:  # noqa: BLE001
            print('skipped', name, e, flush=True)
            continue
        with open(path, 'wb') as f:
            f.write(data)
    m['file'] = name
    print(n + 1, '/', len(meta), name, flush=True)
json.dump(meta, open('commons/meta.json', 'w'), ensure_ascii=False, indent=1)
print('done', len(meta))
