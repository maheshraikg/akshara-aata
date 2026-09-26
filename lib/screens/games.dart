import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ads.dart';
import '../audio.dart';
import '../data.dart';
import '../main.dart';
import '../state.dart';
import '../widgets.dart';
import 'balloon.dart';
import 'home.dart' show HomeBlock;
import 'memory.dart';

final _rnd = math.Random();
T pick<T>(List<T> a) => a[_rnd.nextInt(a.length)];
List<T> shuffled<T>(Iterable<T> a) => a.toList()..shuffle(_rnd);
List<T> sampleOf<T>(List<T> pool, int n, List<T> not) =>
    shuffled(pool.where((x) => !not.contains(x))).take(n).toList();

enum Game { listen, picture, memory, balloon, next, kagunita, count }

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  static const _games = [
    (Game.listen, 'ಕೇಳಿ ಹುಡುಕು', 'Listen & find', '👂', K.red, K.redDeep),
    (Game.picture, 'ಚಿತ್ರ ಆಟ', 'First letter', '🖼️', K.blue, K.blueDeep),
    (Game.memory, 'ಜೋಡಿ ಆಟ', 'Memory pairs', '🃏', K.green, K.greenDeep),
    (Game.balloon, 'ಬಲೂನ್ ಆಟ', 'Balloon pop', '🎈', K.plum, K.plumDeep),
    (Game.next, 'ಮುಂದೆ ಏನು?', 'What comes next', '➡️', K.orange, K.orangeDeep),
    (Game.kagunita, 'ಕಾಗುಣಿತ ಆಟ', 'Add the sign', '📝', K.pink, K.pinkDeep),
    (Game.count, 'ಎಣಿಸು', 'Count & pick', '🧮', K.teal, K.tealDeep),
  ];

  static void open(BuildContext context, Game g, {bool swap = false}) {
    final Widget screen = switch (g) {
      Game.memory => const MemoryScreen(),
      Game.balloon => const BalloonScreen(),
      _ => QuizScreen(game: g),
    };
    swap ? replace(context, screen) : push(context, screen);
  }

  @override
  Widget build(BuildContext context) => KidPage(
    title: 'ಆಟಗಳು',
    sub: 'Games — every right answer earns a ⭐',
    ad: true,
    child: GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 14,
      childAspectRatio: 1.2,
      children: [
        for (final g in _games)
          HomeBlock(
            pic: g.$4,
            title: g.$2,
            sub: g.$3,
            color: g.$5,
            base: g.$6,
            glyphSize: 58,
            onTap: () => open(context, g.$1),
          ),
      ],
    ),
  );
}

class _Round {
  _Round({
    required this.title,
    required this.sub,
    required this.prompt,
    required this.options,
    this.say,
    this.after,
    this.target,
  });

  /// Letter being tested, for the parent report's weak letters.
  final String? target;
  final String title;
  final String sub;
  final Widget Function(BuildContext context, VoidCallback say) prompt;
  final List<(String, bool)> options;
  final VoidCallback? say;
  final VoidCallback? after;
}

Widget _seq(List<Widget> parts) => Wrap(
  alignment: WrapAlignment.center,
  crossAxisAlignment: WrapCrossAlignment.center,
  spacing: 10,
  runSpacing: 6,
  children: parts,
);

Text _big(String s, {Color color = K.blue, double size = 48}) => Text(
  s,
  style: TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
    height: 1.3,
  ),
);

const _hint = TextStyle(fontSize: 16, color: K.inkSoft);
const _q = TextStyle(fontSize: 18, color: K.inkSoft);

