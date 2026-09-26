import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ads.dart';
import 'audio.dart';
import 'data.dart';
import 'state.dart';

/// Bright "candy toy" palette on a sunny sky. Every colour has a deeper
/// partner used for the 3D base under buttons.
class K {
  static const ivory = Color(0xFFFFF8EC);
  static const paper = Color(0xFFFFEFD2);
  static const ink = Color(0xFF2B2140);
  static const inkSoft = Color(0xFF6E6388);
  static const red = Color(0xFFFF5D73);
  static const redDeep = Color(0xFFD63A55);
  static const turmeric = Color(0xFFFFC53D);
  static const turmericDeep = Color(0xFFE09600);
  static const green = Color(0xFF2FC27A);
  static const greenDeep = Color(0xFF1B9357);
  static const blue = Color(0xFF3D8BFF);
  static const blueDeep = Color(0xFF1F63D6);
  static const plum = Color(0xFF9B6BFF);
  static const plumDeep = Color(0xFF6E43D6);
  static const orange = Color(0xFFFF9636);
  static const orangeDeep = Color(0xFFDD6F0C);
  static const pink = Color(0xFFFF77C3);
  static const pinkDeep = Color(0xFFDB4C9D);
  static const teal = Color(0xFF1FC7C1);
  static const tealDeep = Color(0xFF0F9994);
  static const white = Color(0xFFFFFFFF);
  static const shade = Color(0x262B2140);
  static const skyTop = Color(0xFF8FD3FF);
  static const skyMid = Color(0xFFD4F0FF);
  static const skyBottom = Color(0xFFFFF4DA);

  static const rainbow = <(Color, Color)>[
    (red, redDeep),
    (orange, orangeDeep),
    (turmeric, turmericDeep),
    (green, greenDeep),
    (teal, tealDeep),
    (blue, blueDeep),
    (plum, plumDeep),
    (pink, pinkDeep),
  ];

  /// A stable rainbow colour for any text (same letter, same colour).
  static (Color, Color) tintFor(String s) {
    var h = 0;
    for (final r in s.runes) {
      h = (h * 31 + r) & 0x7fffffff;
    }
    return rainbow[h % rainbow.length];
  }

  static (Color, Color) tint(int i) => rainbow[i % rainbow.length];

  static Color of(CardColor c) => switch (c) {
    CardColor.red => red,
    CardColor.blue => blue,
    CardColor.plum => plum,
    CardColor.green => green,
  };

  static Color deepOf(CardColor c) => switch (c) {
    CardColor.red => redDeep,
    CardColor.blue => blueDeep,
    CardColor.plum => plumDeep,
    CardColor.green => greenDeep,
  };

  static Color lighten(Color c, double by) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + by).clamp(0.0, 1.0)).toColor();
  }

  /// Soft pastel version for large backgrounds.
  static Color pastel(Color c, [double t = .16]) => Color.lerp(white, c, t)!;
}

/// A pressable candy-toy button: glossy gradient face on a deeper base that
/// sinks and squishes when tapped.
class Toy extends StatefulWidget {
  const Toy({
    super.key,
    required this.child,
    this.onTap,
    this.color = K.white,
    this.base = K.shade,
    this.radius = 22,
    this.depth = 6,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
    this.sound = true,
    this.gloss = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color base;
  final double radius;
  final double depth;
  final EdgeInsets padding;
  final String? semanticLabel;
  final bool sound;
  final bool gloss;

  @override
  State<Toy> createState() => _ToyState();
}

class _ToyState extends State<Toy> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final sink = _down ? widget.depth - 2 : 0.0;
    final light = widget.color.computeLuminance() > .8;
    final r = BorderRadius.circular(widget.radius);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                if (widget.sound) Audio.instance.tap();
                widget.onTap!();
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : .4,
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.depth),
            child: AnimatedScale(
              scale: _down ? .96 : 1,
              duration: const Duration(milliseconds: 90),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                transform: Matrix4.translationValues(0, sink, 0),
                decoration: BoxDecoration(
                  color: widget.color,
                  gradient: light
                      ? null
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [K.lighten(widget.color, .07), widget.color],
                        ),
                  borderRadius: r,
                  boxShadow: [
                    BoxShadow(
                      color: widget.base,
                      offset: Offset(0, widget.depth - sink),
                    ),
                    BoxShadow(
                      color: const Color(0x1F2B2140),
                      offset: Offset(0, widget.depth - sink + 5),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    Padding(padding: widget.padding, child: widget.child),
                    if (widget.gloss && !light)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: FractionallySizedBox(
                              widthFactor: .86,
                              heightFactor: .42,
                              child: Container(
                                margin: const EdgeInsets.only(top: 3),
                                decoration: BoxDecoration(
                                  borderRadius: r,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: .38),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button (back, listen, next…).
class RoundButton extends StatelessWidget {
  const RoundButton(
    this.icon, {
    super.key,
    required this.onTap,
    this.color = K.white,
    this.base = K.shade,
    this.size = 58,
    this.label,
  });

  final String icon;
  final VoidCallback? onTap;
  final Color color;
  final Color base;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) => Toy(
    onTap: onTap,
    color: color,
    base: base,
    radius: size,
    semanticLabel: label,
    child: SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          icon,
          style: TextStyle(
            fontSize: size * .42,
            color: color.computeLuminance() > .8 ? K.ink : Colors.white,
          ),
        ),
      ),
    ),
  );
}

/// Wide text button.
class PillButton extends StatelessWidget {
  const PillButton(
    this.text, {
    super.key,
    required this.onTap,
    this.color = K.blue,
    this.base = K.blueDeep,
    this.fg = K.white,
    this.small = false,
  });

  final String text;
  final VoidCallback? onTap;
  final Color color;
  final Color base;
  final Color fg;
  final bool small;

  @override
  Widget build(BuildContext context) => Toy(
    onTap: onTap,
    color: color,
    base: base,
    radius: 22,
    depth: small ? 4 : 6,
    padding: EdgeInsets.fromLTRB(20, small ? 9 : 13, 20, small ? 5 : 9),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: small ? 16 : 20,
        fontWeight: FontWeight.w800,
        color: fg,
      ),
    ),
  );
}

