import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio.dart';
import 'data.dart';
import 'widgets.dart';

/// When each ink pixel of a letter is drawn, in the real stroke order
/// (from the Wikimedia Commons writing animations; see
/// tool/make_writing_paths.py).
class WritingData {
  WritingData._(this.aspect, this.ink, this.time, this.head);

  /// Width / height of the letter.
  final double aspect;

  /// The letter in rainbow ink, coloured by when each part is written.
  final ui.Image ink;

  /// Red = when each pixel is written (0–254), 255 where there is no ink.
  final ui.Image time;

  /// Pen position over time: (t in 0–1, x, y in 0–1).
  final List<(double, double, double)> head;

  /// Pen paths: letters (strokes.json) and kagunita (kagunita.json).
  static final Map<String, Map<String, dynamic>> _json = {};
  static final Map<String, Future<WritingData?>> _cache = {};

  static bool has(String ch) =>
      letters.any((l) => l.ch == ch) || kagunitaParts(ch) != null;

  static Future<WritingData?> load(String ch) =>
      _cache[ch] ??= _load(ch).catchError((Object _) => null);

  static Future<ui.Image> _image(Uint8List rgba, int w, int h) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      w,
      h,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }

  static Future<WritingData?> _load(String ch) async {
    if (!has(ch)) return null;
    final file = kagunitaParts(ch) != null ? 'kagunita' : 'strokes';
    final paths = _json[file] ??= jsonDecode(
      await rootBundle.loadString('assets/writing/$file.json'),
    ) as Map<String, dynamic>;
    final info = paths[ch] as Map<String, dynamic>?;
    if (info == null) return null;
    final bytes = await rootBundle.load('assets/writing/${audioKey(ch)}.png');
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    final w = image.width, h = image.height;
    final src = (await image.toByteData())!.buffer.asUint8List();
    image.dispose();

    final ink = Uint8List(w * h * 4), time = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      final t = src[i * 4], a = src[i * 4 + 3];
      final c = _inkAt(t / 254);
      ink[i * 4] = (c.r * 255).round();
      ink[i * 4 + 1] = (c.g * 255).round();
      ink[i * 4 + 2] = (c.b * 255).round();
      ink[i * 4 + 3] = a;
      time[i * 4] = a < 8 ? 255 : t;
      time[i * 4 + 3] = 255;
    }
    final head = [
      for (final p in info['head'] as List)
        (
          (p[0] as num).toDouble(),
          (p[1] as num).toDouble(),
          (p[2] as num).toDouble(),
        ),
    ];
    return WritingData._(
      w / h,
      await _image(ink, w, h),
      await _image(time, w, h),
      head,
    );
  }

  /// Pen position at time [t] (0–1), in 0–1 coordinates.
  Offset headAt(double t) {
    if (head.isEmpty) return const Offset(.5, .5);
    if (t <= head.first.$1) return Offset(head.first.$2, head.first.$3);
    for (var i = 1; i < head.length; i++) {
      final b = head[i];
      if (t <= b.$1) {
        final a = head[i - 1];
        final f = b.$1 == a.$1 ? 1.0 : (t - a.$1) / (b.$1 - a.$1);
        return Offset(a.$2 + (b.$2 - a.$2) * f, a.$3 + (b.$3 - a.$3) * f);
      }
    }
    return Offset(head.last.$2, head.last.$3);
  }
}

/// Ink colours along the stroke: the letter fills with a rainbow in the
/// order it is written.
const _ink = [
  K.pink,
  K.red,
  K.orange,
  K.turmeric,
  K.green,
  K.teal,
  K.blue,
  K.plum,
];

Color _inkAt(double t) {
  final x = t.clamp(0.0, 1.0) * (_ink.length - 1);
  final i = x.floor().clamp(0, _ink.length - 2);
  return Color.lerp(_ink[i], _ink[i + 1], x - i)!;
}

/// Animated writing guide: a crayon writes [ch] stroke by stroke in
/// rainbow ink over a faint copy of the letter, then stars pop up.
class WritingGuide extends StatefulWidget {
  const WritingGuide(this.ch, {super.key, this.size = 280, this.speak = true});
  final String ch;
  final double size;

