import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../audio.dart';
import '../data.dart';
import '../online.dart';
import '../state.dart';
import '../widgets.dart';

/// Read-along story: tap a sentence to hear it, or "Read to me" for all of
/// them; the day's letter is coloured wherever it appears.
class StoryScreen extends StatefulWidget {
  const StoryScreen(this.story, {super.key});
  final Story story;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  int? _reading;
  bool _all = false;

  @override
  void initState() {
    super.initState();
    AppScope.read(context).markSeen(widget.story.letter);
  }

  @override
  void dispose() {
    _all = false;
    _player.dispose();
    super.dispose();
  }

  /// Plays sentence [i]; completes when it has finished.
  Future<void> _play(int i) async {
    final (kn, roman, _) = widget.story.sentences[i];
    setState(() => _reading = i);
    Audio.instance.stop();
    final file = Online.instance.audioFor(kn);
    final voice = AppScope.read(context).voice;
    try {
      await _player.stop();
      if (!voice) return;
      if (file != null) {
        await _player.play(DeviceFileSource(file));
      } else if (Audio.instance.hasRecording(kn)) {
        await _player.play(AssetSource('audio/${audioKey(kn)}.ogg'));
      } else {
        await Audio.instance.speak(kn, roman);
        await Future<void>.delayed(const Duration(seconds: 2));
        return;
      }
      await _player.onPlayerComplete.first.timeout(
        const Duration(seconds: 15),
        onTimeout: () {},
      );
    } catch (_) {}
  }

  Future<void> _readAll() async {
    _all = true;
    for (var i = 0; i < widget.story.sentences.length && _all; i++) {
      if (!mounted) return;
      await _play(i);
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    _all = false;
    if (mounted) setState(() => _reading = null);
  }

  /// [text] with every syllable built on [letter] coloured.
  Widget _highlighted(String text, Color color, bool reading) {
    final spans = <TextSpan>[];
    final ch = widget.story.letter;
    var i = 0;
    while (i < text.length) {
      final at = text.indexOf(ch, i);
      if (at < 0 || ch.isEmpty) {
        spans.add(TextSpan(text: text.substring(i)));
        break;
      }
      var end = at + ch.length;
      // Keep vowel signs and marks that belong to the syllable.
      while (end < text.length) {
        final c = text.codeUnitAt(end);
        if (c >= 0x0CBC && c <= 0x0CD6 && c != 0x0CCD ||
            c == 0x0C82 ||
            c == 0x0C83) {
          end++;
        } else {
          break;
        }
      }
      spans
        ..add(TextSpan(text: text.substring(i, at)))
        ..add(
          TextSpan(
            text: text.substring(at, end),
            style: TextStyle(color: color),
          ),
        );
      i = end;
    }
    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.35,
        color: reading ? K.ink : K.ink.withValues(alpha: .85),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.story;
    final roman = AppScope.of(context).roman;
    final (color, deep) = K.tintFor(st.letter);
    return KidPage(
      title: 'ಇಂದಿನ ಕಥೆ',
      sub: st.online ? "Today's story · ✨ new" : "Today's story",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: deep, offset: const Offset(0, 4)),
                  ],
                ),
                child: Text(
                  st.letter,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      st.title.$1,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    if (roman && st.title.$2.isNotEmpty)
                      Text(
                        st.title.$2,
                        style: const TextStyle(fontSize: 15, color: K.inkSoft),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < st.sentences.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Toy(
                onTap: () {
                  _all = false;
                  _play(i);
                },
                color: _reading == i ? K.pastel(color, .22) : K.white,
                base: _reading == i ? deep : K.shade,
                depth: 4,
                radius: 20,
                semanticLabel: st.sentences[i].$3,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.volume_up_rounded, color: deep, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _highlighted(st.sentences[i].$1, deep, _reading == i),
                          if (roman)
                            Text(
                              st.sentences[i].$3,
                              style: const TextStyle(
                                fontSize: 14,
                                color: K.inkSoft,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: PillButton(
              '▶ ಓದಿ ಹೇಳು · Read to me',
              color: K.green,
              base: K.greenDeep,
              onTap: _all ? null : _readAll,
            ),
          ),
          if (!st.online) ...[
            const SizedBox(height: 14),
            const Text(
              'Connect to the internet for a new story every day.',
              textAlign: TextAlign.center,
              style: TextStyle(color: K.inkSoft, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
