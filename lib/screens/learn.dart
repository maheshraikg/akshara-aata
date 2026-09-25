import 'package:flutter/material.dart';

import '../audio.dart';
import '../data.dart';
import '../main.dart';
import '../state.dart';
import '../widgets.dart';
import 'trace.dart';

List<CardItem> get vowelCards => [
  ...byGroup(Group.swara),
  ...byGroup(Group.yogavaha),
].map(CardItem.letter).toList();
List<CardItem> get consonantCards =>
    byGroup(Group.vyanjana).map(CardItem.letter).toList();
List<CardItem> get numberCards => numbers.map(CardItem.number).toList();

class VowelsScreen extends StatelessWidget {
  const VowelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cards = vowelCards;
    Widget tile(int i) => LetterTile(
      cards[i].ch,
      color: K.of(cards[i].color),
      done: s.traced.contains(cards[i].ch),
      label: cards[i].sayRoman,
      onTap: () => push(context, LetterCardScreen(items: cards, index: i)),
    );
    return KidPage(
      title: 'ಸ್ವರಗಳು',
      sub: 'Vowels — tap a letter',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TileGrid(children: [for (var i = 0; i < 13; i++) tile(i)]),
          const SectionTitle('ಯೋಗವಾಹಗಳು', 'Yogavahas'),
          TileGrid(children: [tile(13), tile(14)]),
        ],
      ),
    );
  }
}

