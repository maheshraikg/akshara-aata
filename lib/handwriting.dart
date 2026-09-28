import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'data.dart';

/// A letter's centre line as points in a unit square: position, direction
/// (as doubled-angle cos/sin, so a line and its reverse match) and when
/// each point is written (0–1).
class _Shape {
  _Shape(this.x, this.y, this.c, this.s, this.t);
  final Float64List x, y, c, s, t;
  int get length => x.length;
}

/// How a child's writing compares with the letter they were asked to write.
class WriteCheck {
  const WriteCheck({
    required this.passed,
    required this.best,
    required this.rank,
    required this.tooSmall,
  });

  final bool passed;

  /// The letter the writing looks most like.
  final String best;

  /// Where the asked-for letter came in the ranking (0 = best match).
  final int rank;

  /// Too little ink to judge.
  final bool tooSmall;
}

enum StrokeHint { ok, start, order }

/// On-device handwriting checker. Compares the child's strokes with the
/// centre lines of every letter (assets/writing/shapes.json, made by
/// tool/make_shapes.py) using a symmetric nearest-point distance on position
/// and line direction, so it tells ಬ from ಪ without any internet or model
/// download.
class Handwriting {
  Handwriting._(this._shapes);

  factory Handwriting.fromJson(Map<String, dynamic> json) =>
      Handwriting._(json.map((k, v) => MapEntry(k, _decode(v as List))));

  /// Must match GRID in tool/make_shapes.py.
  static const grid = 48;

  /// Weight of line direction against position.
  static const _dirWeight = .1;

  /// Neighbourhood for the line direction, in grid cells.
  static const _radius = 2.5;

  final Map<String, _Shape> _shapes;

  static Future<Handwriting>? _instance;

  static Future<Handwriting> load() => _instance ??= rootBundle
      .loadString('assets/writing/shapes.json')
      .then((s) => Handwriting.fromJson(jsonDecode(s) as Map<String, dynamic>));

  bool has(String ch) => _shapes.containsKey(ch);

  static _Shape _decode(List v) {
    final n = v.length ~/ 4;
    final x = Float64List(n), y = Float64List(n), c = Float64List(n);
    final s = Float64List(n), t = Float64List(n);
    for (var i = 0; i < n; i++) {
      x[i] = (v[i * 4] as num) / grid - .5;
      y[i] = (v[i * 4 + 1] as num) / grid - .5;
      final a = (v[i * 4 + 2] as num) * math.pi / 90;
      c[i] = math.cos(a) * _dirWeight;
      s[i] = math.sin(a) * _dirWeight;
      t[i] = (v[i * 4 + 3] as num) / 99;
    }
    return _Shape(x, y, c, s, t);
  }

  /// The child's strokes as a shape, plus which stroke each point is from.
  static (_Shape, Int32List)? _fromStrokes(List<List<Offset>> strokes) {
    final all = [for (final st in strokes) ...st];
    if (all.isEmpty) return null;
    var minX = all.first.dx, maxX = minX, minY = all.first.dy, maxY = minY;
    for (final p in all) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final side = math.max(maxX - minX, maxY - minY);
    if (side <= 0) return null;
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    Offset norm(Offset p) => Offset(
      ((p.dx - cx) / side + .5) * grid,
      ((p.dy - cy) / side + .5) * grid,
    );

    // Walk every stroke in half-cell steps; one point per grid cell.
    final cells = <int, int>{};
    final px = <double>[], py = <double>[], stroke = <int>[];
    void add(Offset p, int si) {
      final gx = p.dx.round(), gy = p.dy.round();
      if (cells.putIfAbsent(gx * 1000 + gy, () => px.length) != px.length) {
        return;
      }
      px.add(gx.toDouble());
      py.add(gy.toDouble());
      stroke.add(si);
    }

    for (var si = 0; si < strokes.length; si++) {
      final pts = strokes[si].map(norm).toList();
      if (pts.isEmpty) continue;
      add(pts.first, si);
      for (var i = 1; i < pts.length; i++) {
        final a = pts[i - 1], b = pts[i];
        final steps = ((b - a).distance / .5).ceil();
        for (var k = 1; k <= steps; k++) {
          add(Offset.lerp(a, b, k / steps)!, si);
        }
      }
    }

    final n = px.length;
    final x = Float64List(n), y = Float64List(n), c = Float64List(n);
    final s = Float64List(n);
    for (var i = 0; i < n; i++) {
      x[i] = px[i] / grid - .5;
      y[i] = py[i] / grid - .5;
      // Direction of the line here: main axis of the nearby points.
      var mx = 0.0, my = 0.0, cnt = 0;
      for (var j = 0; j < n; j++) {
        final dx = px[j] - px[i], dy = py[j] - py[i];
        if (dx * dx + dy * dy <= _radius * _radius) {
          mx += px[j];
          my += py[j];
          cnt++;
        }
      }
      mx /= cnt;
      my /= cnt;
      var sxx = 0.0, syy = 0.0, sxy = 0.0;
      for (var j = 0; j < n; j++) {
        final dx = px[j] - px[i], dy = py[j] - py[i];
        if (dx * dx + dy * dy <= _radius * _radius) {
          final ux = px[j] - mx, uy = py[j] - my;
          sxx += ux * ux;
          syy += uy * uy;
          sxy += ux * uy;
        }
      }
      // Doubled angle of the main axis: cos 2a, sin 2a ∝ (sxx - syy, 2 sxy).
      final len = math.sqrt((sxx - syy) * (sxx - syy) + 4 * sxy * sxy);
      c[i] = len == 0 ? 0 : (sxx - syy) / len * _dirWeight;
      s[i] = len == 0 ? 0 : 2 * sxy / len * _dirWeight;
    }
    return (_Shape(x, y, c, s, Float64List(n)), Int32List.fromList(stroke));
  }

