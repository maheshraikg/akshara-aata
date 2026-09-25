import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import '../state.dart';
import '../widgets.dart';
import 'games.dart';
import 'kagunita.dart';
import 'learn.dart';
import 'parents.dart';
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
          const Padding(
            padding: EdgeInsets.only(bottom: 18, top: 2),
            child: Row(
              children: [
                _Mascot(),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ನಮಸ್ಕಾರ!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'ಬಾ, ಕನ್ನಡ ಅಕ್ಷರ ಕಲಿಯೋಣ. Let’s learn Kannada letters.',
                        style: TextStyle(fontSize: 16, color: K.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _BlockGrid(
            children: [
              HomeBlock(
                glyph: 'ಅ',
                title: 'ಸ್ವರಗಳು',
                sub: 'Vowels · 13',
                color: K.red,
                base: K.redDeep,
                onTap: () => push(context, const VowelsScreen()),
              ),
              HomeBlock(
                glyph: 'ಕ',
                title: 'ವ್ಯಂಜನಗಳು',
                sub: 'Consonants · 34',
                color: K.blue,
                base: K.blueDeep,
                onTap: () => push(context, const ConsonantsScreen()),
              ),
              HomeBlock(
                glyph: 'ಕಾ',
                title: 'ಕಾಗುಣಿತ',
                sub: 'Letter + vowel sign',
                color: K.plum,
                base: K.plumDeep,
                onTap: () => push(context, KagunitaScreen(base: letters[15])),
              ),
              HomeBlock(
                glyph: '೩',
                title: 'ಅಂಕಿಗಳು',
                sub: 'Numbers ೦–೧೦',
                color: K.green,
                base: K.greenDeep,
                onTap: () => push(context, const NumbersScreen()),
              ),
              HomeBlock(
                glyph: '✏️',
                title: 'ಬರೆಯೋಣ',
                sub: 'Trace & write',
                color: K.turmeric,
                base: K.turmericDeep,
                fg: K.ink,
                onTap: () => push(context, const TraceMenuScreen()),
              ),
              HomeBlock(
                glyph: '🎈',
                title: 'ಆಟಗಳು',
                sub: '7 fun games',
                color: K.red,
                base: K.redDeep,
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
                          child: Text(
                            stickers[i],
                            style: const TextStyle(fontSize: 28),
                          ),
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
    required this.glyph,
    required this.title,
    required this.sub,
    required this.color,
    required this.base,
    required this.onTap,
    this.fg = K.white,
    this.glyphSize = 76,
  });

  final String glyph;
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
