import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../data.dart';
import '../state.dart';
import '../widgets.dart';

/// Sing-along: a cheerful loop plays while each letter lights up and is
/// spoken on the beat (one letter per second at 120 BPM).
class SongScreen extends StatefulWidget {
  const SongScreen({super.key});

  @override
  State<SongScreen> createState() => _SongScreenState();
}

class _SongScreenState extends State<SongScreen> {
  bool _vowels = true;
  bool _playing = false;
  int _at = -1;
  Timer? _timer;

  List<Letter> get _song => _vowels
      ? [...byGroup(Group.swara), ...byGroup(Group.yogavaha)]
      : byGroup(Group.vyanjana);

  void _start() {
    _timer?.cancel();
    Audio.instance.startMusic();
    setState(() {
      _playing = true;
      _at = -1;
    });
    // Let the music's first bar play before the first letter.
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (t) {
      if (!mounted) return;
      if (t.tick < 2) return;
      final next = _at + 1;
      if (next >= _song.length) {
        _stop(finished: true);
        return;
      }
      setState(() => _at = next);
      final l = _song[next];
      Audio.instance.speak(l.ch, l.tr);
      AppScope.read(context).markSeen(l.ch);
    });
  }

  void _stop({bool finished = false}) {
    _timer?.cancel();
    Audio.instance.stopMusic();
    if (!mounted) return;
    setState(() => _playing = false);
    if (finished) {
      Audio.instance.win();
      showConfetti(context);
      reward(context, 2);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    Audio.instance.stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = _song;
    return KidPage(
      title: 'ಅಕ್ಷರ ಹಾಡು',
      sub: 'Alphabet song — sing along!',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final v in [true, false])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: PillButton(
                      v ? 'ಸ್ವರಗಳು' : 'ವ್ಯಂಜನಗಳು',
                      small: true,
                      color: _vowels == v ? K.pink : Colors.white,
                      base: _vowels == v ? K.pinkDeep : K.shade,
                      fg: _vowels == v ? Colors.white : K.ink,
                      onTap: () {
                        _stop();
                        setState(() {
                          _vowels = v;
                          _at = -1;
                        });
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Bob(
              height: _playing ? 10 : 4,
              ms: _playing ? 500 : 1400,
              child: Pic(_playing ? '🎶' : '🎵', size: 96),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: PillButton(
              _playing ? '⏸  ನಿಲ್ಲಿಸು · Stop' : '▶  ಹಾಡೋಣ · Sing',
              color: _playing ? K.orange : K.green,
              base: _playing ? K.orangeDeep : K.greenDeep,
              onTap: _playing ? _stop : _start,
            ),
          ),
          const SizedBox(height: 18),
          TileGrid(
            children: [
              for (var i = 0; i < song.length; i++)
                AnimatedScale(
                  scale: i == _at ? 1.18 : 1,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: i == _at
                          ? [
                              BoxShadow(
                                color: K.turmeric.withValues(alpha: .9),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: LetterTile(
                      song[i].ch,
                      label: song[i].tr,
                      done: i < _at,
                      onTap: () => Audio.instance.speak(song[i].ch, song[i].tr),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
