import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../state.dart';
import '../widgets.dart';
import 'games.dart';
import 'kagunita.dart';
import 'learn.dart';
import 'parents.dart';
import 'song.dart';
import 'trace.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final seen = letters.where((l) => s.seen.contains(l.ch)).length;
    final traced = letters.where((l) => s.traced.contains(l.ch)).length;
    return KidPage(
      title: 'ಅಕ್ಷರ ಆಟ',
      sub: 'Akshara Aata · Kannada Varnamala',
      back: false,
      ad: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Hero(),
          const SizedBox(height: 14),
          const _LetterOfTheDay(),
          const SizedBox(height: 14),
          const _StreakCard(),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: HomeBlock(
              pic: '🎵',
              title: 'ಅಕ್ಷರ ಹಾಡು',
              sub: 'Alphabet song',
              color: K.green,
              base: K.greenDeep,
              glyphSize: 62,
              onTap: () => push(context, const SongScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _BlockGrid(
            children: [
              HomeBlock(
                glyph: 'ಅ',
                pic: '🐘',
                title: 'ಸ್ವರಗಳು',
                sub: 'Vowels · 13',
                color: K.red,
                base: K.redDeep,
                onTap: () => push(context, const VowelsScreen()),
              ),
              HomeBlock(
                glyph: 'ಕ',
                pic: '🦚',
                title: 'ವ್ಯಂಜನಗಳು',
                sub: 'Consonants · 34',
                color: K.blue,
                base: K.blueDeep,
                onTap: () => push(context, const ConsonantsScreen()),
              ),
              HomeBlock(
                glyph: 'ಕಾ',
                pic: '🧩',
                title: 'ಕಾಗುಣಿತ',
                sub: 'Letter + vowel sign',
                color: K.plum,
                base: K.plumDeep,
                onTap: () => push(context, KagunitaScreen(base: letters[15])),
              ),
              HomeBlock(
                glyph: '೩',
                pic: '🧮',
                title: 'ಅಂಕಿಗಳು',
                sub: 'Numbers ೦–೧೦',
                color: K.teal,
                base: K.tealDeep,
                onTap: () => push(context, const NumbersScreen()),
              ),
              HomeBlock(
                pic: '✏️',
                title: 'ಬರೆಯೋಣ',
                sub: 'Trace & write',
                color: K.orange,
                base: K.orangeDeep,
                onTap: () => push(context, const TraceMenuScreen()),
              ),
              HomeBlock(
                pic: '🎮',
                title: 'ಆಟಗಳು',
                sub: '7 fun games',
                color: K.pink,
                base: K.pinkDeep,
                onTap: () => push(context, const GamesScreen()),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: K.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(color: K.shade, offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ನನ್ನ ಪ್ರಗತಿ · My progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: seen / 49,
                    minHeight: 16,
                    color: K.green,
                    backgroundColor: K.paper,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$seen / 49 letters explored · $traced / 49 letters written',
                  style: const TextStyle(color: K.inkSoft, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < stickers.length; i++)
                      Opacity(
                        opacity: i < s.stickersUnlocked ? 1 : .22,
                        child: ColorFiltered(
                          colorFilter: i < s.stickersUnlocked
                              ? const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.dst,
                                )
                              : const ColorFilter.matrix(_grey),
                          child: Pic(stickers[i], size: 34),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Every 10 ⭐ unlocks a sticker.',
                  style: TextStyle(color: K.inkSoft, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: TextButton(
              onPressed: () => push(context, const ParentGateScreen()),
              child: const Text(
                'For parents · Settings',
                style: TextStyle(
                  color: K.inkSoft,
                  fontSize: 15,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _grey = <double>[
  .33, .33, .33, 0, 0, //
  .33, .33, .33, 0, 0,
  .33, .33, .33, 0, 0,
  0, 0, 0, 1, 0,
];

class _BlockGrid extends StatelessWidget {
  const _BlockGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 12,
    crossAxisSpacing: 14,
    childAspectRatio: 1.08,
    children: children,
  );
}

class HomeBlock extends StatelessWidget {
  const HomeBlock({
    super.key,
    this.glyph = '',
    this.pic,
    required this.title,
    required this.sub,
    required this.color,
    required this.base,
    required this.onTap,
    this.fg = K.white,
    this.glyphSize = 76,
  });

  /// Kannada letter shown in a round badge (optional).
  final String glyph;

  /// Emoji whose 3D illustration decorates the block.
  final String? pic;
  final String title;
  final String sub;
  final Color color;
  final Color base;
  final Color fg;
  final VoidCallback onTap;
  final double glyphSize;

  @override
  Widget build(BuildContext context) => Toy(
    onTap: onTap,
    color: color,
    base: base,
    radius: 22,
    depth: 8,
    semanticLabel: '$title, $sub',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          if (pic != null)
            Positioned(
              right: 6,
              top: 6,
              child: Bob(
                height: 5,
                ms: 1600,
                child: Pic(pic!, size: glyphSize + 12),
              ),
            )
          else
            Positioned(
              right: 10,
              top: -8,
              child: Text(
                glyph,
                style: TextStyle(
                  fontSize: glyphSize,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: fg.withValues(alpha: .92),
                  shadows: [Shadow(color: base, offset: const Offset(0, 4))],
                ),
              ),
            ),
          if (pic != null && glyph.isNotEmpty)
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                padding: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: base, offset: const Offset(0, 3)),
                  ],
                ),
                child: Text(
                  glyph,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: base,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: fg,
                      height: 1.15,
                    ),
                  ),
                ),
                if (AppScope.of(context).roman)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: fg.withValues(alpha: .92),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Mascot extends StatefulWidget {
  const _Mascot();

  @override
  State<_Mascot> createState() => _MascotState();
}

class _MascotState extends State<_Mascot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, still ? 0 : -6 * _c.value),
        child: Transform.rotate(
          angle: still ? 0 : -.07 * _c.value,
          child: child,
        ),
      ),
      child: const Text('🐘', style: TextStyle(fontSize: 58)),
    );
  }
}

/// Sunny welcome card: the elephant greets the current child by name.
/// Tapping the child's picture switches between children.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4F8B), Color(0xFFFF9A3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0xFFD63A6E), offset: Offset(0, 6)),
          BoxShadow(
            color: Color(0x262B2140),
            offset: Offset(0, 12),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          const Bob(height: 8, child: Pic('🐘', size: 88)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ನಮಸ್ಕಾರ, ${s.child.name}!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: K.redDeep,
                          ),
                        ),
                        const Text(
                          'ಬಾ, ಕನ್ನಡ ಅಕ್ಷರ ಕಲಿಯೋಣ!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: K.ink,
                          ),
                        ),
                        if (s.roman)
                          const Text(
                            "Let's learn Kannada letters",
                            style: TextStyle(fontSize: 13.5, color: K.inkSoft),
                          ),
                      ],
                    ),
                  ),
                  if (s.profiles.length > 1)
                    Semantics(
                      button: true,
                      label: 'Switch child',
                      child: GestureDetector(
                        onTap: () => _pickChild(context),
                        child: Pic(s.child.avatar, size: 46),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _pickChild(BuildContext context) {
  final s = AppScope.read(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < s.profiles.length; i++)
              GestureDetector(
                onTap: () {
                  s.switchProfile(i);
                  Navigator.pop(ctx);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == s.current ? K.pastel(K.green, .3) : K.paper,
                      ),
                      child: Pic(s.profiles[i].avatar, size: 64),
                    ),
                    Text(
                      s.profiles[i].name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Daily streak and today's letters (goal: 5 a day).
class _StreakCard extends StatelessWidget {
  const _StreakCard();
  static const goal = 5;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final today = s.todayCount;
    final streak = s.streak;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: K.shade, offset: Offset(0, 5))],
      ),
      child: Row(
        children: [
          Pic(streak > 0 ? '🔥' : '🌱', size: 50),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak > 1
                      ? '$streak ದಿನಗಳ ಸರಣಿ!'
                      : today > 0
                      ? 'ಇಂದು ಚೆನ್ನಾಗಿ ಕಲಿತೆ!'
                      : 'ಇಂದಿನ ಕಲಿಕೆ ಶುರು ಮಾಡೋಣ',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (s.roman)
                  Text(
                    streak > 1
                        ? '$streak-day streak · $today / $goal letters today'
                        : '$today / $goal letters today',
                    style: const TextStyle(fontSize: 13.5, color: K.inkSoft),
                  ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (today / goal).clamp(0.0, 1.0),
                    minHeight: 10,
                    color: today >= goal ? K.green : K.orange,
                    backgroundColor: K.paper,
                  ),
                ),
              ],
            ),
          ),
          if (today >= goal) ...[
            const SizedBox(width: 8),
            const Pic('🏅', size: 40),
          ],
        ],
      ),
    );
  }
}

/// A different letter every day, one tap from its card.
class _LetterOfTheDay extends StatelessWidget {
  const _LetterOfTheDay();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = now.difference(DateTime(now.year)).inDays;
    final cards = [...vowelCards, ...consonantCards];
    final i = day % cards.length;
    final item = cards[i];
    final (c, deep) = K.tintFor(item.ch);
    return Toy(
      onTap: () => push(context, LetterCardScreen(items: cards, index: i)),
      color: Colors.white,
      base: K.pastel(deep, .5),
      radius: 26,
      semanticLabel: 'Letter of the day, ${item.sayRoman}',
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              item.ch,
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
                  'ಇಂದಿನ ಅಕ್ಷರ · TODAY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                    color: deep,
                  ),
                ),
                Text(
                  item.word,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if (item.en != null)
                  Text(
                    item.en!,
                    style: const TextStyle(fontSize: 14, color: K.inkSoft),
                  ),
              ],
            ),
          ),
          Bob(
            child: item.emoji == null
                ? const SizedBox()
                : Pic(item.emoji!, size: 64),
          ),
        ],
      ),
    );
  }
}
