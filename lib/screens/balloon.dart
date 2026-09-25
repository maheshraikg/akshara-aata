import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio.dart';
import '../data.dart';
import '../widgets.dart';
import 'games.dart';

class _Balloon {
  _Balloon(this.letter, this.x, this.y, this.speed, this.wobble, this.color);
  final Letter letter;
  final double x;
  double y;
  final double speed;
  final double wobble;
  final Color color;
  bool popped = false;
  double popT = 0;
  double shake = 0;
}

/// Pop only the balloons carrying the target letter.
class BalloonScreen extends StatefulWidget {
  const BalloonScreen({super.key});
  static const goal = 8;

  @override
  State<BalloonScreen> createState() => _BalloonScreenState();
}

class _BalloonScreenState extends State<BalloonScreen>
    with SingleTickerProviderStateMixin {
  final _rnd = math.Random();
  late final List<Letter> _pool = pick([
    byGroup(Group.swara),
    byGroup(Group.vyanjana).sublist(0, 15),
    byGroup(Group.vyanjana).sublist(15),
  ]);
  late final Letter _target = pick(_pool);
  final List<_Balloon> _balloons = [];
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _clock = 0;
  double _spawnAt = 0;
  int _popped = 0;
  Size _sky = const Size(300, 480);
  bool _over = false;

  static const _colors = [K.red, K.blue, K.green, K.plum, K.orange];
  static const _w = 78.0, _h = 94.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    Future.delayed(const Duration(milliseconds: 300), _say);
  }

  void _say() {
    if (mounted) Audio.instance.speak(_target.ch, _target.tr);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero
        ? 0.0
        : math.min(.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    _clock += dt;
    if (!_over && _clock > _spawnAt) {
      final isTarget = _rnd.nextDouble() < .4;
      final l = isTarget
          ? _target
          : pick(_pool.where((x) => x != _target).toList());
      _balloons.add(
        _Balloon(
          l,
          8 + _rnd.nextDouble() * math.max(10, _sky.width - _w - 16),
          _sky.height + 10,
          55 + _rnd.nextDouble() * 45 + _popped * 4,
          _rnd.nextDouble() * 6,
          _colors[_rnd.nextInt(_colors.length)],
        ),
      );
      _spawnAt = _clock + .9 - math.min(.4, _popped * .03);
    }
    for (final b in _balloons) {
      if (b.popped) {
        b.popT += dt;
      } else {
        b.y -= b.speed * dt;
      }
      if (b.shake > 0) b.shake = math.max(0, b.shake - dt);
    }
    _balloons.removeWhere((b) => b.y < -_h - 50 || b.popT > .25);
    setState(() {});
  }

  void _hit(_Balloon b) {
    if (b.popped || _over) return;
    if (b.letter == _target) {
      b.popped = true;
      Audio.instance.pop();
      _popped++;
      if (_popped >= BalloonScreen.goal) {
        _over = true;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            finishGame(
              context,
              Game.balloon,
              BalloonScreen.goal,
              BalloonScreen.goal,
            );
          }
        });
      }
    } else {
      b.shake = .3;
      Audio.instance.wrong();
      Audio.instance.speak(b.letter.ch, b.letter.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KidPage(
      title: 'ಬಲೂನ್ ಆಟ',
      sub: 'Pop only the balloons with this letter',
      scroll: false,
      child: Column(
        children: [
          Row(
            children: [
              PillButton('${_target.ch} 🔊', onTap: _say),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _popped / BalloonScreen.goal,
                    minHeight: 14,
                    color: K.turmeric,
                    backgroundColor: K.paper,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$_popped/${BalloonScreen.goal}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                _sky = Size(c.maxWidth, c.maxHeight);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFBFE3FF),
                          Color(0xFFEAF6FF),
                          Color(0xFFD8F0D2),
                        ],
                        stops: [0, .7, 1],
                      ),
                    ),
                    child: Stack(
                      children: [
                        for (final b in _balloons)
                          Positioned(
                            left:
                                b.x +
                                math.sin(_clock * 2 + b.wobble) * 8 +
                                math.sin(b.shake * 40) *
                                    8 *
                                    (b.shake > 0 ? 1 : 0),
                            top: b.y,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (_) => _hit(b),
                              child: Opacity(
                                opacity: b.popped
                                    ? math.max(0, 1 - b.popT * 4)
                                    : 1,
                                child: Transform.scale(
                                  scale: 1 + b.popT * 2.4,
                                  child: _BalloonShape(b),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BalloonShape extends StatelessWidget {
  const _BalloonShape(this.b);
  final _Balloon b;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Balloon ${b.letter.tr}',
    child: SizedBox(
      width: 78,
      height: 130,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 92,
            child: Container(
              width: 2,
              height: 36,
              color: const Color(0x592A1D14),
            ),
          ),
          Container(
            width: 78,
            height: 94,
            decoration: BoxDecoration(
              color: b.color,
              borderRadius: const BorderRadius.all(Radius.elliptical(39, 47)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  offset: Offset(-6, -8),
                  spreadRadius: -6,
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              b.letter.ch,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: K.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
