import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../main.dart';
import '../state.dart';
import '../widgets.dart';

/// Keeps settings away from small children: answer a sum to continue.
class ParentGateScreen extends StatefulWidget {
  const ParentGateScreen({super.key});

  @override
  State<ParentGateScreen> createState() => _ParentGateScreenState();
}

class _ParentGateScreenState extends State<ParentGateScreen> {
  final _rnd = math.Random();
  late final int a = 3 + _rnd.nextInt(6), b = 4 + _rnd.nextInt(5);
  late final List<int> opts = ([a + b, a + b + 2, a + b - 3, a + b + 5]
    ..shuffle(_rnd));

  @override
  Widget build(BuildContext context) => KidPage(
    title: 'For parents',
    sub: 'Ask a grown-up',
    child: _Panel(
      children: [
        const Text(
          'Grown-ups only: tap the answer to open settings.',
          style: TextStyle(color: K.inkSoft, fontSize: 16),
        ),
        Center(
          child: Text(
            '$a + $b = ?',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 12,
          childAspectRatio: 2,
          children: [
            for (final o in opts)
              PillButton(
                '$o',
                color: K.white,
                base: K.shade,
                fg: K.ink,
                onTap: () => o == a + b
                    ? replace(context, const ParentsScreen())
                    : Navigator.of(context).maybePop(),
              ),
          ],
        ),
      ],
    ),
  );
}

class ParentsScreen extends StatefulWidget {
  const ParentsScreen({super.key});

  @override
  State<ParentsScreen> createState() => _ParentsScreenState();
}

class _ParentsScreenState extends State<ParentsScreen> {
  bool _armed = false;

  String get _voiceText => switch (Audio.instance.kind) {
    VoiceKind.kannada => '✅ Kannada voice is installed.',
    VoiceKind.hindi => '⚠️ No Kannada voice on this phone, so the Hindi voice reads the letters (close, but not perfect). For the best sound, install Kannada: Settings → Accessibility → Text-to-speech → Speech Services by Google → Install voice data → Kannada, then reopen the app.',
    _ => '⚠️ No Kannada voice on this phone. Install it: Settings → Accessibility → Text-to-speech → Speech Services by Google → Install voice data → Kannada, then reopen the app.',
  };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget sw(String label, bool v, void Function(AppState, bool) set) => Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 17))),
        Switch(
          value: v,
          activeTrackColor: K.green,
          onChanged: (x) => s.update((st) => set(st, x)),
        ),
      ],
    );
    return KidPage(
      title: 'Parents',
      sub: 'Settings & progress',
      child: Column(
        children: [
          _Panel(
            children: [
              const _H('Sound'),
              sw('Speak letters aloud', s.voice, (st, x) => st.voice = x),
              sw('Game sound effects', s.sfx, (st, x) => st.sfx = x),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Speaking speed',
                      style: TextStyle(fontSize: 17),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: Slider(
                      value: s.rate.clamp(.2, .7),
                      min: .2,
                      max: .7,
                      activeColor: K.blue,
                      onChanged: (x) => s.update((st) => st.rate = x),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: K.paper,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_voiceText, style: const TextStyle(fontSize: 15)),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: PillButton(
                  '🔊 Test: ಅ ಆ ಇ',
                  small: true,
                  onTap: () => Audio.instance.speak('ಅ ಆ ಇ', 'a aa i'),
                ),
              ),
            ],
          ),
          _Panel(
            children: [
              const _H('Display'),
              sw(
                'Show English sounds (a, aa, ka…) and meanings',
                s.roman,
                (st, x) => st.roman = x,
              ),
            ],
          ),
          _Panel(
            children: [
              const _H('Progress'),
              Text(
                '${s.seen.length} letters explored · ${s.traced.length} letters written · ${s.stars} stars',
                style: const TextStyle(color: K.inkSoft, fontSize: 16),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: PillButton(
                  _armed ? 'Tap again to erase all progress' : 'Reset progress',
                  small: true,
                  color: K.red,
                  base: K.redDeep,
                  onTap: () {
                    if (!_armed) {
                      setState(() => _armed = true);
                      return;
                    }
                    s.reset();
                    setState(() => _armed = false);
                    toast(context, 'Progress reset');
                  },
                ),
              ),
            ],
          ),
          const _Panel(
            children: [
              _H('About'),
              Text(
                'Akshara Aata teaches the 49 letters of the Kannada varnamala (13 swaras, 2 yogavahas, 34 vyanjanas), kagunita and numbers through listening, tracing and games. No accounts and no in-app purchases. Progress stays on this phone. Ads are child-safe: G-rated, not personalised, never during learning, tracing or a game.',
                style: TextStyle(color: K.inkSoft, fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: K.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [BoxShadow(color: K.shade, offset: Offset(0, 6))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    ),
  );
}
