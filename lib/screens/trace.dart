import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../data.dart';
import '../main.dart';
import '../state.dart';
import '../widgets.dart';
import 'learn.dart';

class TraceMenuScreen extends StatelessWidget {
  const TraceMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final v = vowelCards, c = consonantCards, n = numberCards.sublist(0, 10);
    List<Widget> tiles(List<CardItem> items) => [
      for (var i = 0; i < items.length; i++)
        LetterTile(
          items[i].ch,
          color: K.of(items[i].color),
          done: s.traced.contains(items[i].ch),
          label: items[i].sayRoman,
          onTap: () => push(context, TraceScreen(items: items, index: i)),
        ),
    ];
    return KidPage(
      title: 'ಬರೆಯೋಣ',
      sub: 'Pick a letter to write',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('ಸ್ವರಗಳು', 'Vowels'),
          TileGrid(children: tiles(v)),
          const SectionTitle('ವ್ಯಂಜನಗಳು', 'Consonants'),
          TileGrid(children: tiles(c)),
          const SectionTitle('ಅಂಕಿಗಳು', 'Numbers'),
          TileGrid(children: tiles(n)),
        ],
      ),
    );
  }
}

class _Stroke {
  _Stroke(this.color);
  final Color color;
  final List<Offset> points = [];
}

const _crayons = [K.red, K.blue, K.green, K.plum, K.orange];

/// Where and how big the letter sits in a square of side [size].
class LetterLayout {
  LetterLayout(this.ch, this.size) {
    var fs = size * .62;
    var tp = _painter(fs);
    final scale = math.min(
      1.0,
      math.min(size * .78 / tp.width, size * .82 / tp.height),
    );
    if (scale < 1) {
      fs *= scale;
      tp = _painter(fs);
    }
    fontSize = fs;
    offset = Offset((size - tp.width) / 2, (size - tp.height) / 2);
  }

  final String ch;
  final double size;
  late final double fontSize;
  late final Offset offset;

  TextPainter _painter(double fs, [Paint? fg]) => TextPainter(
    text: TextSpan(
      text: ch,
      style: TextStyle(
        fontFamily: 'BalooTamma2',
        fontWeight: FontWeight.w800,
        fontSize: fs,
        height: 1.25,
        foreground: fg,
        color: fg == null ? const Color(0xFFEEE2CC) : null,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void paint(Canvas canvas, {Paint? fg}) =>
      _painter(fontSize, fg).paint(canvas, offset);
}

class TraceScreen extends StatefulWidget {
  const TraceScreen({super.key, required this.items, required this.index});
  final List<CardItem> items;
  final int index;

  @override
  State<TraceScreen> createState() => _TraceScreenState();
}

class _TraceScreenState extends State<TraceScreen> {
  final List<_Stroke> _strokes = [];
  Color _crayon = K.red;
  String _msg = '';
  double _size = 300;
  bool _checking = false;

  CardItem get item => widget.items[widget.index];
  double get _brush => _size * .065;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Audio.instance.speak(item.say, item.sayRoman);
    });
  }

  void _go(int i) {
    if (i < 0 || i >= widget.items.length) return;
    replace(context, TraceScreen(items: widget.items, index: i));
  }

