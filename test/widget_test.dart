import 'package:akshara_aata/audio.dart';
import 'package:akshara_aata/data.dart';
import 'package:akshara_aata/main.dart';
import 'package:akshara_aata/screens/trace.dart';
import 'package:akshara_aata/state.dart';
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

  test('Kannada maps onto Devanagari for the Hindi voice fallback', () {
    expect(Audio.toDevanagari('ಕ'), 'क');
    expect(Audio.toDevanagari('ಆನೆ'), 'आने');
    expect(Audio.toDevanagari('೩'), '३');
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
    final state = await freshState();
    state.update((s) => s.sfx = false);
    await tester.pumpWidget(AksharaAata(state: state));
    expect(find.text('ಅಕ್ಷರ ಆಟ'), findsOneWidget);

    await tester.tap(find.text('ಸ್ವರಗಳು'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ಆ').first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('2 / 15'), findsOneWidget);
    expect(find.text('🐘'), findsOneWidget);
    expect(state.seen, contains('ಆ'));
  });

  testWidgets('a quiz game can be played to the result screen', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = await freshState();
    state.update((s) => s.sfx = false);
    await tester.pumpWidget(AksharaAata(state: state));
    await tester.tap(find.text('ಆಟಗಳು'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ಎಣಿಸು'));
    await tester.pumpAndSettle();

    for (var round = 0; round < 8; round++) {
      // The prompt row holds N emoji; the right answer is numbers[N].
      final prompt = tester
          .widget<Text>(find.byKey(const ValueKey('count-row')))
          .data!;
      final n = prompt.split(' ').where((x) => x.isNotEmpty).length;
      await tester.tap(find.text(numbers[n].ch));
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();
    }
    expect(find.text('ಶಭಾಷ್!'), findsOneWidget);
    expect(state.stars, 8);
  });
}
