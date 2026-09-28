/// Smart practice: which letters a child should practise next, and whether
/// what the speech recogniser heard matches a word. Pure Dart, runs on the
/// phone.
library;

import 'dart:math' as math;

import 'data.dart';

/// Days between reviews for each Leitner box: a letter moves up a box when
/// the child gets it right and back to box 0 when they get it wrong, so hard
/// letters come back tomorrow and known ones every week or two.
const reviewGaps = [0, 1, 2, 4, 8, 16];

/// Day number used for scheduling.
int dayNumber(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

/// A letter's place in the practice schedule.
class Review {
  const Review(this.box, this.due);
  final int box;
  final int due;

  Review answer({required bool right, required int today}) {
    final b = right ? math.min(box + 1, reviewGaps.length - 1) : 0;
    return Review(b, today + reviewGaps[b]);
  }

  List<int> toJson() => [box, due];
  factory Review.fromJson(List v) => Review(v[0] as int, v[1] as int);
}

/// The [n] letters to practise today: letters that are due (weakest first),
/// then new letters in varnamala order, then the least-known of the rest.
/// At least one new letter is included while there are any, so practice
/// keeps moving forward.
List<String> practicePlan(
  Map<String, Review> reviews,
  int today, {
  int n = 5,
  List<String>? pool,
}) {
  final all = pool ?? [for (final l in letters) l.ch];
  final due =
      all.where((c) => reviews[c] != null && reviews[c]!.due <= today).toList()
        ..sort((a, b) {
          final ra = reviews[a]!, rb = reviews[b]!;
          return ra.box != rb.box
              ? ra.box.compareTo(rb.box)
              : ra.due.compareTo(rb.due);
        });
  final fresh = all.where((c) => reviews[c] == null).toList();
  final plan = <String>[
    ...due.take(fresh.isEmpty ? n : n - 1),
    ...fresh.take(n),
  ].take(n).toList();
  if (plan.length < n) {
    final rest = all.where((c) => !plan.contains(c)).toList()
      ..sort((a, b) => reviews[a]!.box.compareTo(reviews[b]!.box));
    plan.addAll(rest.take(n - plan.length));
  }
  return plan;
}

/// Only the Kannada letters of [s], without spaces or joiners.
String _kannada(String s) =>
    String.fromCharCodes(s.runes.where((c) => c >= 0x0C80 && c <= 0x0CFF));

int _editDistance(List<int> a, List<int> b) {
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = [i, ...List.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

double _similarity(String a, String b) {
  final x = a.runes.toList(), y = b.runes.toList();
  if (x.isEmpty || y.isEmpty) return 0;
  return 1 - _editDistance(x, y) / math.max(x.length, y.length);
}

/// How well the recogniser's guesses [heard] match [word] (Kannada) or its
/// romanisation [roman], from 0 to 1. Each guess is compared whole and word
/// by word, so "ಇದು ಆನೆ" still matches ಆನೆ.
double speechMatch(String word, String roman, List<String> heard) {
  final target = _kannada(word);
  final latin = roman.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  var best = 0.0;
  for (final h in heard) {
    final parts = [h, ...h.split(RegExp(r'\s+'))];
    for (final p in parts) {
      final kn = _kannada(p);
      if (kn.isNotEmpty) best = math.max(best, _similarity(target, kn));
      final en = p.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
      if (en.isNotEmpty && latin.isNotEmpty) {
        best = math.max(best, _similarity(latin, en));
      }
    }
  }
  return best;
}

/// A spoken word counts as right from this similarity up.
const speechPass = .75;

/// "Almost": encourage another try.
const speechClose = .45;