  /// Says the letter each time it is finished.
  final bool speak;

  @override
  State<WritingGuide> createState() => _WritingGuideState();
}

class _WritingGuideState extends State<WritingGuide>
    with SingleTickerProviderStateMixin {
  static const _drawMs = 3600, _holdMs = 1400;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _drawMs + _holdMs),
  );
  WritingData? _data;
  bool _said = false;

  @override
  void initState() {
    super.initState();
    WritingData.load(widget.ch).then((d) {
      if (!mounted || d == null) return;
      setState(() => _data = d);
      _c
        ..addListener(_tick)
        ..repeat();
    });
  }

  void _tick() {
    final done = _c.value * (_drawMs + _holdMs) >= _drawMs;
    if (done && !_said) {
      _said = true;
      if (widget.speak) {
        final say = sayingOf(widget.ch);
        if (say != null) Audio.instance.speak(say.$1, say.$2);
      }
    } else if (!done) {
      _said = false;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final s = widget.size;
    if (d == null) {
      return SizedBox.square(
        dimension: s,
        child: Center(
          child: Text(
            widget.ch,
            style: TextStyle(fontSize: s * .5, color: const Color(0xFFE6E0F0)),
          ),
        ),
      );
    }
    // Fit the letter inside the square.
    final w = d.aspect >= 1 ? s * .9 : s * .9 * d.aspect;
    final h = d.aspect >= 1 ? s * .9 / d.aspect : s * .9;
    final box = Rect.fromLTWH((s - w) / 2, (s - h) / 2, w, h);
    return Semantics(
      label: 'How to write ${widget.ch}',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final ms = _c.value * (_drawMs + _holdMs);
          final t = Curves.easeInOutSine.transform(
            (ms / _drawMs).clamp(0.0, 1.0),
          );
          final done = ms >= _drawMs;
          final pen = d.headAt(t);
          final penAt = Offset(
            box.left + pen.dx * box.width,
            box.top + pen.dy * box.height,
          );
          final pop = done
              ? Curves.elasticOut.transform(
                  ((ms - _drawMs) / 700).clamp(0.0, 1.0),
                )
              : 0.0;
          return SizedBox.square(
            dimension: s,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _GuidePainter(d, box, t, done)),
                ),
                if (!done)
                  // The crayon's tip is its bottom-left corner.
                  Positioned(
                    left: penAt.dx - 4,
                    top: penAt.dy - 40,
                    child: const IgnorePointer(child: Pic('✏️', size: 44)),
                  ),
                if (done)
                  for (final (dx, dy, sz) in const [
                    (.08, .06, 34.0),
                    (.82, .1, 28.0),
                    (.86, .76, 32.0),
                  ])
                    Positioned(
                      left: s * dx,
                      top: s * dy,
                      child: Transform.scale(
                        scale: pop,
                        child: Pic('🌟', size: sz),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.d, this.box, this.t, this.done);
  final WritingData d;
  final Rect box;
  final double t;
  final bool done;

  /// Softness of the ink's leading edge, in time steps (of 254).
  static const _soft = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      d.ink.width.toDouble(),
      d.ink.height.toDouble(),
    );
    final smooth = Paint()..filterQuality = FilterQuality.medium;

    // The whole letter, faint, so children see where the crayon is going.
    canvas.drawImageRect(
      d.ink,
      src,
      box,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = const ColorFilter.mode(
          Color(0xFFEDE7F6),
          BlendMode.srcIn,
        ),
    );
    // Rainbow ink, masked to the part written by time t: alpha falls from
    // 255 to 0 as a pixel's time goes past the threshold.
    final thr = t * 254 + _soft;
    const k = 255 / _soft;
    canvas.saveLayer(box.inflate(2), Paint());
    canvas.drawImageRect(d.ink, src, box, smooth);
    canvas.drawImageRect(
      d.time,
      src,
      box,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..blendMode = BlendMode.dstIn
        ..colorFilter = ColorFilter.matrix([
          0, 0, 0, 0, 0, //
          0, 0, 0, 0, 0, //
          0, 0, 0, 0, 0, //
          -k, 0, 0, 0, k * thr, //
        ]),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.t != t || old.done != done || old.d != d || old.box != box;
}
