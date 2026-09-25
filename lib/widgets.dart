import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'audio.dart';
import 'data.dart';
import 'state.dart';

/// Channapatna-toy palette: lacquer colours on an ivory ground.
class K {
  static const ivory = Color(0xFFFFF7E8);
  static const paper = Color(0xFFF7E9CF);
  static const ink = Color(0xFF2A1D14);
  static const inkSoft = Color(0xFF6B5646);
  static const red = Color(0xFFC8323C);
  static const redDeep = Color(0xFF9C2130);
  static const turmeric = Color(0xFFF2B21B);
  static const turmericDeep = Color(0xFFC98A00);
  static const green = Color(0xFF2F9A5A);
  static const greenDeep = Color(0xFF1F7442);
  static const blue = Color(0xFF1E6FB0);
  static const blueDeep = Color(0xFF145188);
  static const plum = Color(0xFF7A3E8E);
  static const plumDeep = Color(0xFF5A2A6B);
  static const orange = Color(0xFFF28C1B);
  static const white = Color(0xFFFFFDF8);
  static const shade = Color(0x2E2A1D14);

  static Color of(CardColor c) => switch (c) {
    CardColor.red => red,
    CardColor.blue => blue,
    CardColor.plum => plum,
    CardColor.green => green,
  };
}

/// A pressable toy block: flat face sitting on a darker base that sinks when tapped.
class Toy extends StatefulWidget {
  const Toy({
    super.key,
    required this.child,
    this.onTap,
    this.color = K.white,
    this.base = K.shade,
    this.radius = 20,
    this.depth = 6,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
    this.sound = true,
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

  @override
  State<Toy> createState() => _ToyState();
}

class _ToyState extends State<Toy> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final sink = _down ? widget.depth - 2 : 0.0;
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
          opacity: enabled ? 1 : .35,
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.depth),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 60),
              transform: Matrix4.translationValues(0, sink, 0),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.radius),
                boxShadow: [
                  BoxShadow(
                    color: widget.base,
                    offset: Offset(0, widget.depth - sink),
                    blurRadius: 0,
                  ),
                ],
              ),
              padding: widget.padding,
              child: widget.child,
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
          style: TextStyle(fontSize: size * .42, color: K.ink),
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
    radius: 18,
    depth: small ? 4 : 6,
    padding: EdgeInsets.fromLTRB(18, small ? 8 : 12, 18, small ? 4 : 8),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: small ? 16 : 19,
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 16, 2),
        decoration: BoxDecoration(
          color: K.turmeric,
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
    );
  }
}

/// Page frame: rangoli-dot ground, top bar with back button and stars.
class KidPage extends StatelessWidget {
  const KidPage({
    super.key,
    required this.title,
    this.sub,
    required this.child,
    this.back = true,
    this.scroll = true,
  });

  final String title;
  final String? sub;
  final Widget child;
  final bool back;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: child,
        ),
      ),
    );
    return Scaffold(
      backgroundColor: K.ivory,
      body: CustomPaint(
        painter: const _DotsPainter(),
        child: SafeArea(
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Row(
                      children: [
                        if (back) ...[
                          RoundButton(
                            '⬅️',
                            size: 50,
                            label: 'Back',
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 24,
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
                                    fontSize: 13.5,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = K.red.withValues(alpha: .10);
    for (double y = 13; y < size.height; y += 26) {
      for (double x = 13; x < size.width; x += 26) {
        canvas.drawCircle(Offset(x, y), 1.7, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.kn, this.en, {super.key});
  final String kn;
  final String en;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      children: [
        Text(
          kn,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            en.toUpperCase(),
            style: const TextStyle(
              fontSize: 12.5,
              color: K.inkSoft,
              letterSpacing: .6,
            ),
          ),
        ),
      ],
    ),
  );
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
        mainAxisSpacing: 10,
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
    required this.color,
    required this.onTap,
    this.done = false,
    this.caption,
    this.label,
  });

  final String ch;
  final Color color;
  final VoidCallback onTap;
  final bool done;
  final String? caption;
  final String? label;

  @override
  Widget build(BuildContext context) => Toy(
    onTap: onTap,
    radius: 18,
    depth: 5,
    semanticLabel: label ?? ch,
    child: Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FittedBox(
              child: Text(
                ch,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
        ),
        if (done)
          const Positioned(
            top: 4,
            right: 7,
            child: Text(
              '★',
              style: TextStyle(color: K.turmericDeep, fontSize: 14),
            ),
          ),
        if (caption != null)
          Positioned(
            bottom: 3,
            left: 0,
            right: 0,
            child: Text(
              caption!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: K.inkSoft),
            ),
          ),
      ],
    ),
  );
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
