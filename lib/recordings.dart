import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

import 'data.dart';

/// A native speaker's own recordings, made in the parents' recording studio.
/// They play instead of the built-in voice on this phone, and can be
/// exported as a zip so they can be built into the app for everyone.
class Recordings {
  Recordings._();
  static final Recordings instance = Recordings._();

  Directory? _dir;
  final Set<String> _keys = {};
  final AudioRecorder _rec = AudioRecorder();

  int get count => _keys.length;
  bool has(String kannada) => _keys.contains(audioKey(kannada));
  String? pathFor(String kannada) =>
      _dir == null ? null : '${_dir!.path}/${audioKey(kannada)}.m4a';

  Future<void> init() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final d = Directory('${base.path}/recordings');
      await d.create(recursive: true);
      _dir = d;
      for (final f in d.listSync()) {
        final name = f.uri.pathSegments.last;
        if (name.endsWith('.m4a')) {
          _keys.add(name.substring(0, name.length - 4));
        }
      }
    } catch (_) {
      _dir = null;
    }
  }

  /// Asks for the microphone if needed. Returns false if refused.
  Future<bool> start(String kannada) async {
    final path = pathFor(kannada);
    if (path == null) return false;
    try {
      if (!await _rec.hasPermission()) return false;
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 96000,
        ),
        path: '$path.part',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stops and keeps the recording if it is long enough to hold speech.
  Future<bool> stop(String kannada) async {
    try {
      final p = await _rec.stop();
      if (p == null) return false;
      final f = File(p);
      if (!f.existsSync() || f.lengthSync() < 3000) {
        if (f.existsSync()) f.deleteSync();
        return false;
      }
      f.renameSync(p.substring(0, p.length - 5));
      _keys.add(audioKey(kannada));
      return true;
    } catch (_) {
      return false;
    }
  }

  void delete(String kannada) {
    final path = pathFor(kannada);
    if (path == null) return;
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
    _keys.remove(audioKey(kannada));
  }

  /// Zips every recording with a list of what each file says, and opens the
  /// share sheet (WhatsApp, Drive, email…).
  Future<void> export() async {
    final d = _dir;
    if (d == null || _keys.isEmpty) return;
    final byKey = {
      for (final (kn, tr) in spokenTexts()) audioKey(kn): (kn, tr),
    };
    final list = StringBuffer('file,kannada,roman\n');
    final archive = Archive();
    for (final k in _keys) {
      final bytes = File('${d.path}/$k.m4a').readAsBytesSync();
      archive.addFile(ArchiveFile('$k.m4a', bytes.length, bytes));
      final (kn, tr) = byKey[k] ?? ('', '');
      list.writeln('$k.m4a,$kn,$tr');
    }
    final csv = list.toString().codeUnits;
    archive.addFile(ArchiveFile('list.csv', csv.length, csv));
    final tmp = await getTemporaryDirectory();
    final zip = File('${tmp.path}/akshara-aata-recordings.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(zip.path)],
        text: 'Akshara Aata voice recordings (${_keys.length})',
      ),
    );
  }
}
