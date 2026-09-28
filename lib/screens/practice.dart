import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../brain.dart';
import '../data.dart';
import '../handwriting.dart';
import '../speech.dart';
import '../state.dart';
import '../widgets.dart';
import 'games.dart';
import 'trace.dart';

final _rnd = math.Random();

/// Aane the elephant, the practice buddy, with a speech bubble.
class Buddy extends StatelessWidget {
  const Buddy(this.kn, this.en, {super.key, this.pic = '🐘'});
  final String kn;
  final String en;
  final String pic;

  @override
  Widget build(BuildContext context) {
    final roman = AppScope.of(context).roman;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Bob(height: 6, child: Pic(pic, size: 72)),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            child: Container(
              key: ValueKey(kn + en),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: K.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                  bottomLeft: Radius.circular(6),
                ),
                boxShadow: const [
                  BoxShadow(color: K.shade, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kn,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  if (roman && en.isNotEmpty)
                    Text(
                      en,
                      style: const TextStyle(fontSize: 14, color: K.inkSoft),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A blank copybook card: the child writes a letter from memory and the
/// handwriting checker says whether it is right.
class WritePad extends StatefulWidget {
  const WritePad(this.ch, {super.key, required this.onResult, this.onMessage});
  final String ch;

  /// Called after each check.
  final void Function(bool passed) onResult;

  /// Feedback for the buddy to say: Kannada and English.
  final void Function(String kn, String en)? onMessage;

  @override
  State<WritePad> createState() => _WritePadState();
}

class _WritePadState extends State<WritePad> {
  final List<List<Offset>> _strokes = [];
  double _size = 300;
  bool _peek = false;
  bool _checking = false;

  void _say(String kn, String en) => widget.onMessage?.call(kn, en);

  Future<void> _check() async {
    if (_checking) return;
    if (_strokes.isEmpty) {
      _say(
        'ಬೆರಳಿನಿಂದ ${widget.ch} ಬರೆ ✍️',
        'Write ${widget.ch} with your finger',
      );
      return;
    }
    _checking = true;
    final hw = await Handwriting.load();
    final r = hw.check(widget.ch, _strokes);
    final hint = r.passed ? hw.strokeHint(widget.ch, _strokes) : StrokeHint.ok;
    _checking = false;
    if (!mounted) return;
    if (r.passed) {
      Audio.instance.win();
      showConfetti(context);
      final p = praise[_rnd.nextInt(praise.length)];
      if (hint == StrokeHint.ok) {
        _say('$p ಸರಿಯಾಗಿ ಬರೆದೆ!', 'You wrote ${widget.ch}!');
      } else {
        final (kn, en) = startHint(hw.startOf(widget.ch));
        _say(
          '$p ಮುಂದಿನ ಸಲ $kn',
          hint == StrokeHint.start
              ? 'Right! Next time: ${en.toLowerCase()}.'
              : 'Right! Try the strokes in order next time.',
        );
      }
      final say = sayingOf(widget.ch);
      if (say != null) Audio.instance.speak(say.$1, say.$2);
    } else {
      Audio.instance.wrong();
      if (r.tooSmall) {
        _say('ದೊಡ್ಡದಾಗಿ ಬರೆ', 'Write it bigger');
      } else if (r.rank >= 3 && r.best.isNotEmpty) {
        _say(
          'ಇದು ${r.best} ತರಹ ಕಾಣುತ್ತಿದೆ. ${widget.ch} ಬರೆ!',
          'That looks like ${r.best}. Try ${widget.ch}!',
        );
      } else {
        _say('ಹತ್ತಿರ! ಇನ್ನೊಮ್ಮೆ ಬರೆ', 'Close! Try once more');
      }
      setState(_strokes.clear);
    }
    widget.onResult(r.passed);
  }

  void _peekLetter() {
    setState(() => _peek = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _peek = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final side = math.min(c.maxWidth, 360.0);
            if (side != _size && _strokes.isEmpty) _size = side;
            return Container(
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
                  onPanDown: (d) =>
                      setState(() => _strokes.add([d.localPosition])),
                  onPanUpdate: (d) =>
                      setState(() => _strokes.last.add(d.localPosition)),
                  child: CustomPaint(
                    size: Size.square(_size),
                    painter: _PadPainter(
                      _peek ? LetterLayout(widget.ch, _size) : null,
                      _strokes,
                      _size * .055,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RoundButton(
              '🧽',
              label: 'Clear',
              onTap: () => setState(_strokes.clear),
            ),
            RoundButton('👀', label: 'Peek at the letter', onTap: _peekLetter),
            PillButton(
              '✔ ಆಯ್ತು',
              color: K.green,
              base: K.greenDeep,
              onTap: _check,
            ),
          ],
        ),
      ],
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter(this.peek, this.strokes, this.brush);
  final LetterLayout? peek;
  final List<List<Offset>> strokes;
  final double brush;

  @override
  void paint(Canvas canvas, Size size) {
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
    peek?.paint(canvas);
    for (final s in strokes) {
      drawStroke(canvas, s, K.blue, brush);
    }
  }

  @override
  bool shouldRepaint(_PadPainter old) => true;
}

/// Picture word to say aloud: the child hears it, taps the microphone and
/// says it; the phone's speech recogniser checks it.
class SayIt extends StatefulWidget {
  const SayIt(
    this.word, {
    super.key,
    required this.onResult,
    this.onMessage,
    this.onUnavailable,
  });
  final Word word;
  final void Function(bool right) onResult;
  final void Function(String kn, String en)? onMessage;

  /// Speech recognition can't run on this phone.
  final VoidCallback? onUnavailable;

  @override
  State<SayIt> createState() => _SayItState();
}

class _SayItState extends State<SayIt> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _listening = false;
  String _heard = '';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), _play);
  }

  @override
  void dispose() {
    _pulse.dispose();
    Speech.instance.stop();
    super.dispose();
  }

  void _play() {
    if (mounted) Audio.instance.speak(widget.word.word, widget.word.wordTr);
  }

  void _say(String kn, String en) => widget.onMessage?.call(kn, en);

  Future<void> _listen() async {
    if (_listening) return;
    Audio.instance.stop();
    setState(() {
      _listening = true;
      _heard = '';
    });
    _pulse.repeat(reverse: true);
    final h = await Speech.instance.listen(
      hint: widget.word.word,
      online: AppScope.read(context).onlineSpeech,
      onWords: (w) {
        if (mounted) setState(() => _heard = w);
      },
    );
    if (!mounted) return;
    _pulse.stop();
    setState(() {
      _listening = false;
      if (h.guesses.isNotEmpty) _heard = h.guesses.first;
    });
    switch (h.status) {
      case HearStatus.heard:
        final m = speechMatch(widget.word.word, widget.word.wordTr, h.guesses);
        if (m >= speechPass) {
          Audio.instance.right();
          showConfetti(context);
          _say(
            '${praise[_rnd.nextInt(praise.length)]} ಸರಿಯಾಗಿ ಹೇಳಿದೆ!',
            'You said ${widget.word.en.toLowerCase()} right!',
          );
          widget.onResult(true);
        } else {
          Audio.instance.wrong();
          m >= speechClose
              ? _say('ಹತ್ತಿರ! ಮತ್ತೆ ಹೇಳು', 'Almost! Say it again')
              : _say('ಕೇಳು, ಮತ್ತೆ ಹೇಳು', 'Listen, then say it again');
          widget.onResult(false);
          Future.delayed(const Duration(milliseconds: 700), _play);
        }
      case HearStatus.silent:
        _say(
          'ನನಗೆ ಕೇಳಿಸಲಿಲ್ಲ. 🎤 ಒತ್ತಿ ಜೋರಾಗಿ ಹೇಳು',
          "I didn't hear you. Tap 🎤 and say it loudly",
        );
      case HearStatus.noPermission:
        _say('ಮೈಕ್ ಬೇಕು', 'Ask a grown-up to allow the microphone');
        widget.onUnavailable?.call();
      case HearStatus.unavailable:
        _say(
          'ಈ ಫೋನಿನಲ್ಲಿ ಕನ್ನಡ ಕೇಳಲು ಆಗುತ್ತಿಲ್ಲ',
          'This phone can\'t listen in Kannada yet. Grown-ups: see "For parents".',
        );
        widget.onUnavailable?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.word;
    return Column(
      children: [
        Bob(child: Pic(w.emoji, size: 120)),
        Text(
          w.word,
          style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800),
        ),
        if (AppScope.of(context).roman)
          Text(
            '“${w.wordTr}” · ${w.en}',
            style: const TextStyle(fontSize: 16, color: K.inkSoft),
          ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RoundButton('🔊', label: 'Hear the word', onTap: _play),
            const SizedBox(width: 18),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) =>
                  Transform.scale(scale: 1 + _pulse.value * .12, child: child),
              child: RoundButton(
                '🎤',
                size: 96,
                color: _listening ? K.red : K.turmeric,
                base: _listening ? K.redDeep : K.turmericDeep,
                label: 'Say it',
                onTap: _listen,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 30,
          child: Center(
            child: Text(
              _listening
                  ? (_heard.isEmpty ? 'ಕೇಳುತ್ತಿದ್ದೇನೆ… · Listening…' : _heard)
                  : (_heard.isEmpty ? '' : 'ನಾನು ಕೇಳಿದ್ದು: $_heard'),
              style: const TextStyle(fontSize: 16, color: K.inkSoft),
            ),
          ),
        ),
      ],
    );
  }
}

/// Words that start with their letter and have a recording, for speaking.
List<(Letter, Word)> _sayWords() => startWordPairs()
    .where((p) => Audio.instance.hasRecording(p.$2.word))
    .toList();

/// "Say the word" game: six picture words to say aloud.
class SayGameScreen extends StatefulWidget {
  const SayGameScreen({super.key});
  static const rounds = 6;

  @override
  State<SayGameScreen> createState() => _SayGameScreenState();
}

class _SayGameScreenState extends State<SayGameScreen> {
  late final List<(Letter, Word)> _words;
  int _round = 0, _score = 0, _tries = 0;
  bool _unavailable = false;
  (String, String) _msg = (
    'ಚಿತ್ರ ನೋಡು, 🎤 ಒತ್ತಿ ಹೇಳು',
    'Look, tap 🎤 and say the word',
  );

  @override
  void initState() {
    super.initState();
    final recorded = _sayWords();
    final all = recorded.isEmpty ? startWordPairs() : recorded;
    final focus = AppScope.read(context).practiceLetters(6);
    final pool = shuffled(all);
    // Half of the words come from the letters the child needs to practise.
    _words =
        [
          ...shuffled(all.where((p) => focus.contains(p.$1.ch))).take(3),
          ...pool,
        ].fold<List<(Letter, Word)>>([], (acc, p) {
          if (acc.length < SayGameScreen.rounds && !acc.contains(p)) acc.add(p);
          return acc;
        });
  }

  void _next() {
    if (_round + 1 >= SayGameScreen.rounds) {
      finishGame(context, Game.say, _score, SayGameScreen.rounds);
    } else {
      setState(() {
        _round++;
        _tries = 0;
        _msg = ('ಮುಂದಿನ ಪದ', 'Next word');
      });
    }
  }

  void _result(bool right) {
    final (l, _) = _words[_round];
    AppScope.read(context).recordAnswer(l.ch, right: right && _tries == 0);
    if (right) {
      if (_tries == 0) _score++;
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) _next();
      });
    } else {
      setState(() => _tries++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (_, w) = _words[_round];
    return KidPage(
      title: 'ಹೇಳು ಆಟ',
      sub: 'Say the word',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _round / SayGameScreen.rounds,
                    minHeight: 14,
                    color: K.turmeric,
                    backgroundColor: K.paper,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_round + 1}/${SayGameScreen.rounds}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Buddy(_msg.$1, _msg.$2),
          const SizedBox(height: 12),
          SayIt(
            w,
            key: ValueKey(_round),
            onResult: _result,
            onMessage: (kn, en) => setState(() => _msg = (kn, en)),
            onUnavailable: () => setState(() => _unavailable = true),
          ),
          if (_tries >= 2 || _unavailable)
            Center(
              child: PillButton(
                'ಮುಂದೆ ▶',
                small: true,
                color: K.white,
                base: K.shade,
                fg: K.ink,
                onTap: _next,
              ),
            ),
        ],
      ),
    );
  }
}

