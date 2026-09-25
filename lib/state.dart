import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

/// Progress and settings, saved on the device only.
class AppState extends ChangeNotifier {
  AppState(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        stars = m['stars'] as int? ?? 0;
        seen.addAll((m['seen'] as List? ?? const []).cast<String>());
        traced.addAll((m['traced'] as List? ?? const []).cast<String>());
        voice = m['voice'] as bool? ?? true;
        sfx = m['sfx'] as bool? ?? true;
        roman = m['roman'] as bool? ?? true;
        rate = (m['rate'] as num? ?? rate).toDouble();
      } catch (_) {
        // Corrupt data: start fresh rather than crash.
      }
    }
  }

  static const _key = 'akshara-aata-v1';
  final SharedPreferences _prefs;

  int stars = 0;
  final Set<String> seen = {};
  final Set<String> traced = {};
  bool voice = true;
  bool sfx = true;
  bool roman = true;
  double rate = 0.4;

  int get stickersUnlocked => (stars ~/ 10).clamp(0, stickers.length);

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({
        'stars': stars,
        'seen': seen.toList(),
        'traced': traced.toList(),
        'voice': voice,
        'sfx': sfx,
        'roman': roman,
        'rate': rate,
      }),
    );
    notifyListeners();
  }

  void markSeen(String ch) {
    if (seen.add(ch)) _save();
  }

  /// Returns true the first time a letter is traced.
  bool markTraced(String ch) {
    final first = traced.add(ch);
    if (first) _save();
    return first;
  }

  /// Adds stars and returns a newly unlocked sticker, if any.
  String? addStars(int n) {
    if (n <= 0) return null;
    final before = stickersUnlocked;
    stars += n;
    _save();
    return stickersUnlocked > before ? stickers[stickersUnlocked - 1] : null;
  }

  void update(void Function(AppState s) change) {
    change(this);
    _save();
  }

  void reset() {
    stars = 0;
    seen.clear();
    traced.clear();
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