_Round _makeRound(Game g, AppState s) {
  switch (g) {
    case Game.listen:
      final pool = pick([
        byGroup(Group.swara),
        byGroup(Group.vyanjana),
        letters,
      ]);
      final ans = pick(pool);
      final opts = shuffled([
        ans,
        ...sampleOf(pool, 3, [ans]),
      ]);
      return _Round(
        target: ans.ch,
        title: 'ಕೇಳಿ ಹುಡುಕು',
        sub: 'Listen, then tap the letter',
        say: () => Audio.instance.speak(ans.ch, ans.tr),
        prompt: (_, say) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoundButton(
              '🔊',
              size: 104,
              color: K.turmeric,
              base: K.turmericDeep,
              label: 'Play sound',
              onTap: say,
            ),
            const SizedBox(height: 6),
            const Text('ಯಾವ ಅಕ್ಷರ? Which letter?', style: _q),
            if (s.roman) Text('“${ans.tr}”', style: _hint),
          ],
        ),
        options: [for (final o in opts) (o.ch, o == ans)],
      );
    case Game.picture:
      final pairs = startWordPairs();
      final (ansL, w) = pick(pairs);
      final pool = letters.where((l) => l != ansL).toList();
      final opts = shuffled([ansL, ...sampleOf(pool, 3, const [])]);
      return _Round(
        title: 'ಚಿತ್ರ ಆಟ',
        sub: 'Which letter does it start with?',
        target: ansL.ch,
        say: () => Audio.instance.speak(w.word, w.wordTr),
        prompt: (_, say) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Bob(child: Pic(w.emoji, size: 120)),
            const SizedBox(height: 6),
            PillButton(
              '🔊 ${s.roman ? w.en : 'ಕೇಳು'}',
              small: true,
              color: K.white,
              base: K.shade,
              fg: K.ink,
              onTap: say,
            ),
          ],
        ),
        options: [for (final o in opts) (o.ch, o == ansL)],
        after: () => Audio.instance.speak(w.word, w.wordTr),
      );
    case Game.next:
      final seqs = <List<(String, String, String)>>[
        [for (final l in byGroup(Group.swara)) (l.ch, l.ch, l.tr)],
        [
          for (final l in byGroup(Group.vyanjana).sublist(0, 25))
            (l.ch, l.ch, l.tr),
        ],
        [
          for (final l in byGroup(Group.vyanjana).sublist(25))
            (l.ch, l.ch, l.tr),
        ],
        [for (final n in numbers.sublist(0, 10)) (n.ch, n.word, n.wordTr)],
      ];
      final seq = pick(seqs);
      final start = _rnd.nextInt(seq.length - 3);
      final run = seq.sublist(start, start + 4);
      final gap = 1 + _rnd.nextInt(3);
      final ans = run[gap];
      final opts = shuffled([ans, ...sampleOf(seq, 3, run)]);
      return _Round(
        title: 'ಮುಂದೆ ಏನು?',
        sub: 'Which letter fills the gap?',
        prompt: (_, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _seq([
              for (var i = 0; i < run.length; i++)
                i == gap
                    ? Container(
                        width: 64,
                        height: 56,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: K.red, width: 5),
                          ),
                        ),
                      )
                    : _big(run[i].$1),
            ]),
            const SizedBox(height: 6),
            const Text('ಬಿಟ್ಟ ಅಕ್ಷರ ಯಾವುದು?', style: _q),
          ],
        ),
        options: [for (final o in opts) (o.$1, o == ans)],
        after: () => Audio.instance.speak(ans.$2, ans.$3),
      );
    case Game.kagunita:
      final bases = byGroup(Group.vyanjana)
          .where((b) => b.ch != 'ಙ' && b.ch != 'ಞ')
          .toList();
      final base = pick(bases);
      final pool = signs.sublist(1, 13);
      final sg = pick(pool);
      final ans = base.ch + sg.sign;
      final roman = rootOf(base) + sg.tr;
      final other = pick(bases.where((b) => b != base).toList()).ch + sg.sign;
      final opts = shuffled([
        ans,
        other,
        ...sampleOf(pool, 2, [sg]).map((o) => base.ch + o.sign),
      ]);
      return _Round(
        title: 'ಕಾಗುಣಿತ ಆಟ',
        sub: 'Letter + vowel sign = ?',
        say: () => Audio.instance.speak(ans, roman),
        prompt: (_, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _seq([
              _big(base.ch),
              _big('+', color: K.inkSoft),
              _big(sg.vowel, color: K.red),
              _big('=', color: K.inkSoft),
              _big('?', color: K.inkSoft),
            ]),
            if (s.roman) Text('${base.tr} + ${sg.tr} = “$roman”', style: _hint),
          ],
        ),
        options: [for (final o in opts) (o, o == ans)],
        after: () => Audio.instance.speak(ans, roman),
      );
    case Game.count:
      final pool = numbers.sublist(1, 10);
      final ans = pick(pool);
      final thing = pick(['🍎', '🐟', '🌸', '🦆', '⭐', '🥭', '🎈', '🐞']);
      final opts = shuffled([
        ans,
        ...sampleOf(pool, 3, [ans]),
      ]);
      return _Round(
        title: 'ಎಣಿಸು',
        sub: 'Count, then tap the Kannada number',
        prompt: (_, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Wrap(
                key: const ValueKey('count-row'),
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < ans.n; i++) Pic(thing, size: 52),
                ],
              ),
            ),
            const Text('ಎಷ್ಟು? How many?', style: _q),
          ],
        ),
        options: [for (final o in opts) (o.ch, o == ans)],
        after: () => Audio.instance.speak(ans.word, ans.wordTr),
      );
    case Game.memory:
    case Game.balloon:
      throw ArgumentError('$g has its own screen');
  }
}