class StarsPill extends StatelessWidget {
  const StarsPill({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Semantics(
      label: '${s.stars} stars',
      child: TweenAnimationBuilder<double>(
        // Re-keys on every new star, so the pill bounces when stars arrive.
        key: ValueKey(s.stars),
        tween: Tween(begin: 1.25, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 14, 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFD86B), K.turmeric],
            ),
            borderRadius: BorderRadius.circular(99),
            boxShadow: const [
              BoxShadow(color: K.turmericDeep, offset: Offset(0, 4)),
            ],
          ),
          child: Text(
            '⭐ ${s.stars}',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: K.ink,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// Page frame: sunny sky with clouds, a floating top bar with back button
/// and stars, and an optional banner ad at the bottom.
class KidPage extends StatelessWidget {
  const KidPage({
    super.key,
    required this.title,
    this.sub,
    required this.child,
    this.back = true,
    this.scroll = true,
    this.ad = false,
  });

  final String title;
  final String? sub;
  final Widget child;
  final bool back;
  final bool scroll;

  /// Show a banner ad at the bottom. Only for menu screens, never during
  /// learning, tracing or a game.
  final bool ad;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: child,
        ),
      ),
    );
    return Scaffold(
      backgroundColor: K.skyBottom,
      body: CustomPaint(
        painter: const _SkyPainter(),
        child: SafeArea(
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .82),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A2B2140),
                          offset: Offset(0, 4),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (back) ...[
                          RoundButton(
                            '⬅️',
                            size: 46,
                            label: 'Back',
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 10),
                        ] else
                          const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              if (sub != null)
                                Text(
                                  sub!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: K.inkSoft,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const StarsPill(),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: scroll ? SingleChildScrollView(child: content) : content,
              ),
              if (ad) const BannerAdSlot(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sky gradient with soft clouds, a sun and faint floating Kannada letters.
class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  static const _floaters = ['ಅ', 'ಕ', 'ಆ', 'ಮ', 'ಇ', 'ನ', 'ಉ', 'ಗ'];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [K.skyTop, K.skyMid, K.skyBottom],
          stops: [0, .35, .8],
        ).createShader(rect),
    );
    // sun
    final sunC = Offset(size.width - 40, 40);
    canvas.drawCircle(
      sunC,
      70,
      Paint()..color = const Color(0xFFFFE27A).withValues(alpha: .35),
    );
    canvas.drawCircle(
      sunC,
      42,
      Paint()..color = const Color(0xFFFFE27A).withValues(alpha: .7),
    );
    // clouds
    final cloud = Paint()..color = Colors.white.withValues(alpha: .75);
    void puff(double x, double y, double s) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 90 * s, height: 34 * s),
        cloud,
      );
      canvas.drawCircle(Offset(x - 16 * s, y - 10 * s), 20 * s, cloud);
      canvas.drawCircle(Offset(x + 12 * s, y - 14 * s), 24 * s, cloud);
    }

    puff(size.width * .18, size.height * .16, 1);
    puff(size.width * .78, size.height * .33, .8);
    puff(size.width * .3, size.height * .55, .7);
    puff(size.width * .85, size.height * .72, .9);
    // faint letters
    for (var i = 0; i < _floaters.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: _floaters[i],
          style: TextStyle(
            fontFamily: 'BalooTamma2',
            fontWeight: FontWeight.w800,
            fontSize: 44 + (i % 3) * 14,
            color: K.rainbow[i].$1.withValues(alpha: .10),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (i * 0.37 % 1) * (size.width - 40);
      final y = ((i * 0.23 + .12) % 1) * size.height;
      tp.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => false;
}

/// Pops a child in with a springy scale when it first appears.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = 0});
  final Widget child;

  /// 0–1 fraction of the animation to wait before starting (for staggering).
  final double delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 550 + (delay * 400).round()),
      builder: (_, t, c) {
        final v = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
        final s = .5 + .5 * Curves.elasticOut.transform(v);
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: s, child: c),
        );
      },
      child: child,
    );
  }
}

