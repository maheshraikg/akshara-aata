import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'data.dart';
import 'state.dart';

enum VoiceKind { kannada, hindi, english, none }

/// Kannada speech from recordings bundled in assets/audio/, falling back to
/// the phone's text-to-speech; plus small synthesized sound effects.
class Audio {
  Audio._();
  static final Audio instance = Audio._();

  final FlutterTts _tts = FlutterTts();
  VoiceKind kind = VoiceKind.none;
  AppState? state;
  final Map<String, AudioPlayer> _players = {};
  final Map<String, Uint8List> _sounds = {};

  /// Prepares sound effects right away and the voice in the background.
  /// Never awaits the text-to-speech engine: flutter_tts holds every call
  /// until the phone's engine reports ready, and on phones where it is slow,
  /// missing or broken that never happens.
  void init(AppState s) {
    state = s;
    _makeSounds();
    unawaited(_loadRecordings());
    unawaited(_setUpVoice());
  }

  /// audioKey()s that have a bundled recording.
  final Set<String> _recorded = {};
  AudioPlayer? _voicePlayer;

  bool hasRecording(String kannada) => _recorded.contains(audioKey(kannada));

  Future<void> _loadRecordings() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final a in manifest.listAssets()) {
        if (a.startsWith('assets/audio/') && a.endsWith('.ogg')) {
          _recorded.add(a.substring(13, a.length - 4));
        }
      }
    } catch (_) {}
  }

  static const _ttsTimeout = Duration(seconds: 8);

  Future<void> _setUpVoice() async {
    try {
      await _tts.awaitSpeakCompletion(false).timeout(_ttsTimeout);
      if (await _available('kn-IN')) {
        await _tts.setLanguage('kn-IN').timeout(_ttsTimeout);
        kind = VoiceKind.kannada;
      } else if (await _available('hi-IN')) {
        await _tts.setLanguage('hi-IN').timeout(_ttsTimeout);
        kind = VoiceKind.hindi;
      } else if (await _available('en-IN')) {
        await _tts.setLanguage('en-IN').timeout(_ttsTimeout);
        kind = VoiceKind.english;
      }
      await _tts.setPitch(1.1).timeout(_ttsTimeout);
    } catch (_) {
      // Timed out or no engine: the app works silently.
    }
  }

  void _makeSounds() {
    _sounds['tap'] = _wav([(660, 0, .08)], wave: _triangle, vol: .15);
    _sounds['right'] = _wav([
      (523, 0, .14),
      (659, .1, .14),
      (784, .2, .25),
    ], wave: _triangle);
    _sounds['wrong'] = _wav([(220, 0, .2), (180, .12, .25)], vol: .2);
    _sounds['pop'] = _wav(
      [(900, 0, .06), (1300, .03, .06)],
      wave: _square,
      vol: .1,
    );
    _sounds['win'] = _wav([
      (523, 0, .3),
      (659, .12, .3),
      (784, .24, .3),
      (1047, .36, .35),
    ], wave: _triangle);
  }

  Future<bool> _available(String lang) async {
    try {
      final r = await _tts.isLanguageAvailable(lang).timeout(_ttsTimeout);
      return r == true || r == 1;
    } catch (_) {
      return false;
    }
  }

  /// Kannada and Devanagari share the Brahmi layout, so a Hindi voice can read
  /// a shifted string. Short e/o have no Hindi sound, so they map to long ones.
  static String toDevanagari(String s) {
    const fix = {
      0x0C8E: 0x090F,
      0x0C92: 0x0913,
      0x0CC6: 0x0947,
      0x0CCA: 0x094B,
    };
    final out = StringBuffer();
    for (final c in s.runes) {
      if (fix.containsKey(c)) {
        out.writeCharCode(fix[c]!);
      } else if (c >= 0x0C80 && c <= 0x0CFF) {
        out.writeCharCode(c - 0x380);
      } else {
        out.writeCharCode(c);
      }
    }
    return out.toString();
  }

  Future<void> speak(String kannada, String roman) async {
    final s = state;
    if (s == null || !s.voice) return;
    final key = audioKey(kannada);
    if (_recorded.contains(key)) {
      try {
        final p = _voicePlayer ??= AudioPlayer()
          ..setReleaseMode(ReleaseMode.stop);
        await p.stop();
        // Speed slider (0.2–0.7, default 0.4) maps to 0.7×–1.2× playback.
        await p.setPlaybackRate(.5 + s.rate);
        await p.play(AssetSource('audio/$key.ogg'));
      } catch (_) {}
      return;
    }
    if (kind == VoiceKind.none) return;
    final text = switch (kind) {
      VoiceKind.kannada => kannada,
      VoiceKind.hindi => toDevanagari(kannada),
      _ => roman,
    };
    try {
      await _tts.stop().timeout(_ttsTimeout);
      await _tts.setSpeechRate(s.rate).timeout(_ttsTimeout);
      await _tts.speak(text).timeout(_ttsTimeout);
    } catch (_) {}
  }

  /// Fire-and-forget: nothing waits on stopping speech.
  void stop() {
    if (state == null) return;
    _voicePlayer?.stop().then((_) {}, onError: (_) {});
    _tts.stop().then((_) {}, onError: (_) {});
  }

  void tap() => _play('tap');
  void right() => _play('right');
  void wrong() => _play('wrong');
  void pop() => _play('pop');
  void win() => _play('win');

  Future<void> _play(String name) async {
    if (state?.sfx != true) return;
    final bytes = _sounds[name];
    if (bytes == null) return;
    try {
      final p = _players.putIfAbsent(name, () {
        final ap = AudioPlayer();
        ap.setReleaseMode(ReleaseMode.stop);
        return ap;
      });
      await p.stop();
      await p.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {}
  }

  static double _triangle(double p) => 1 - 4 * ((p - .25) % 1 - .5).abs();
  static double _square(double p) => p % 1 < .5 ? 1 : -1;
  static double _sine(double p) => math.sin(2 * math.pi * p);

  /// Builds a 16-bit mono WAV from (frequency, start, duration) notes.
  static Uint8List _wav(
    List<(double, double, double)> notes, {
    double Function(double) wave = _sine,
    double vol = .25,
  }) {
    const rate = 22050;
    final end = notes.map((n) => n.$2 + n.$3).reduce(math.max) + .05;
    final count = (end * rate).ceil();
    final pcm = Float64List(count);
    for (final (f, start, dur) in notes) {
      final s0 = (start * rate).floor();
      final len = (dur * rate).floor();
      for (var i = 0; i < len && s0 + i < count; i++) {
        final t = i / rate;
        final env = math.min(1.0, t / .02) * math.exp(-4 * t / dur);
        pcm[s0 + i] += wave(f * t) * env * vol;
      }
    }
    final data = ByteData(44 + count * 2);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + count * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, count * 2, Endian.little);
    for (var i = 0; i < count; i++) {
      data.setInt16(
        44 + i * 2,
        (pcm[i].clamp(-1.0, 1.0) * 32767).round(),
        Endian.little,
      );
    }
    return data.buffer.asUint8List();
  }
}
