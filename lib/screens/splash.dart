import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../widgets.dart';
import 'home.dart';

/// Opening animation. It starts exactly like the phone's launch screen (the
/// icon's ಅ badge on red), then the badge bounces, the red opens into the
/// sky, rainbow letters burst out, the title drops in and Aane walks on.
/// Tap to skip.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _ms = 3000;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _ms),
  );
  bool _left = false;
  bool _chimed = false;

  static const _letters = [
    'ಅ', 'ಆ', 'ಇ', 'ಉ', 'ಎ', 'ಒ', 'ಕ', 'ಗ', 'ಚ', 'ಜ', 'ತ', 'ನ', 'ಪ', 'ಮ', //
  ];

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_chimed && _c.value > .42) {
        _chimed = true;
        Audio.instance.win();
      }
    });
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduced motion: only the end of the animation, briefly.
    final still = MediaQuery.of(context).disableAnimations;
    _c.forward(from: still ? .9 : 0).whenComplete(_go);
  }

  void _go() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(
              begin: 1.06,
              end: 1.0,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0–1 progress of [t] through the window [a]–[b].
  static double _span(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC8323C),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final size = MediaQuery.of(context).size;
            final center = Offset(size.width / 2, size.height * .42);
            final logo = math.min(size.width * .38, 170.0);

            // Badge: a squash-and-stretch hop, then it moves up a little.
            final hop = _span(t, 0, .3);
            final badgeScale = hop < .35
                ? 1 - .12 * Curves.easeOut.transform(hop / .35)
                : .88 + .22 * Curves.elasticOut.transform((hop - .35) / .65);
            final rise = Curves.easeInOutCubic.transform(_span(t, .3, .55));

            // The red opens into the sky as a growing circle.
            final open = Curves.easeInOutCubic.transform(_span(t, .22, .5));
            final radius = open * size.longestSide * 1.2;

            // Letters burst out of the badge and float around it.
            final burst = Curves.easeOutBack.transform(_span(t, .3, .62));
            final title = Curves.elasticOut.transform(_span(t, .45, .85));
            final aane = Curves.easeOutCubic.transform(_span(t, .55, .85));
            final fade = 1 - _span(t, .93, 1);

            // Starts where the launch screen's badge is (150 wide, centred).
            final badgeCenter = Offset.lerp(
              Offset(size.width / 2, size.height / 2),
              center - Offset(0, size.height * .1),
              rise,
            )!;
            final logoNow = 150 + (logo - 150) * rise;
            return Opacity(
              opacity: fade,
              child: Stack(
                children: [
                  // Sky opening from the badge.
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _CircleClip(badgeCenter, radius),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [K.skyTop, K.skyMid, K.skyBottom],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Twinkling stars.
                  for (var i = 0; i < 10; i++)
                    Positioned(
                      left: size.width * ((i * 37 % 100) / 100),
                      top: size.height * ((i * 53 % 90) / 100),
                      child: Opacity(
                        opacity:
                            open *
                            (.4 +
                                .6 * (0.5 + 0.5 * math.sin(t * 18 + i * 1.7))),
                        child: Icon(
                          i.isEven ? Icons.star_rounded : Icons.auto_awesome,
                          size: 14.0 + (i % 3) * 6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  // Rainbow letters on a ring.
                  for (var i = 0; i < _letters.length; i++)
                    _letter(i, badgeCenter, logoNow, burst, t),
                  // The badge.
                  Positioned(
                    left: badgeCenter.dx - logoNow / 2,
                    top: badgeCenter.dy - logoNow / 2,
                    child: Transform.scale(
                      scale: badgeScale,
                      child: Container(
                        width: logoNow,
                        height: logoNow,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .18 * open),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/splash/logo.png',
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
                  // Title.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: badgeCenter.dy + logoNow * .95 + 40,
                    child: Opacity(
                      opacity: _span(t, .45, .6),
                      child: Transform.translate(
                        offset: Offset(0, 40 * (1 - title)),
                        child: Column(
                          children: [
                            Text(
                              'ಅಕ್ಷರ ಆಟ',
                              style: TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                                shadows: const [
                                  Shadow(
                                    color: Color(0xFF1F63D6),
                                    offset: Offset(0, 4),
                                  ),
                                  Shadow(
                                    color: Color(0x552B2140),
                                    offset: Offset(0, 8),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'Akshara Aata · Kannada Varnamala',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F4E9C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Aane walks on and waves.
                  Positioned(
                    left: -120 + aane * (size.width * .5 - 20),
                    bottom: size.height * .06,
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        -8 * math.sin(t * 40).abs() * (1 - aane),
                      ),
                      child: const Pic('🐘', size: 110),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _letter(int i, Offset center, double logo, double burst, double t) {
    final n = _letters.length;
    final angle = 2 * math.pi * i / n + t * 1.2;
    final r = logo * (.35 + .6 * burst) + 6 * math.sin(t * 9 + i);
    final (color, deep) = K.tint(i);
    final pos = center + Offset(math.cos(angle) * r, math.sin(angle) * r * .9);
    const box = 46.0;
    return Positioned(
      left: pos.dx - box / 2,
      top: pos.dy - box / 2,
      child: Opacity(
        opacity: burst.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: .4 + .6 * burst,
          child: Transform.rotate(
            angle: .25 * math.sin(t * 7 + i),
            child: Container(
              width: box,
              height: box,
              alignment: Alignment.center,
              padding: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: deep, offset: const Offset(0, 3))],
              ),
              child: Text(
                _letters[i],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleClip extends CustomClipper<Path> {
  _CircleClip(this.center, this.radius);
  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_CircleClip old) =>
      old.center != center || old.radius != radius;
}
