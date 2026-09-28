import 'dart:convert';
import 'dart:io';

import 'package:akshara_aata/audio.dart';
import 'package:akshara_aata/brain.dart';
import 'package:akshara_aata/handwriting.dart';
import 'package:akshara_aata/data.dart';
import 'package:akshara_aata/main.dart';
import 'package:akshara_aata/online.dart';
import 'package:akshara_aata/screens/trace.dart';
import 'package:akshara_aata/writing_guide.dart';
import 'package:akshara_aata/state.dart';
import 'package:akshara_aata/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> freshState() async {
  SharedPreferences.setMockInitialValues({});
  return AppState(await SharedPreferences.getInstance());
}

void main() {
  group('varnamala data', () {
    test('has the 49 letters of the aksharamale', () {
      expect(letters.length, 49);
      expect(byGroup(Group.swara).length, 13);
      expect(byGroup(Group.yogavaha).length, 2);
      expect(byGroup(Group.vyanjana).length, 34);
      expect(letters.map((l) => l.ch).toSet().length, 49);
    });

    test('every consonant belongs to a varga', () {
      final ids = vargas.map((v) => v.id).toSet();
      for (final l in byGroup(Group.vyanjana)) {
        expect(ids, contains(l.varga), reason: l.ch);
      }
      for (final v in vargas.take(5)) {
        expect(letters.where((l) => l.varga == v.id).length, 5, reason: v.id);
      }
    });

    test('start-letter words really start with their letter', () {
      for (final l in letters.where((l) => l.start)) {
        expect(l.word.startsWith(l.ch), isTrue, reason: '${l.ch} ${l.word}');
      }
    });

    test('kagunita forms join consonant and sign', () {
      final ka = letters.firstWhere((l) => l.ch == 'ಕ');
      expect(signs.map((s) => ka.ch + s.sign).take(3), ['ಕ', 'ಕಾ', 'ಕಿ']);
      expect(rootOf(ka) + signs[2].tr, 'ki');
      expect(signs.length, 15);
    });
  });

  test('every spoken text has a bundled recording', () {
    for (final (kn, _) in spokenTexts()) {
      final f = File('assets/audio/${audioKey(kn)}.ogg');
      expect(f.existsSync(), isTrue, reason: '$kn has no recording');
    }
    // Every text the app says aloud is in the list.
    final texts = spokenTexts().map((e) => e.$1).toSet();
    for (final l in letters) {
      expect(texts, containsAll([l.ch, l.word]));
    }
    expect(texts, containsAll(numbers.map((n) => n.word)));
    expect(texts, contains('ಕೌ'));
  });

  test('every picture word and sticker has a bundled 3D image', () {
    final emoji = {...letters.map((l) => l.emoji), ...stickers};
    for (final e in emoji) {
      final f = File('assets/pics/${Pic.keyOf(e)}.webp');
      expect(f.existsSync(), isTrue, reason: '$e has no picture');
    }
  });

  test('every letter has stroke-order writing data', () {
    final strokes = jsonDecode(
      File('assets/writing/strokes.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final l in letters) {
      expect(WritingData.has(l.ch), isTrue, reason: l.ch);
      expect(strokes[l.ch], isNotNull, reason: '${l.ch} has no pen path');
      expect(
        File('assets/writing/${audioKey(l.ch)}.png').existsSync(),
        isTrue,
        reason: '${l.ch} has no time map',
      );
    }
    expect(WritingData.has('೧'), isFalse);
  });

  test('every kagunita form has stroke-order writing data', () {
    final paths = jsonDecode(
      File('assets/writing/kagunita.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final b in byGroup(Group.vyanjana)) {
      final cards = kagunitaCards(b);
      expect(cards.length, 15);
      for (final k in cards.skip(1)) {
        expect(WritingData.has(k.ch), isTrue, reason: k.ch);
        expect(paths[k.ch], isNotNull, reason: '${k.ch} has no pen path');
        expect(
          File('assets/writing/${audioKey(k.ch)}.png').existsSync(),
          isTrue,
          reason: '${k.ch} has no time map',
        );
      }
    }
    expect(sayingOf('ಕಾ'), ('ಕಾ', 'kaa'));
    expect(kagunitaParts('ಅಾ'), isNull);
  });

  test('Kannada maps onto Devanagari for the Hindi voice fallback', () {
    expect(Audio.toDevanagari('ಕ'), 'क');
    expect(Audio.toDevanagari('ಆನೆ'), 'आने');
    expect(Audio.toDevanagari('೩'), '३');
  });

  test('extra picture words start with their letter and have pictures', () {
    for (final e in extraWords.entries) {
      for (final w in e.value) {
        expect(w.word.startsWith(e.key), isTrue, reason: w.word);
        expect(
          File('assets/pics/${Pic.keyOf(w.emoji)}.webp').existsSync(),
          isTrue,
          reason: w.emoji,
        );
      }
    }
    expect(startWordPairs().length, greaterThan(70));
  });

  test('streak counts consecutive days and resets after a gap', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 9, 1, 10);
    final s = AppState(prefs, clock: () => now);
    s.markSeen('ಅ');
    expect(s.streak, 1);
    expect(s.todayCount, 1);
    now = DateTime(2026, 9, 2, 9);
    expect(s.todayCount, 0);
    s.markSeen('ಆ');
    expect(s.streak, 2);
    now = DateTime(2026, 9, 5, 9);
    expect(s.streak, 0);
    s.markSeen('ಇ');
    expect(s.streak, 1);
  });

  test('weak letters rise with mistakes and fall with right answers', () async {
    final s = await freshState();
    s.recordAnswer('ಕ', right: false);
    s.recordAnswer('ಕ', right: false);
    s.recordAnswer('ಗ', right: false);
    expect(s.weakLetters, ['ಕ', 'ಗ']);
    s.recordAnswer('ಗ', right: true);
    expect(s.weakLetters, ['ಕ']);
  });

  test('old single-child data becomes the first profile', () async {
    SharedPreferences.setMockInitialValues({
      'akshara-aata-v1':
          '{"stars": 12, "seen": ["ಅ"], "traced": [], "roman": false}',
    });
    final s = AppState(await SharedPreferences.getInstance());
    expect(s.profiles.length, 1);
    expect(s.stars, 12);
    expect(s.seen, contains('ಅ'));
    expect(s.roman, isFalse);
    s.addProfile('Anu', '👧');
    expect(s.stars, 0);
    s.switchProfile(0);
    expect(s.stars, 12);
  });

  test('stars unlock a sticker every 10', () async {
    final s = await freshState();
    expect(s.addStars(9), isNull);
    expect(s.addStars(1), stickers[0]);
    expect(s.stickersUnlocked, 1);
  });

  test('progress survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = AppState(prefs)
      ..markTraced('ಅ')
      ..addStars(3);
    s.markSeen('ಆ');
    final again = AppState(prefs);
    expect(again.stars, 3);
    expect(again.traced, contains('ಅ'));
    expect(again.seen, contains('ಆ'));
  });

  testWidgets('tracing: covering the letter passes, scribbling does not', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const size = 300.0, brush = size * .065;
      final layout = LetterLayout('ಅ', size);
      // Fill the letter's box densely: high coverage but lots of ink outside.
      final scribble = [
        for (double y = 0; y < size; y += brush * .8)
          [Offset(0, y), Offset(size, y)],
      ];
      final bad = await scoreTracing('ಅ', size, brush, scribble);
      expect(bad.passed, isFalse);
      expect(bad.accuracy, lessThan(.7));

      // Stay inside the glyph's box only.
      final w = layout.fontSize;
      final box = Rect.fromLTWH(layout.offset.dx, layout.offset.dy, w, w);
      final careful = [
        for (double y = box.top; y < box.bottom; y += brush * .8)
          [Offset(box.left, y), Offset(box.right, y)],
      ];
      final ok = await scoreTracing('ಅ', size, brush, careful);
      expect(ok.coverage, greaterThan(.5));
    });
  });

  testWidgets('home opens vowels and a letter card', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // The mascot and pictures bob forever; tests run with reduced motion.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final state = await freshState();
    state.update((s) => s.sfx = false);
    await tester.pumpWidget(AksharaAata(state: state));
    // Past the opening splash to the home screen.
    await tester.pumpAndSettle();
    expect(find.text('ಅಕ್ಷರ ಆಟ'), findsOneWidget);

    await tester.ensureVisible(find.text('ಸ್ವರಗಳು'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ಸ್ವರಗಳು'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ಆ').first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('2 / 15'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Pic && w.emoji == '🐘'),
      findsOneWidget,
    );
    expect(state.seen, contains('ಆ'));
  });

  testWidgets('a quiz game can be played to the result screen', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // The mascot and pictures bob forever; tests run with reduced motion.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final state = await freshState();
    state.update((s) => s.sfx = false);
    await tester.pumpWidget(AksharaAata(state: state));
    // Past the opening splash to the home screen.
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ಆಟಗಳು'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ಆಟಗಳು'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ಎಣಿಸು'));
    await tester.pumpAndSettle();

    for (var round = 0; round < 8; round++) {
      // The prompt row holds N pictures; the right answer is numbers[N].
      final n = tester
          .widget<Wrap>(find.byKey(const ValueKey('count-row')))
          .children
          .length;
      await tester.tap(find.text(numbers[n].ch));
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();
    }
    expect(find.text('ಶಭಾಷ್!'), findsOneWidget);
    expect(state.stars, 8);
  });

  group('handwriting checker', () {
    final json = jsonDecode(
      File('assets/writing/shapes.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final hw = Handwriting.fromJson(json);

    /// A letter's centre line as a child's writing: one stroke per point,
    /// in writing order, squeezed and slanted like a child's hand.
    List<List<Offset>> writing(String ch, {double sx = 1, double shear = 0}) {
      final v = (json[ch] as List).cast<int>();
      final pts = [
        for (var i = 0; i < v.length; i += 4)
          (
            v[i + 3],
            Offset(v[i] * 5.0 * sx + v[i + 1] * shear * 5, v[i + 1] * 5.0),
          ),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      return [
        for (final p in pts) [p.$2],
      ];
    }

    test('has shapes for every letter and kagunita', () {
      for (final l in letters) {
        expect(hw.has(l.ch), isTrue, reason: l.ch);
      }
      expect(hw.has('ಕಾ') && hw.has('ಳಃ'), isTrue);
    });

    test('recognises letters, even squeezed and slanted', () {
      var top = 0;
      for (final l in letters) {
        final r = hw.check(l.ch, writing(l.ch));
        expect(r.passed, isTrue, reason: l.ch);
        expect(r.best, l.ch);
        if (hw.check(l.ch, writing(l.ch, sx: .85, shear: .15)).passed) top++;
      }
      expect(top, greaterThanOrEqualTo(45));
    });

    test('tells ಬ from ಪ and checks the kagunita sign', () {
      expect(hw.check('ಪ', writing('ಬ')).best, 'ಬ');
      expect(hw.check('ಕಾ', writing('ಕಾ')).passed, isTrue);
      expect(hw.check('ಕಾ', writing('ಕೌ')).best, 'ಕೌ');
    });

    test('a scribble or a dot does not pass', () {
      final zigzag = [
        [for (var i = 0; i < 40; i++) Offset(i * 8.0, i.isEven ? 0 : 200)],
      ];
      expect(hw.check('ಅ', zigzag).passed, isFalse);
      expect(
        hw.check('ಅ', [
          [const Offset(5, 5)],
        ]).tooSmall,
        isTrue,
      );
    });

    test('notices writing in the wrong order', () {
      expect(hw.strokeHint('ಕ', writing('ಕ')), StrokeHint.ok);
      final backwards = writing('ಕ').reversed.toList();
      expect(hw.strokeHint('ಕ', backwards), isNot(StrokeHint.ok));
      expect(startHint(const Offset(.2, .2)).$2, 'Start at the top left');
    });
  });

  group('smart practice', () {
    test('new letters come in order, mistakes come back first', () {
      expect(practicePlan({}, 100, n: 3), ['ಅ', 'ಆ', 'ಇ']);
      final r = {
        'ಅ': const Review(3, 150),
        'ಆ': const Review(0, 100),
        'ಇ': const Review(2, 99),
      };
      expect(practicePlan(r, 100, n: 3), ['ಆ', 'ಇ', 'ಈ']);
    });

    test('right answers space reviews out, a mistake resets', () {
      var r = const Review(0, 10);
      r = r.answer(right: true, today: 10);
      expect((r.box, r.due), (1, 11));
      r = r.answer(right: true, today: 11).answer(right: true, today: 13);
      expect((r.box, r.due), (3, 17));
      r = r.answer(right: false, today: 17);
      expect((r.box, r.due), (0, 17));
    });

    test('game answers schedule letters for this child', () async {
      final s = await freshState();
      s.recordAnswer('ಕ', right: false);
      expect(s.practiceLetters(2).first, 'ಕ');
      expect(s.child.reviews['ಕ']!.box, 0);
    });
  });

  group('speech check', () {
    test('matches the word, in a sentence or romanised', () {
      expect(speechMatch('ಆನೆ', 'aane', ['ಆನೆ']), 1);
      expect(speechMatch('ಆನೆ', 'aane', ['ಇದು ಆನೆ']), 1);
      expect(speechMatch('ಬಸ್', 'bas', ['bus']), greaterThanOrEqualTo(.6));
      expect(
        speechMatch('ಕಮಲ', 'kamala', ['ಕಮಲಾ']),
        greaterThanOrEqualTo(speechPass),
      );
      expect(speechMatch('ಕಮಲ', 'kamala', ['ಮರ']), lessThan(speechPass));
      expect(speechMatch('ಕಮಲ', 'kamala', []), 0);
    });
  });

  group('online story pack', () {
    test("picks today's story from the pack, else the built-in one", () {
      final pack = {
        'stories': {
          '2026-09-28': {
            'letter': 'ಕ',
            'title': ['ಕಪ್ಪೆಯ ಕಥೆ', 'The frog'],
            'sentences': [
              ['ಕಪ್ಪೆ ಕುಣಿಯಿತು.', 'kappe kuNiyitu.', 'The frog danced.'],
            ],
          },
        },
      };
      final s = storyFor(pack, DateTime(2026, 9, 28))!;
      expect((s.letter, s.online, s.sentences.length), ('ಕ', true, 1));
      expect(storyFor(pack, DateTime(2026, 9, 29)), isNull);
      final off = offlineStory(DateTime(2026, 9, 29));
      expect(off.online, isFalse);
      expect(off.sentences, isNotEmpty);
    });
  });
}
