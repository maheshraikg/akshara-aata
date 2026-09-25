// Generates the built-in Kannada recordings in assets/audio/.
//
//   dart run tool/generate_audio.dart          # only missing files
//   dart run tool/generate_audio.dart --all    # regenerate everything
//
// Needs espeak-ng (Kannada voice) and ffmpeg on PATH. To use a human voice
// instead, record the lines in assets/audio/recording-list.csv and save each
// as an .ogg file with the listed name; this tool never overwrites a file
// unless --all is given.
import 'dart:io';

import 'package:akshara_aata/data.dart';

const voice = 'kn+f3';
// Single letters are spoken slower than words so small children hear them.
const letterSpeed = '90';
const wordSpeed = '115';

Future<void> main(List<String> args) async {
  final all = args.contains('--all');
  final dir = Directory('assets/audio')..createSync(recursive: true);
  final texts = spokenTexts();
  final csv = StringBuffer('file,kannada,roman\n');
  var made = 0;
  for (final (kn, roman) in texts) {
    final key = audioKey(kn);
    csv.writeln('$key.ogg,$kn,$roman');
    final out = File('${dir.path}/$key.ogg');
    if (out.existsSync() && !all) continue;
    final wav = '${Directory.systemTemp.path}/akshara_$key.wav';
    final speed = kn.runes.length <= 3 ? letterSpeed : wordSpeed;
    await _run('espeak-ng', ['-v', voice, '-s', speed, '-w', wav, kn]);
    // Trim silence at both ends, level the volume, encode small mono Vorbis.
    await _run('ffmpeg', [
      '-y',
      '-loglevel',
      'error',
      '-i',
      wav,
      '-af',
      'silenceremove=start_periods=1:start_threshold=-45dB,areverse,'
          'silenceremove=start_periods=1:start_threshold=-45dB,areverse,'
          'apad=pad_dur=0.08,loudnorm=I=-16:TP=-1.5',
      '-ac',
      '1',
      '-ar',
      '22050',
      '-c:a',
      'libvorbis',
      '-q:a',
      '4',
      out.path,
    ]);
    File(wav).deleteSync();
    made++;
  }
  File('${dir.path}/recording-list.csv').writeAsStringSync(csv.toString());
  stdout.writeln('${texts.length} texts, $made files written to ${dir.path}');
}

Future<void> _run(String exe, List<String> args) async {
  final r = await Process.run(exe, args);
  if (r.exitCode != 0) {
    stderr.write(r.stderr);
    throw ProcessException(exe, args, 'exit ${r.exitCode}', r.exitCode);
  }
}