/// Eight-round multiple-choice game shared by five games.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.game});
  final Game game;
  static const rounds = 8;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _round = 0;
  int _score = 0;
  late _Round _r;
  bool _firstTry = true;
  bool _done = false;
  int? _right;
  final Set<int> _wrong = {};

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    _r = _makeRound(widget.game, AppScope.read(context));
    _firstTry = true;
    _done = false;
    _right = null;
    _wrong.clear();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _r.say?.call();
    });
  }

  void _choose(int i) {
    if (_done || _wrong.contains(i)) return;
    final t = _r.target;
    if (t != null) {
      AppScope.read(context)
          .recordAnswer(t, right: _r.options[i].$2 && _firstTry);
    }
    if (_r.options[i].$2) {
      setState(() {
        _done = true;
        _right = i;
        if (_firstTry) _score++;
      });
      Audio.instance.right();
      _r.after?.call();
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (!mounted) return;
        _round++;
        if (_round >= QuizScreen.rounds) {
          finishGame(context, widget.game, _score, QuizScreen.rounds);
        } else {
          setState(_newRound);
        }
      });
    } else {
      setState(() {
        _firstTry = false;
        _wrong.add(i);
      });
      Audio.instance.wrong();
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _r.say?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return KidPage(
      title: _r.title,
      sub: _r.sub,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _round / QuizScreen.rounds,
                    minHeight: 14,
                    color: K.turmeric,
                    backgroundColor: K.paper,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_round + 1}/${QuizScreen.rounds}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(minHeight: 200),
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFBEF), Colors.white],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [
                BoxShadow(color: Color(0xFFE8D9B8), offset: Offset(0, 7)),
                BoxShadow(
                  color: Color(0x1F2B2140),
                  offset: Offset(0, 14),
                  blurRadius: 18,
                ),
              ],
            ),
            child: _r.prompt(context, () => _r.say?.call()),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 14,
            childAspectRatio: 1.55,
            children: [
              for (var i = 0; i < _r.options.length; i++)
                _Choice(
                  index: i,
                  label: _r.options[i].$1,
                  state: i == _right
                      ? _ChoiceState.right
                      : _wrong.contains(i)
                      ? _ChoiceState.wrong
                      : _ChoiceState.idle,
                  onTap: () => _choose(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ChoiceState { idle, right, wrong }

class _Choice extends StatelessWidget {
  const _Choice({
    required this.index,
    required this.label,
    required this.state,
    required this.onTap,
  });
  final int index;
  final String label;
  final _ChoiceState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Candy colours per slot; right turns green, wrong fades out.
    const slots = [
      (K.blue, K.blueDeep),
      (K.orange, K.orangeDeep),
      (K.plum, K.plumDeep),
      (K.pink, K.pinkDeep),
    ];
    final (c, d) = slots[index % slots.length];
    final (bg, base, fg) = switch (state) {
      _ChoiceState.right => (K.green, K.greenDeep, K.white),
      _ChoiceState.wrong => (
        const Color(0xFFE9E4F0),
        const Color(0xFFCFC7DB),
        const Color(0xFFA79DB8),
      ),
      _ChoiceState.idle => (c, d, K.white),
    };
    final button = Toy(
      onTap: onTap,
      sound: false,
      color: bg,
      base: base,
      radius: 22,
      semanticLabel: label,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FittedBox(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w800,
                color: fg,
                shadows: state == _ChoiceState.wrong
                    ? null
                    : [Shadow(color: base, offset: const Offset(0, 3))],
              ),
            ),
          ),
        ),
      ),
    );
    if (state != _ChoiceState.right) {
      return PopIn(delay: index * .1, child: button);
    }
    // A right answer bounces.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.25, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: button,
    );
  }
}

/// Shows the end-of-game screen and awards stars.
void finishGame(BuildContext context, Game g, int score, int total) {
  reward(context, score);
  Ads.afterGame(() {
    if (context.mounted) {
      replace(context, ResultScreen(game: g, score: score, total: total));
    }
  });
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.game,
    required this.score,
    required this.total,
  });
  final Game game;
  final int score;
  final int total;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int get rating => widget.score >= widget.total * .85
      ? 3
      : widget.score >= widget.total * .5
      ? 2
      : 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Audio.instance.win();
      if (rating == 3) showConfetti(context);
      Audio.instance.speak(
        rating == 3 ? 'ಶಭಾಷ್' : 'ಚೆನ್ನಾಗಿದೆ',
        rating == 3 ? 'shabash' : 'chennagide',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = rating;
    return KidPage(
      title: 'ಆಟ ಮುಗಿಯಿತು',
      sub: 'Game over',
      ad: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        decoration: BoxDecoration(
          color: K.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: K.shade, offset: Offset(0, 6))],
        ),
        child: Column(
          children: [
            Bob(
              height: 8,
              child: Pic(
                r == 3
                    ? '🏆'
                    : r == 2
                    ? '🥳'
                    : '🌱',
                size: 120,
              ),
            ),
            Text(
              r == 3
                  ? 'ಶಭಾಷ್!'
                  : r == 2
                  ? 'ಚೆನ್ನಾಗಿದೆ!'
                  : 'ಮತ್ತೆ ಆಡೋಣ!',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
            ),
            Semantics(
              label: '$r of 3 stars',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Opacity(
                      opacity: i < r ? 1 : .2,
                      child: const Pic('⭐', size: 50),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.score} / ${widget.total} right the first time · +${widget.score} ⭐',
              textAlign: TextAlign.center,
              style: const TextStyle(color: K.inkSoft, fontSize: 16),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                PillButton(
                  '🔁 ಮತ್ತೆ ಆಡು',
                  onTap: () =>
                      GamesScreen.open(context, widget.game, swap: true),
                ),
                PillButton(
                  '🎮 ಆಟಗಳು',
                  color: K.white,
                  base: K.shade,
                  fg: K.ink,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                PillButton(
                  '🏠',
                  color: K.white,
                  base: K.shade,
                  fg: K.ink,
                  onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