  Future<void> _check() async {
    if (_checking) return;
    if (_strokes.isEmpty) {
      setState(() => _msg = 'ಬೆರಳಿನಿಂದ ಬರೆ ✍️ Draw with your finger');
      Audio.instance.speak(item.say, item.sayRoman);
      return;
    }
    _checking = true;
    final score = await scoreTracing(
      item.ch,
      _size,
      _brush,
      _strokes.map((s) => s.points).toList(),
    );
    _checking = false;
    if (!mounted) return;
    final state = AppScope.read(context);
    if (score.passed) {
      final first = state.markTraced(item.ch);
      Audio.instance.win();
      showConfetti(context);
      setState(
        () => _msg =
            praise[math.Random().nextInt(praise.length)] +
            (first ? ' +2 ⭐' : ''),
      );
      if (first) reward(context, 2);
      Audio.instance.speak(item.say, item.sayRoman);
    } else {
      Audio.instance.wrong();
      setState(
        () => _msg = score.accuracy < .7
            ? 'ಗೆರೆಯ ಒಳಗೆ ಬರೆ · Stay inside the letter'
            : 'ಇನ್ನೂ ಸ್ವಲ್ಪ! · Colour the whole letter',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return KidPage(
      title: 'ಬರೆ: ${item.ch}',
      sub: 'Trace over the grey letter',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final side = math.min(c.maxWidth, 440.0);
              if (side != _size && _strokes.isEmpty) _size = side;
              return Center(
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    color: K.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(color: K.shade, offset: Offset(0, 6)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: GestureDetector(
                      // Pan wins the gesture arena over the page scroll, so
                      // drawing downwards doesn't scroll the screen.
                      onPanDown: (d) => setState(() {
                        _strokes.add(
                          _Stroke(_crayon)..points.add(d.localPosition),
                        );
                      }),
                      onPanUpdate: (d) => setState(
                        () => _strokes.last.points.add(d.localPosition),
                      ),
                      child: CustomPaint(
                        size: Size.square(_size),
                        painter: _TracePainter(
                          LetterLayout(item.ch, _size),
                          _strokes,
                          _brush,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final c in _crayons)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Semantics(
                    button: true,
                    selected: c == _crayon,
                    label: 'Crayon colour',
                    child: GestureDetector(
                      onTap: () => setState(() => _crayon = c),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == _crayon ? K.ink : K.white,
                            width: 4,
                          ),
                          boxShadow: const [
                            BoxShadow(color: K.shade, offset: Offset(0, 3)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              height: 30,
              child: Text(
                _msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RoundButton(
                '◀',
                label: 'Previous',
                onTap: widget.index > 0 ? () => _go(widget.index - 1) : null,
              ),
              RoundButton(
                '🧽',
                label: 'Clear',
                onTap: () => setState(() {
                  _strokes.clear();
                  _msg = '';
                }),
              ),
              PillButton(
                '✔ ಆಯ್ತು',
                color: K.green,
                base: K.greenDeep,
                onTap: _check,
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
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.layout, this.strokes, this.brush);
  final LetterLayout layout;
  final List<_Stroke> strokes;
  final double brush;

  @override
  void paint(Canvas canvas, Size size) {
    // copybook ruling
    final rule = Paint()
      ..color = K.blue.withValues(alpha: .18)
      ..strokeWidth = 2;
    for (final f in [.2, .8]) {
      canvas.drawLine(
        Offset(0, size.height * f),
        Offset(size.width, size.height * f),
        rule,
      );
    }
    layout.paint(canvas);
    layout.paint(
      canvas,
      fg: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFC9B48F),
    );
    for (final s in strokes) {
      drawStroke(canvas, s.points, s.color, brush);
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) => true;
}

void drawStroke(Canvas canvas, List<Offset> pts, Color color, double brush) {
  if (pts.isEmpty) return;
  final paint = Paint()
    ..color = color
    ..strokeWidth = brush
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  if (pts.length == 1) {
    canvas.drawCircle(pts.first, brush / 2, paint..style = PaintingStyle.fill);
    return;
  }
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final p in pts.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path, paint);
}

class TraceScore {
  const TraceScore(this.coverage, this.accuracy);

  /// Share of the letter's pixels the child coloured.
  final double coverage;

  /// Share of the child's ink that stayed on (or near) the letter.
  final double accuracy;
  bool get passed => coverage >= .5 && accuracy >= .7;
}

/// Renders letter, tolerance band and ink at low resolution and compares them.
Future<TraceScore> scoreTracing(
  String ch,
  double size,
  double brush,
  List<List<Offset>> strokes,
) async {
  const n = 160;
  final k = n / size;
  final layout = LetterLayout(ch, size);

  Future<Uint8List> render(void Function(Canvas c) draw) async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)..scale(k);
    draw(canvas);
    final img = await rec.endRecording().toImage(n, n);
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    return data!.buffer.asUint8List();
  }

  final black = Paint()..color = const Color(0xFF000000);
  final core = await render((c) => layout.paint(c, fg: black));
  final tol = await render((c) {
    layout.paint(c, fg: black);
    layout.paint(
      c,
      fg: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = brush * 2.2
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF000000),
    );
  });
  final ink = await render((c) {
    for (final s in strokes) {
      drawStroke(c, s, const Color(0xFF000000), brush);
    }
  });

  var letter = 0, covered = 0, inkPx = 0, inside = 0;
  for (var i = 3; i < core.length; i += 4) {
    final isL = core[i] > 60, isInk = ink[i] > 60;
    if (isL) {
      letter++;
      if (isInk) covered++;
    }
    if (isInk) {
      inkPx++;
      if (tol[i] > 60) inside++;
    }
  }
  return TraceScore(covered / math.max(1, letter), inside / math.max(1, inkPx));
}
