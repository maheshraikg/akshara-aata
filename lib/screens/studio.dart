import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../audio.dart';
import '../data.dart';
import '../recordings.dart';
import '../widgets.dart';

enum _Set { letters, words, numbers, kagunita }

/// Recording studio for a native Kannada speaker: go through the letters
/// one by one, record, listen back, redo. Recordings replace the built-in
/// voice on this phone and can be exported for the app.
class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  _Set _set = _Set.letters;
  int _i = 0;
  bool _recording = false;
  Timer? _autoStop;
  final AudioPlayer _player = AudioPlayer();

  List<(String, String)> get _items => switch (_set) {
    _Set.letters => [for (final l in letters) (l.ch, l.tr)],
    _Set.words => [
      for (final l in letters)
        for (final w in wordsFor(l)) (w.word, w.wordTr),
    ],
    _Set.numbers => [for (final n in numbers) (n.word, n.wordTr)],
    _Set.kagunita => [
      for (final l in byGroup(Group.vyanjana))
        for (final s in signs.skip(1)) (l.ch + s.sign, rootOf(l) + s.tr),
    ],
  };

  @override
  void dispose() {
    _autoStop?.cancel();
    if (_recording) Recordings.instance.stop(_items[_i].$1);
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final (kn, _) = _items[_i];
    if (_recording) {
      _autoStop?.cancel();
      final ok = await Recordings.instance.stop(kn);
      if (!mounted) return;
      setState(() => _recording = false);
      if (ok) {
        _play();
      } else {
        toast(context, 'Too short, please try again');
      }
      return;
    }
    Audio.instance.stop();
    final ok = await Recordings.instance.start(kn);
    if (!mounted) return;
    if (!ok) {
      toast(context, 'Please allow the microphone');
      return;
    }
    setState(() => _recording = true);
    _autoStop = Timer(const Duration(seconds: 4), () {
      if (_recording) _toggle();
    });
  }

  Future<void> _play() async {
    final path = Recordings.instance.pathFor(_items[_i].$1);
    if (path == null || !Recordings.instance.has(_items[_i].$1)) return;
    try {
      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } catch (_) {}
  }

  void _go(int d) {
    if (_recording) return;
    final n = _items.length;
    setState(() => _i = (_i + d).clamp(0, n - 1));
  }

  /// Jumps to the next item without a recording.
  void _nextMissing() {
    final items = _items;
    for (var k = 1; k <= items.length; k++) {
      final j = (_i + k) % items.length;
      if (!Recordings.instance.has(items[j].$1)) {
        setState(() => _i = j);
        return;
      }
    }
    toast(context, 'Everything in this set is recorded');
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final (kn, tr) = items[_i];
    final done = items.where((e) => Recordings.instance.has(e.$1)).length;
    final mine = Recordings.instance.has(kn);
    return KidPage(
      title: 'ಧ್ವನಿ ಮುದ್ರಣ',
      sub: 'Recording studio — a native speaker records each sound',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (s, label) in [
                (_Set.letters, 'Letters'),
                (_Set.words, 'Words'),
                (_Set.numbers, 'Numbers'),
                (_Set.kagunita, 'Kagunita'),
              ])
                PillButton(
                  label,
                  small: true,
                  color: _set == s ? K.blue : Colors.white,
                  base: _set == s ? K.blueDeep : K.shade,
                  fg: _set == s ? Colors.white : K.ink,
                  onTap: _recording
                      ? null
                      : () => setState(() {
                          _set = s;
                          _i = 0;
                        }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$done / ${items.length} recorded in this set · ${Recordings.instance.count} in total',
            style: const TextStyle(color: K.inkSoft, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _recording ? K.red : (mine ? K.green : Colors.white),
                width: 4,
              ),
              boxShadow: const [
                BoxShadow(color: K.shade, offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '${_i + 1} / ${items.length}',
                  style: const TextStyle(color: K.inkSoft, fontSize: 14),
                ),
                FittedBox(
                  child: Text(
                    kn,
                    style: const TextStyle(
                      fontSize: 110,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
                Text(
                  '“$tr”',
                  style: const TextStyle(fontSize: 18, color: K.inkSoft),
                ),
                const SizedBox(height: 8),
                Text(
                  _recording
                      ? '● Recording… say it clearly, then tap stop'
                      : mine
                      ? '✓ Your recording is used in the app'
                      : 'Not recorded yet (built-in voice is used)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _recording
                        ? K.red
                        : (mine ? K.greenDeep : K.inkSoft),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Toy(
              onTap: _toggle,
              color: _recording ? K.ink : K.red,
              base: _recording ? Colors.black : K.redDeep,
              radius: 60,
              depth: 7,
              semanticLabel: _recording ? 'Stop' : 'Record',
              child: SizedBox(
                width: 96,
                height: 96,
                child: Icon(
                  _recording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 52,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              RoundButton(
                '◀',
                label: 'Previous',
                onTap: _i > 0 && !_recording ? () => _go(-1) : null,
              ),
              PillButton(
                '▶ Mine',
                small: true,
                color: K.green,
                base: K.greenDeep,
                onTap: mine && !_recording ? _play : null,
              ),
              PillButton(
                '🔊 Built-in',
                small: true,
                color: Colors.white,
                base: K.shade,
                fg: K.ink,
                onTap: _recording
                    ? null
                    : () async {
                        // Temporarily hide the own recording to hear the AI.
                        Audio.instance.speakBuiltIn(kn, tr);
                      },
              ),
              RoundButton(
                '▶',
                label: 'Next',
                onTap: _i < items.length - 1 && !_recording
                    ? () => _go(1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              PillButton(
                'Next not recorded',
                small: true,
                color: K.plum,
                base: K.plumDeep,
                onTap: _recording ? null : _nextMissing,
              ),
              if (mine)
                PillButton(
                  'Delete mine',
                  small: true,
                  color: Colors.white,
                  base: K.shade,
                  fg: K.ink,
                  onTap: _recording
                      ? null
                      : () => setState(() => Recordings.instance.delete(kn)),
                ),
            ],
          ),
          const SizedBox(height: 22),
          PillButton(
            'Send recordings (${Recordings.instance.count})',
            color: K.orange,
            base: K.orangeDeep,
            onTap: Recordings.instance.count == 0 || _recording
                ? null
                : () => Recordings.instance.export(),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tips: record in a quiet room, hold the phone 20 cm away, say each '
            'letter once, clearly and naturally, as you would teach a child. '
            '"Send recordings" makes one zip file you can share on WhatsApp, '
            'Drive or email, so the recordings can be built into the app.',
            style: TextStyle(color: K.inkSoft, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}