  /// Mean distance from each point of [a] to the nearest point of [b], and
  /// back.
  static double _distance(_Shape a, _Shape b) {
    final toB = Float64List(a.length)..fillRange(0, a.length, 1e9);
    final toA = Float64List(b.length)..fillRange(0, b.length, 1e9);
    for (var i = 0; i < a.length; i++) {
      for (var j = 0; j < b.length; j++) {
        final dx = a.x[i] - b.x[j], dy = a.y[i] - b.y[j];
        final dc = a.c[i] - b.c[j], ds = a.s[i] - b.s[j];
        final d = dx * dx + dy * dy + dc * dc + ds * ds;
        if (d < toB[i]) toB[i] = d;
        if (d < toA[j]) toA[j] = d;
      }
    }
    var sum = 0.0;
    for (final d in toB) {
      sum += math.sqrt(d);
    }
    var back = 0.0;
    for (final d in toA) {
      back += math.sqrt(d);
    }
    return sum / a.length + back / b.length;
  }

  /// Letters a child might mix up with [target]: all 49 letters for a
  /// letter, and the consonant's kagunita forms for a kagunita.
  List<String> candidatesFor(String target) {
    final k = kagunitaParts(target);
    final list = k == null
        ? [for (final l in letters) l.ch]
        : [k.$1.ch, for (final s in signs.skip(1)) k.$1.ch + s.sign];
    return list.where(has).toList();
  }

  /// Letters ranked by how much [strokes] look like them, best first.
  List<(String, double)> rank(
    List<List<Offset>> strokes,
    List<String> candidates,
  ) {
    final child = _fromStrokes(strokes)?.$1;
    if (child == null) return const [];
    return [
      for (final ch in candidates)
        if (_shapes[ch] case final s?) (ch, _distance(child, s)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
  }

  /// Checks whether [strokes] look like [target]. Children pass when the
  /// target is among the three closest letters, nearly as close as the
  /// best, and the writing is close enough not to be a scribble.
  WriteCheck check(String target, List<List<Offset>> strokes) {
    final child = _fromStrokes(strokes);
    if (child == null || child.$1.length < 12 || !has(target)) {
      return WriteCheck(passed: false, best: '', rank: -1, tooSmall: true);
    }
    final ranked = rank(strokes, candidatesFor(target));
    final i = ranked.indexWhere((r) => r.$1 == target);
    final d = ranked[i].$2, best = ranked.first.$2;
    return WriteCheck(
      passed: i < 3 && d <= best * 1.2 && d < .2,
      best: ranked.first.$1,
      rank: i,
      tooSmall: false,
    );
  }

  /// Where [target] is first written, in 0–1 of its box.
  Offset startOf(String target) {
    final s = _shapes[target]!;
    var k = 0;
    for (var i = 1; i < s.length; i++) {
      if (s.t[i] < s.t[k]) k = i;
    }
    return Offset(s.x[k] + .5, s.y[k] + .5);
  }

  /// Compares the order of the child's strokes with the real stroke order:
  /// each point of the writing takes the time of the nearest point of the
  /// letter.
  StrokeHint strokeHint(String target, List<List<Offset>> strokes) {
    final shape = _shapes[target];
    final child = _fromStrokes(strokes);
    if (shape == null || child == null) return StrokeHint.ok;
    final (c, stroke) = child;
    double timeAt(int i) {
      var best = 1e9, t = 0.0;
      for (var j = 0; j < shape.length; j++) {
        final dx = c.x[i] - shape.x[j], dy = c.y[i] - shape.y[j];
        final d = dx * dx + dy * dy;
        if (d < best) {
          best = d;
          t = shape.t[j];
        }
      }
      return t;
    }

    // Median time of each stroke, and the time where the first one starts.
    final times = <int, List<double>>{};
    for (var i = 0; i < c.length; i++) {
      (times[stroke[i]] ??= []).add(timeAt(i));
    }
    final firstStroke = times.keys.reduce(math.min);
    if (times[firstStroke]!.first > .3) return StrokeHint.start;
    final medians = [
      for (final k in times.keys.toList()..sort())
        (times[k]!..sort())[times[k]!.length ~/ 2],
    ];
    for (var i = 1; i < medians.length; i++) {
      if (medians[i] < medians[i - 1] - .15) return StrokeHint.order;
    }
    return StrokeHint.ok;
  }
}

/// "Start at the top left" for a start point in the letter's box: Kannada
/// and English.
(String, String) startHint(Offset p) {
  final v = p.dy < .38 ? 0 : (p.dy > .62 ? 2 : 1);
  final h = p.dx < .38 ? 0 : (p.dx > .62 ? 2 : 1);
  const vKn = ['ಮೇಲೆ', 'ಮಧ್ಯ', 'ಕೆಳಗೆ'],
      vKnFrom = ['ಮೇಲಿನಿಂದ', 'ಮಧ್ಯದಿಂದ', 'ಕೆಳಗಿನಿಂದ'];
  const vEn = ['top', 'middle', 'bottom'];
  const hKn = ['ಎಡದಿಂದ', '', 'ಬಲದಿಂದ'], hEn = ['left', '', 'right'];
  return h == 1
      ? ('${vKnFrom[v]} ಶುರು ಮಾಡು', 'Start at the ${vEn[v]}')
      : ('${vKn[v]} ${hKn[h]} ಶುರು ಮಾಡು', 'Start at the ${vEn[v]} ${hEn[h]}');
}