/// Writing a letter from memory, from the trace screen.
class FreeWriteScreen extends StatefulWidget {
  const FreeWriteScreen(this.item, {super.key});
  final CardItem item;

  @override
  State<FreeWriteScreen> createState() => _FreeWriteScreenState();
}

class _FreeWriteScreenState extends State<FreeWriteScreen> {
  late (String, String) _msg = (
    'ನೋಡದೆ ${widget.item.ch} ಬರೆ!',
    'Write ${widget.item.ch} without looking!',
  );
  bool _rewarded = false;

  @override
  Widget build(BuildContext context) {
    final ch = widget.item.ch;
    return KidPage(
      title: 'ನೆನಪಿನಿಂದ ಬರೆ',
      sub: 'Write from memory',
      child: Column(
        children: [
          Buddy(_msg.$1, _msg.$2),
          const SizedBox(height: 12),
          WritePad(
            ch,
            onMessage: (kn, en) => setState(() => _msg = (kn, en)),
            onResult: (ok) {
              final s = AppScope.read(context);
              if (ok) {
                s.markTraced(ch);
                if (!_rewarded) {
                  _rewarded = true;
                  reward(context, 3);
                }
              }
            },
          ),
          const SizedBox(height: 10),
          PillButton(
            '▶ ನೋಡು · Watch how',
            small: true,
            color: K.plum,
            base: K.plumDeep,
            onTap: () => showWritingGuide(context, ch),
          ),
        ],
      ),
    );
  }
}

