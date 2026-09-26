import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One child's progress.
class Profile {
  Profile(this.name, this.avatar);

  String name;

  /// Emoji shown as a 3D picture.
  String avatar;
  int stars = 0;
  final Set<String> seen = {};
  final Set<String> traced = {};

  /// Wrong answers per letter in games, lowered again by right answers.
  final Map<String, int> weak = {};
  int streak = 0;
  String lastDay = '';

  /// Letters explored or written today.
  final Set<String> today = {};

  factory Profile.fromJson(Map<String, dynamic> m) =>
      Profile(m['name'] as String? ?? 'ಮಗು', m['avatar'] as String? ?? '🧒')
        ..stars = m['stars'] as int? ?? 0
        ..seen.addAll((m['seen'] as List? ?? const []).cast<String>())
        ..traced.addAll((m['traced'] as List? ?? const []).cast<String>())
        ..weak.addAll(
          (m['weak'] as Map? ?? const {}).map(
            (k, v) => MapEntry(k as String, v as int),
          ),
        )
        ..streak = m['streak'] as int? ?? 0
        ..lastDay = m['lastDay'] as String? ?? ''
        ..today.addAll((m['today'] as List? ?? const []).cast<String>());

  Map<String, dynamic> toJson() => {
    'name': name,
    'avatar': avatar,
    'stars': stars,
    'seen': seen.toList(),
    'traced': traced.toList(),
    'weak': weak,
    'streak': streak,
    'lastDay': lastDay,
    'today': today.toList(),
  };
}

/// Progress and settings, saved on the device only.
class AppState extends ChangeNotifier {
  AppState(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final list = m['profiles'] as List?;
        if (list != null && list.isNotEmpty) {
          profiles.addAll(
            list.map((p) => Profile.fromJson(p as Map<String, dynamic>)),
          );
          current = (m['current'] as int? ?? 0).clamp(0, profiles.length - 1);
        } else {
          // Version 1 kept one child's progress at the top level.
          profiles.add(Profile.fromJson({...m, 'name': 'ಮಗು'}));
        }
        voice = m['voice'] as bool? ?? true;
        sfx = m['sfx'] as bool? ?? true;
        roman = m['roman'] as bool? ?? true;
        maleVoice = m['maleVoice'] as bool? ?? false;
        teacherMode = m['teacherMode'] as bool? ?? false;
        rate = (m['rate'] as num? ?? rate).toDouble();
        final d = m['demos'] as Map?;
        if (d != null) {
          demos.addAll(
            d.map(
              (k, v) => MapEntry(k as String, [
                for (final stroke in v as List)
                  [
                    for (final pt in stroke as List)
                      Offset(
                        (pt[0] as num).toDouble(),
                        (pt[1] as num).toDouble(),
                      ),
                  ],
              ]),
            ),
          );
        }
      } catch (_) {
        // Corrupt data: start fresh rather than crash.
      }
    }
    if (profiles.isEmpty) profiles.add(Profile('ಮಗು', '🧒'));
  }

  static const _key = 'akshara-aata-v1';
  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  final List<Profile> profiles = [];
  int current = 0;
  bool voice = true;
  bool sfx = true;

  /// Show English help (sounds, meanings, subtitles).
  bool roman = true;

  /// Chetan (male) instead of Vidya (female) for built-in speech.
  bool maleVoice = false;
  double rate = 0.4;

  /// Shows the 'save as writing demo' button on the trace screen.
  bool teacherMode = false;

  /// Teacher-recorded writing demos: letter → strokes of points in 0–1.
  final Map<String, List<List<Offset>>> demos = {};

  Profile get child => profiles[current];
  int get stars => child.stars;
  Set<String> get seen => child.seen;
  Set<String> get traced => child.traced;
  int get stickersUnlocked => (stars ~/ 10).clamp(0, stickers.length);

  /// Days in a row with learning, counting today only once something was done.
  int get streak {
    final today = _day(_clock());
    final yesterday = _day(_clock().subtract(const Duration(days: 1)));
    return child.lastDay == today || child.lastDay == yesterday
        ? child.streak
        : 0;
  }

  int get todayCount =>
      child.lastDay == _day(_clock()) ? child.today.length : 0;

  /// Letters with the most game mistakes, worst first.
  List<String> get weakLetters =>
      (child.weak.entries.where((e) => e.value > 0).toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .map((e) => e.key)
          .toList();

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({
        'profiles': [for (final p in profiles) p.toJson()],
        'current': current,
        'voice': voice,
        'sfx': sfx,
        'roman': roman,
        'maleVoice': maleVoice,
        'teacherMode': teacherMode,
        'rate': rate,
        'demos': demos.map(
          (k, v) => MapEntry(k, [
            for (final s in v)
              [
                for (final o in s)
                  [
                    double.parse(o.dx.toStringAsFixed(3)),
                    double.parse(o.dy.toStringAsFixed(3)),
                  ],
              ],
          ]),
        ),
      }),
    );
    notifyListeners();
  }

  /// Counts today towards the streak and today's letters.
  void _touch(String? ch) {
    final today = _day(_clock());
    final p = child;
    if (p.lastDay != today) {
      final yesterday = _day(_clock().subtract(const Duration(days: 1)));
      p.streak = p.lastDay == yesterday ? p.streak + 1 : 1;
      p.lastDay = today;
      p.today.clear();
    }
    if (ch != null) p.today.add(ch);
  }

  void markSeen(String ch) {
    final before = todayCount;
    final added = seen.add(ch);
    _touch(ch);
    if (added || todayCount != before) _save();
  }

  /// Returns true the first time a letter is traced.
  bool markTraced(String ch) {
    final first = traced.add(ch);
    _touch(ch);
    _save();
    return first;
  }

  /// Adds stars and returns a newly unlocked sticker, if any.
  String? addStars(int n) {
    if (n <= 0) return null;
    final before = stickersUnlocked;
    child.stars += n;
    _touch(null);
    _save();
    return stickersUnlocked > before ? stickers[stickersUnlocked - 1] : null;
  }

  /// A game answer for [ch]: mistakes raise its weak score, right answers
  /// lower it.
  void recordAnswer(String ch, {required bool right}) {
    final w = child.weak[ch] ?? 0;
    final next = right ? (w - 1).clamp(0, 99) : w + 1;
    if (next == w) return;
    if (next == 0) {
      child.weak.remove(ch);
    } else {
      child.weak[ch] = next;
    }
    _save();
  }

  void update(void Function(AppState s) change) {
    change(this);
    _save();
  }

  void addProfile(String name, String avatar) {
    profiles.add(Profile(name, avatar));
    current = profiles.length - 1;
    _save();
  }

  void switchProfile(int i) {
    current = i.clamp(0, profiles.length - 1);
    _save();
  }

  void removeProfile(int i) {
    if (profiles.length <= 1) return;
    profiles.removeAt(i);
    current = current.clamp(0, profiles.length - 1);
    _save();
  }

  void saveDemo(String ch, List<List<Offset>> strokes) {
    demos[ch] = strokes;
    _save();
  }

  void deleteDemo(String ch) {
    if (demos.remove(ch) != null) _save();
  }

  /// Clears the current child's progress.
  void reset() {
    final p = child;
    profiles[current] = Profile(p.name, p.avatar);
    _save();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without rebuilding when state changes.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