/// Gentle endless up-and-down bob (mascots, pictures).
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child, this.height = 6, this.ms = 1400});
  final Widget child;
  final double height;
  final int ms;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.ms),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          0,
          -widget.height * Curves.easeInOut.transform(_c.value),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.kn, this.en, {super.key});
  final String kn;
  final String en;

  @override
  Widget build(BuildContext context) {
    final (c, deep) = K.tintFor(kn);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(99),
              boxShadow: [BoxShadow(color: deep, offset: const Offset(0, 3))],
            ),
            child: Text(
              kn,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              en.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: K.inkSoft,
                letterSpacing: .8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid of square letter tiles.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.min = 76});
  final List<Widget> children;
  final double min;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = math.max(3, (c.maxWidth / min).floor());
      return GridView.count(
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      );
    },
  );
}

class LetterTile extends StatelessWidget {
  const LetterTile(
    this.ch, {
    super.key,
    this.color,
    required this.onTap,
    this.done = false,
    this.caption,
    this.label,
  });

  final String ch;

  /// Kept for call sites; tiles now use a stable rainbow colour per letter.
  final Color? color;
  final VoidCallback onTap;
  final bool done;
  final String? caption;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (c, deep) = K.tintFor(ch);
    return PopIn(
      delay: (ch.runes.first % 7) / 20,
      child: Toy(
        onTap: onTap,
        color: K.pastel(c, .18),
        base: K.pastel(deep, .55),
        radius: 22,
        depth: 5,
        semanticLabel: label ?? ch,
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 6,
                  bottom: caption == null ? 0 : 10,
                ),
                child: FittedBox(
                  child: Text(
                    ch,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: deep,
                    ),
                  ),
                ),
              ),
            ),
            if (done)
              const Positioned(
                top: 3,
                right: 6,
                child: Text('⭐', style: TextStyle(fontSize: 13)),
              ),
            if (caption != null)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: deep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void toast(BuildContext context, String msg) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m != null) _showToast(m, msg);
}

void _showToast(ScaffoldMessengerState m, String msg) {
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(
        msg,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: K.white,
        ),
      ),
      backgroundColor: K.ink,
      behavior: SnackBarBehavior.floating,
      shape: const StadiumBorder(),
      duration: const Duration(milliseconds: 1800),
    ),
  );
}

/// Gives stars and announces a new sticker.
void reward(BuildContext context, int stars) {
  final sticker = AppScope.read(context).addStars(stars);
  if (sticker == null) return;
  // The messenger outlives this screen (games swap to the result screen).
  final messenger = ScaffoldMessenger.maybeOf(context);
  Future.delayed(const Duration(milliseconds: 900), () {
    if (messenger != null && messenger.mounted) {
      _showToast(messenger, 'ಹೊಸ ಸ್ಟಿಕ್ಕರ್! New sticker $sticker');
    }
  });
}

/// Short burst of paper confetti over the whole screen.
void showConfetti(BuildContext context) {
  if (MediaQuery.of(context).disableAnimations) return;
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _Confetti(
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    ),
  );
  overlay.insert(entry);
}

class _Confetti extends StatefulWidget {
  const _Confetti({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1800),
        )
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        })
        ..forward();
  final _rnd = math.Random();
  late final List<List<double>> _parts = List.generate(
    110,
    (_) => [
      (_rnd.nextDouble() - .5) * 1300, // vx px/s
      -_rnd.nextDouble() * 1000 - 350, // vy px/s
      6 + _rnd.nextDouble() * 8, // size
      _rnd.nextDouble() * 6, // rotation
      _rnd.nextInt(5).toDouble(), // colour
    ],
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => CustomPaint(
      size: Size.infinite,
      painter: _ConfettiPainter(_parts, _c.value * 1.8),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.parts, this.t);
  final List<List<double>> parts;
  final double t;
  static const colors = [K.red, K.turmeric, K.green, K.blue, K.plum];

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * .35);
    final paint = Paint();
    for (final p in parts) {
      final pos = origin + Offset(p[0] * t, p[1] * t + 1400 * t * t);
      paint.color = colors[p[4].toInt()];
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p[3] + t * 8);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p[2], height: p[2] / 2),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
