import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'data.dart';
import 'lines.dart';

/// A short story to read along: a letter, a title and a few sentences
/// (Kannada, romanised, English).
class Story {
  const Story({
    required this.letter,
    required this.title,
    required this.sentences,
    required this.online,
  });
  final String letter;
  final (String, String) title;
  final List<(String, String, String)> sentences;

  /// A new story from the online pack (written by AI), not built in.
  final bool online;
}

/// The online daily pack: new stories written by Gemini and read by Sarvam
/// every day in GitHub Actions (tool/gemini_daily.py), published as a
/// release file. When the phone is online the app downloads it; offline it
/// uses the last pack it downloaded, or its built-in letter lines. The app
/// sends nothing and never calls an AI service itself.
class Online {
  Online._();
  static final Online instance = Online._();

  static const url =
      'https://github.com/maheshraikg/Pdf_Tools/releases/download/akshara-aata-online/daily.zip';

  /// Today's story, online if there is one, otherwise built in.
  final ValueNotifier<Story> today = ValueNotifier(
    offlineStory(DateTime.now()),
  );

  Directory? _dir;
  bool _fetching = false;

  Future<void> init() async {
    try {
      final base = await getApplicationSupportDirectory();
      _dir = Directory('${base.path}/online');
      await _dir!.create(recursive: true);
      _load();
      await refresh();
    } catch (_) {
      // No storage or no network: keep the built-in story.
    }
  }

  /// Downloads a new pack if the one on the phone is older than six hours.
  Future<void> refresh({bool force = false}) async {
    final dir = _dir;
    if (dir == null || _fetching) return;
    final pack = File('${dir.path}/pack.json');
    if (!force &&
        pack.existsSync() &&
        DateTime.now().difference(pack.lastModifiedSync()).inHours < 6) {
      return;
    }
    _fetching = true;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close().timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return;
      final bytes = await res
          .fold<BytesBuilder>(BytesBuilder(), (b, d) => b..add(d))
          .timeout(const Duration(seconds: 120));
      final zip = ZipDecoder().decodeBytes(bytes.takeBytes());
      final fresh = Directory('${dir.path}.new');
      if (fresh.existsSync()) fresh.deleteSync(recursive: true);
      fresh.createSync(recursive: true);
      for (final f in zip.files) {
        final name = f.name.split('/').last;
        if (!f.isFile || name.isEmpty || name.contains('..')) continue;
        File('${fresh.path}/$name').writeAsBytesSync(f.content);
      }
      if (!File('${fresh.path}/pack.json').existsSync()) return;
      dir.deleteSync(recursive: true);
      fresh.renameSync(dir.path);
      _load();
    } catch (_) {
      // Offline or the pack isn't there: keep what we have.
    } finally {
      client.close(force: true);
      _fetching = false;
    }
  }

  void _load() {
    try {
      final m = jsonDecode(
        File('${_dir!.path}/pack.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final story = storyFor(m, DateTime.now());
      if (story != null) today.value = story;
    } catch (_) {}
  }

  /// The downloaded recording of [kannada], if the pack has one.
  String? audioFor(String kannada) {
    final dir = _dir;
    if (dir == null) return null;
    final f = File('${dir.path}/${audioKey(kannada)}.ogg');
    return f.existsSync() ? f.path : null;
  }
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Today's story from a pack, or null if the pack has none for today.
Story? storyFor(Map<String, dynamic> pack, DateTime now) {
  final s = (pack['stories'] as Map?)?[_date(now)] as Map?;
  if (s == null) return null;
  final title = (s['title'] as List).cast<String>();
  return Story(
    letter: s['letter'] as String,
    title: (title[0], title.length > 1 ? title[1] : ''),
    sentences: [
      for (final x in s['sentences'] as List)
        (x[0] as String, x[1] as String, x[2] as String),
    ],
    online: true,
  );
}

/// The built-in story for a day: the letter's line and its words.
Story offlineStory(DateTime now) {
  final l = letters[now.difference(DateTime(2000)).inDays % letters.length];
  final line = letterLines[l.ch];
  return Story(
    letter: l.ch,
    title: ('${l.ch} ಅಕ್ಷರ', 'The letter ${l.tr}'),
    sentences: [?line, for (final w in wordsFor(l)) (w.word, w.wordTr, w.en)],
    online: false,
  );
}