enum _Step { hear, write, say }

/// Today's practice with Aane: for each letter the smart planner picks,
/// hear it and find it, write it from memory, and say its word.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final List<Letter> _plan;
  late final List<(Letter, _Step)> _steps;
  int _i = 0, _score = 0, _misses = 0;
  bool _noSpeech = false, _done = false;
  List<Letter> _options = const [];
  final Set<int> _wrong = {};
  int? _right;
  (String, String) _msg = ('', '');
  final Set<String> _missed = {};

  @override
  void initState() {
    super.initState();
    final plan = AppScope.read(context).practiceLetters(5);
    _plan = [for (final c in plan) letters.firstWhere((l) => l.ch == c)];
    _steps = [
      for (final l in _plan) ...[
        (l, _Step.hear),
        (l, _Step.write),
        if (_wordFor(l) != null) (l, _Step.say),
      ],
    ];
    _startStep();
  }

  Word? _wordFor(Letter l) {
    final ws = wordsFor(l)
        .where((w) => w.word.startsWith(l.ch) && (l.start || w.word != l.word));
    final rec = ws.where((w) => Audio.instance.hasRecording(w.word));
    return rec.isNotEmpty ? rec.first : (ws.isNotEmpty ? ws.first : null);
  }

  (Letter, _Step) get _step => _steps[_i];

  void _startStep() {
    final (l, step) = _step;
    _misses = 0;
    _wrong.clear();
    _right = null;
    switch (step) {
      case _Step.hear:
        // Look-alikes from the same group first, so the choice is real.
        final same = shuffled(
          letters.where((o) => o.group == l.group && o != l),
        );
        final other = shuffled(letters.where((o) => o.group != l.group));
        _options = shuffled([
          l,
          ...[...same, ...other].take(3),
        ]);
        _msg = ('ಕೇಳು! ಯಾವ ಅಕ್ಷರ?', 'Listen! Which letter is it?');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Audio.instance.speak(l.ch, l.tr);
        });
      case _Step.write:
        _msg = ('ಈಗ ${l.ch} ನೆನಪಿನಿಂದ ಬರೆ', 'Now write ${l.ch} from memory');
      case _Step.say:
        _msg = ('ಈ ಪದ ಹೇಳು', 'Say this word');
    }
  }

  void _advance({bool firstTry = false}) {
    if (firstTry) _score++;
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      var next = _i + 1;
      while (next < _steps.length &&
          _noSpeech &&
          _steps[next].$2 == _Step.say) {
        next++;
      }
      if (next >= _steps.length) {
        _finish();
      } else {
        setState(() {
          _i = next;
          _startStep();
        });
      }
    });
  }

  void _finish() {
    reward(context, _score);
    Audio.instance.win();
    showConfetti(context);
    Audio.instance.speak(spokenPraise.first.$1, spokenPraise.first.$2);
    setState(() => _done = true);
  }

  void _choose(int k) {
    if (_right != null || _wrong.contains(k)) return;
    final l = _step.$1;
    final right = _options[k] == l;
    AppScope.read(context).recordAnswer(l.ch, right: right && _wrong.isEmpty);
    if (right) {
      Audio.instance.right();
      setState(() {
        _right = k;
        _msg = (praise[_rnd.nextInt(praise.length)], 'That\'s ${l.tr}!');
      });
      Audio.instance.speak(l.ch, l.tr);
      _advance(firstTry: _wrong.isEmpty);
    } else {
      Audio.instance.wrong();
      _missed.add(l.ch);
      setState(() {
        _wrong.add(k);
        _msg = (
          'ಇದು ${_options[k].ch}. ಮತ್ತೆ ಕೇಳು',
          'That is ${_options[k].tr}. Listen again',
        );
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Audio.instance.speak(l.ch, l.tr);
      });
    }
  }

  Widget _hear(Letter l) => Column(
    children: [
      RoundButton(
        '🔊',
        size: 96,
        color: K.turmeric,
        base: K.turmericDeep,
        label: 'Play sound',
        onTap: () => Audio.instance.speak(l.ch, l.tr),
      ),
      const SizedBox(height: 14),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 14,
        childAspectRatio: 1.6,
        children: [
          for (var k = 0; k < _options.length; k++)
            Opacity(
              opacity: _wrong.contains(k) ? .35 : 1,
              child: Toy(
                onTap: () => _choose(k),
                sound: false,
                color: k == _right ? K.green : K.tint(k + 4).$1,
                base: k == _right ? K.greenDeep : K.tint(k + 4).$2,
                semanticLabel: _options[k].ch,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _options[k].ch,
                      style: const TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.w800,
                        color: K.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _body() {
    final (l, step) = _step;
    switch (step) {
      case _Step.hear:
        return _hear(l);
      case _Step.write:
        return Column(
          children: [
            WritePad(
              l.ch,
              key: ValueKey('w$_i'),
              onMessage: (kn, en) => setState(() => _msg = (kn, en)),
              onResult: (ok) {
                final s = AppScope.read(context);
                if (ok) {
                  s.markTraced(l.ch);
                  _advance(firstTry: _misses == 0);
                } else {
                  if (_misses == 0) s.recordAnswer(l.ch, right: false);
                  _missed.add(l.ch);
                  setState(() => _misses++);
                  if (_misses == 2) showWritingGuide(context, l.ch);
                }
              },
            ),
            if (_misses >= 2)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: PillButton(
                  'ಮುಂದೆ ▶',
                  small: true,
                  color: K.white,
                  base: K.shade,
                  fg: K.ink,
                  onTap: () => _advance(),
                ),
              ),
          ],
        );
      case _Step.say:
        return Column(
          children: [
            SayIt(
              _wordFor(l)!,
              key: ValueKey('s$_i'),
              onMessage: (kn, en) => setState(() => _msg = (kn, en)),
              onResult: (ok) {
                if (ok) {
                  AppScope.read(context)
                      .recordAnswer(l.ch, right: _misses == 0);
                  _advance(firstTry: _misses == 0);
                } else {
                  setState(() => _misses++);
                }
              },
              onUnavailable: () => setState(() {
                _noSpeech = true;
                _misses = 2;
              }),
            ),
            if (_misses >= 2)
              PillButton(
                'ಮುಂದೆ ▶',
                small: true,
                color: K.white,
                base: K.shade,
                fg: K.ink,
                onTap: () => _advance(),
              ),
          ],
        );
    }
  }

  Widget _summary() {
    final total = _steps.where((s) => !_noSpeech || s.$2 != _Step.say).length;
    return Column(
      children: [
        Buddy(
          'ಶಭಾಷ್! ಇಂದಿನ ಅಭ್ಯಾಸ ಮುಗಿಯಿತು',
          'Well done! Today\'s practice is finished. +$_score ⭐',
          pic: '🐘',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final l in _plan)
              Container(
                width: 76,
                height: 86,
                alignment: Alignment.center,
                padding: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: _missed.contains(l.ch) ? K.orange : K.green,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.ch,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: K.white,
                      ),
                    ),
                    Text(
                      _missed.contains(l.ch) ? 'ಮತ್ತೆ ನಾಳೆ' : '✓',
                      style: const TextStyle(color: K.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$_score / $total right the first time. Orange letters come back tomorrow.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: K.inkSoft, fontSize: 15),
        ),
        const SizedBox(height: 16),
        PillButton(
          '🏠',
          color: K.white,
          base: K.shade,
          fg: K.ink,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return KidPage(
      title: 'ಆನೆಯ ಜೊತೆ ಅಭ್ಯಾಸ',
      sub: 'Practice with Aane',
      child: _done
          ? _summary()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _i / _steps.length,
                    minHeight: 14,
                    color: K.turmeric,
                    backgroundColor: K.paper,
                  ),
                ),
                const SizedBox(height: 12),
                Buddy(_msg.$1, _msg.$2),
                const SizedBox(height: 14),
                _body(),
              ],
            ),
    );
  }
}