class ConsonantsScreen extends StatelessWidget {
  const ConsonantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final vy = byGroup(Group.vyanjana);
    final cards = consonantCards;
    return KidPage(
      title: 'ವ್ಯಂಜನಗಳು',
      sub: 'Consonants — tap a letter',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final v in vargas) ...[
            SectionTitle(v.name, v.en),
            TileGrid(
              children: [
                for (var i = 0; i < vy.length; i++)
                  if (vy[i].varga == v.id)
                    LetterTile(
                      vy[i].ch,
                      color: K.blue,
                      done: s.traced.contains(vy[i].ch),
                      label: vy[i].tr,
                      onTap: () => push(
                        context,
                        LetterCardScreen(items: cards, index: i),
                      ),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class NumbersScreen extends StatelessWidget {
  const NumbersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cards = numberCards;
    return KidPage(
      title: 'ಅಂಕಿಗಳು',
      sub: 'Kannada numbers',
      child: TileGrid(
        children: [
          for (var i = 0; i < cards.length; i++)
            LetterTile(
              cards[i].ch,
              color: K.green,
              caption: '${cards[i].count}',
              done: s.traced.contains(cards[i].ch),
              label: '${cards[i].count}',
              onTap: () =>
                  push(context, LetterCardScreen(items: cards, index: i)),
            ),
        ],
      ),
    );
  }
}

class LetterCardScreen extends StatefulWidget {
  const LetterCardScreen({super.key, required this.items, required this.index});
  final List<CardItem> items;
  final int index;

  @override
  State<LetterCardScreen> createState() => _LetterCardScreenState();
}

class _LetterCardScreenState extends State<LetterCardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  CardItem get item => widget.items[widget.index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppScope.read(context).markSeen(item.ch);
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _sayLetter();
      });
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _sayLetter() {
    _pop.forward(from: 0);
    Audio.instance.speak(item.say, item.sayRoman);
  }

  void _sayWord() => Audio.instance.speak(item.word, item.wordTr);

  void _go(int i) {
    if (i < 0 || i >= widget.items.length) return;
    replace(context, LetterCardScreen(items: widget.items, index: i));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final color = K.of(item.color);
    final isNum = item.count != null;
    return KidPage(
      title: '${widget.index + 1} / ${widget.items.length}',
      sub: item.label,
      child: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -250) _go(widget.index + 1);
          if (v > 250) _go(widget.index - 1);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          decoration: BoxDecoration(
            color: K.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [BoxShadow(color: K.shade, offset: Offset(0, 6))],
          ),
          child: Column(
            children: [
              Semantics(
                button: true,
                label: 'Say ${item.sayRoman}',
                child: GestureDetector(
                  onTap: _sayLetter,
                  child: AnimatedBuilder(
                    animation: _pop,
                    builder: (_, child) {
                      final t = _pop.value;
                      final scale = t < .3
                          ? 1 + t / .3 * .15
                          : t < .6
                          ? 1.15 - (t - .3) / .3 * .19
                          : .96 + (t - .6) / .4 * .04;
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Text(
                      item.ch,
                      style: TextStyle(
                        fontSize: 150,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: color,
                        shadows: const [
                          Shadow(
                            color: Color(0x1F2A1D14),
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (s.roman && !isNum)
                Text(
                  '“${item.sayRoman}”',
                  style: const TextStyle(
                    fontSize: 18,
                    color: K.inkSoft,
                    letterSpacing: .6,
                  ),
                ),
              const SizedBox(height: 10),
              if (isNum)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    item.count == 0
                        ? '🫙'
                        : List.filled(item.count!, '⭐').join(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 30, height: 1.3),
                  ),
                ),
              Toy(
                onTap: _sayWord,
                color: K.paper,
                base: Colors.transparent,
                depth: 0,
                radius: 20,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                semanticLabel: '${item.wordTr} ${item.en ?? ''}',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.emoji != null) ...[
                      Text(item.emoji!, style: const TextStyle(fontSize: 52)),
                      const SizedBox(width: 14),
                    ],
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HighlightedWord(
                            word: item.word,
                            ch: isNum ? '' : item.ch,
                            color: color,
                          ),
                          Text(
                            [
                              if (s.roman) item.wordTr,
                              if (item.en != null) item.en!,
                              if (isNum) '${item.count}',
                            ].join(' · '),
                            style: const TextStyle(
                              color: K.inkSoft,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  RoundButton(
                    '◀',
                    label: 'Previous',
                    onTap: widget.index > 0
                        ? () => _go(widget.index - 1)
                        : null,
                  ),
                  RoundButton(
                    '🔊',
                    label: 'Listen',
                    color: K.blue,
                    base: K.blueDeep,
                    onTap: () {
                      _sayLetter();
                      if (!isNum) {
                        Future.delayed(const Duration(milliseconds: 1100), () {
                          if (mounted) _sayWord();
                        });
                      }
                    },
                  ),
                  RoundButton(
                    '✏️',
                    label: 'Trace this letter',
                    color: K.turmeric,
                    base: K.turmericDeep,
                    onTap: () => push(
                      context,
                      TraceScreen(items: widget.items, index: widget.index),
                    ),
                  ),
                  RoundButton(
                    '▶',
                    label: 'Next',
                    onTap: widget.index < widget.items.length - 1
                        ? () => _go(widget.index + 1)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightedWord extends StatelessWidget {
  const _HighlightedWord({
    required this.word,
    required this.ch,
    required this.color,
  });
  final String word;
  final String ch;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      color: K.ink,
      height: 1.3,
    );
    final i = ch.isEmpty ? -1 : word.indexOf(ch);
    if (i < 0) return Text(word, style: style);
    // Colour the whole syllable (letter + its vowel signs) so shaping isn't
    // split mid-cluster; skip conjuncts, which can't be coloured apart.
    var end = i + ch.length;
    bool isMark(int c) =>
        (c >= 0x0CBC && c <= 0x0CD6) || c == 0x0C82 || c == 0x0C83;
    while (end < word.length && isMark(word.codeUnitAt(end))) {
      end++;
    }
    const virama = 0x0CCD;
    if (word.codeUnitAt(end - 1) == virama ||
        (i > 0 && word.codeUnitAt(i - 1) == virama)) {
      return Text(word, style: style);
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: word.substring(0, i)),
          TextSpan(
            text: word.substring(i, end),
            style: TextStyle(color: color),
          ),
          TextSpan(text: word.substring(end)),
        ],
      ),
    );
  }
}
