import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum HearStatus { heard, silent, unavailable, noPermission }

/// What the recogniser heard: its guesses, best first.
class Heard {
  const Heard(this.status, [this.guesses = const []]);
  final HearStatus status;
  final List<String> guesses;
}

/// Kannada speech recognition with the phone's own recogniser. Works on the
/// phone (offline) when the Kannada speech pack is installed; online only
/// when a parent allows it.
class Speech {
  Speech._();
  static final Speech instance = Speech._();

  final SpeechToText _stt = SpeechToText();
  bool? _ready;
  String _locale = 'kn_IN';
  Completer<Heard>? _pending;
  String _lastError = '';

  /// Latest partial result, used if the recogniser stops without a final one.
  String _words = '';

  bool get listening => _stt.isListening;

  Future<bool> _init() async {
    if (_ready == true) return true;
    try {
      _ready = await _stt.initialize(onError: _onError, onStatus: _onStatus);
      if (_ready!) {
        final kn = (await _stt.locales()).where(
          (l) => l.localeId.toLowerCase().startsWith('kn'),
        );
        if (kn.isNotEmpty) _locale = kn.first.localeId;
      }
    } catch (_) {
      _ready = false;
    }
    return _ready!;
  }

  void _onError(SpeechRecognitionError e) {
    _lastError = e.errorMsg;
    _finish(
      e.errorMsg.contains('no_match') || e.errorMsg.contains('speech_timeout')
          ? const Heard(HearStatus.silent)
          : e.errorMsg.contains('permission')
          ? const Heard(HearStatus.noPermission)
          : const Heard(HearStatus.unavailable),
    );
  }

  void _onStatus(String s) {
    // 'done' without a final result: nothing was heard.
    if (s == SpeechToText.doneStatus) {
      Future.delayed(const Duration(milliseconds: 400), () {
        _finish(
          _words.isEmpty
              ? const Heard(HearStatus.silent)
              : Heard(HearStatus.heard, [_words]),
        );
      });
    }
  }

  void _finish(Heard h) {
    final p = _pending;
    if (p != null && !p.isCompleted) p.complete(h);
  }

  /// Why the last attempt failed, for parents.
  String get lastError => _lastError;

  /// Listens for one word. [hint] biases the recogniser towards the word
  /// the child is asked to say; [online] allows the network recogniser.
  Future<Heard> listen({
    required String hint,
    required bool online,
    void Function(String words)? onWords,
  }) async {
    if (!await _init()) {
      final allowed = await _stt.hasPermission.catchError((Object _) => true);
      return Heard(allowed ? HearStatus.unavailable : HearStatus.noPermission);
    }
    _finish(const Heard(HearStatus.silent));
    final done = _pending = Completer<Heard>();
    _words = '';
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          _words = r.recognizedWords;
          onWords?.call(r.recognizedWords);
          if (r.finalResult) {
            _finish(
              Heard(HearStatus.heard, [
                for (final a in r.alternates)
                  if (a.recognizedWords.isNotEmpty) a.recognizedWords,
              ]),
            );
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          onDevice: !online,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
          listenFor: const Duration(seconds: 6),
          pauseFor: const Duration(seconds: 2),
          contextualPhrases: [hint],
        ),
      );
    } catch (_) {
      _finish(const Heard(HearStatus.unavailable));
    }
    return done.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        stop();
        return const Heard(HearStatus.silent);
      },
    );
  }

  void stop() {
    _stt.stop().then((_) {}, onError: (_) {});
  }
}
