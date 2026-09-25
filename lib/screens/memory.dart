import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../data.dart';
import '../widgets.dart';
import 'games.dart';

class _MCard {
  _MCard(this.letter, this.isPicture);
  final Letter letter;
  final bool isPicture;
  bool open = false;
  bool matched = false;
  String get face => isPicture ? letter.emoji : letter.ch;
}

/// Match each letter with its picture: 6 pairs.
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  late final List<Letter> _pairs = sampleOf(
    letters.where((l) => l.start).toList(),
    6,
    const [],
  );
  late final List<_MCard> _cards = shuffled([
    for (final l in _pairs) _MCard(l, false),
    for (final l in _pairs) _MCard(l, true),
  ]);
  final List<_MCard> _open = [];
  int _moves = 0;
  int _matched = 0;
  bool _lock = false;

  void _flip(_MCard c) {
    if (_lock || c.open || c.matched) return;
    Audio.instance.tap();
    setState(() => c.open = true);
    c.isPicture
        ? Audio.instance.speak(c.letter.word, c.letter.wordTr)
        : Audio.instance.speak(c.letter.ch, c.letter.tr);
    _open.add(c);
    if (_open.length < 2) return;
    final a = _open[0], b = _open[1];
    _open.clear();
    setState(() => _moves++);
    if (a.letter == b.letter && a.isPicture != b.isPicture) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          a.matched = b.matched = true;
          _matched++;
        });
        Audio.instance.right();
        if (_matched == _pairs.length) {
          final score = _moves <= 9
              ? 8
              : _moves <= 13
              ? 6
              : 4;
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted) finishGame(context, Game.memory, score, 8);
          });
        }
      });
    } else {
      _lock = true;
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() {
          a.open = b.open = false;
          _lock = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) => KidPage(
    title: 'ಜೋಡಿ ಆಟ',
    sub: 'Match each letter with its picture',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Moves: $_moves',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) => GridView.count(
            crossAxisCount: c.maxWidth > 520 ? 4 : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final card in _cards)
                _FlipCard(card: card, onTap: () => _flip(card)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.card, required this.onTap});
  final _MCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shown = card.open || card.matched;
    return Semantics(
      button: true,
      label: shown ? card.face : 'Hidden card',
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: shown ? 1 : 0),
          duration: const Duration(milliseconds: 350),
          builder: (_, t, _) {
            final front = t > .5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0015)
                ..rotateY(math.pi * t),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(front ? math.pi : 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: front
                        ? (card.matched ? const Color(0xFFDFF3E6) : K.white)
                        : K.red,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: K.shade, offset: Offset(0, 5)),
                    ],
                  ),
                  child: front
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: FittedBox(
                              child: Text(
                                card.face,
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const CustomPaint(painter: _BackPainter()),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  const _BackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = K.turmeric;
    for (double y = 12; y < size.height - 4; y += 18) {
      for (double x = 12; x < size.width - 4; x += 18) {
        canvas.drawCircle(Offset(x, y), 3, p);
      }
    }
  }

  @override
  bool shouldRepaint(_BackPainter oldDelegate) => false;
}
