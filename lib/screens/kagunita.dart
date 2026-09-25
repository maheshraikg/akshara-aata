import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../data.dart';
import '../main.dart';
import '../state.dart';
import '../widgets.dart';

/// Consonant × 15 vowel signs (ಕ ಕಾ ಕಿ … ಕಃ).
class KagunitaScreen extends StatefulWidget {
  const KagunitaScreen({super.key, required this.base});
  final Letter base;

  @override
  State<KagunitaScreen> createState() => _KagunitaScreenState();
}

class _KagunitaScreenState extends State<KagunitaScreen> {
  Timer? _timer;
  int _playing = -1;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<(String, String)> get forms => [
    for (final s in signs)
      (widget.base.ch + s.sign, rootOf(widget.base) + s.tr),
  ];

  void _hearAll() {
    _timer?.cancel();
    var i = 0;
    void step() {
      if (!mounted || i >= forms.length) {
        _timer?.cancel();
        setState(() => _playing = -1);
        return;
      }
      setState(() => _playing = i);
      Audio.instance.speak(forms[i].$1, forms[i].$2);
      i++;
    }

    step();
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) => step());
  }

  @override
  Widget build(BuildContext context) {
    final roman = AppScope.of(context).roman;
    final bases = byGroup(Group.vyanjana);
    final f = forms;
    return KidPage(
      title: 'ಕಾಗುಣಿತ',
      sub: 'Kagunita — pick a letter, then tap a form',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in bases)
                Toy(
                  onTap: b == widget.base
                      ? null
                      : () => replace(context, KagunitaScreen(base: b)),
                  color: b == widget.base ? K.blue : K.white,
                  base: b == widget.base ? K.blueDeep : K.shade,
                  radius: 14,
                  depth: 4,
                  semanticLabel: b.tr,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          b.ch,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: b == widget.base ? K.white : K.blue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SectionTitle(
            '${widget.base.ch} ಕಾಗುಣಿತ',
            '${widget.base.tr} + vowel signs',
          ),
          TileGrid(
            children: [
              for (var i = 0; i < f.length; i++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: i == _playing ? K.turmeric : Colors.transparent,
                      width: 4,
                    ),
                  ),
                  child: LetterTile(
                    f[i].$1,
                    color: K.blue,
                    caption: roman ? f[i].$2 : null,
                    label: f[i].$2,
                    onTap: () => Audio.instance.speak(f[i].$1, f[i].$2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: PillButton('🔊 ಎಲ್ಲವನ್ನೂ ಕೇಳು · Hear all', onTap: _hearAll),
          ),
        ],
      ),
    );
  }
}
