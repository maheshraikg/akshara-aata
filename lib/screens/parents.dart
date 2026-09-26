import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio.dart';
import '../data.dart';
import '../main.dart';
import '../state.dart';
import '../widgets.dart';
import 'studio.dart';

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

  String get _voiceText =>
      '✅ Every letter, word, number and kagunita sound is built into the app, so it works offline on any phone. '
      '${Audio.instance.kind == VoiceKind.kannada ? "The phone's Kannada voice is used only for anything without a recording." : "Tip: installing the Kannada text-to-speech voice (Settings → Accessibility → Text-to-speech) is optional."}';

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
              sw(
                'Male voice (Chetan) instead of female (Vidya)',
                s.maleVoice,
                (st, x) => st.maleVoice = x,
              ),
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
                  '🔊 Test: ಆನೆ',
                  small: true,
                  onTap: () => Audio.instance.speak('ಆನೆ', 'aane'),
                ),
              ),
            ],
          ),
          _Panel(
            children: [
              const _H('Children'),
              const Text(
                'Each child keeps their own stars, stickers, streak and report. Tap to switch.',
                style: TextStyle(color: K.inkSoft, fontSize: 15),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < s.profiles.length; i++)
                    GestureDetector(
                      onTap: () => s.switchProfile(i),
                      onLongPress: s.profiles.length > 1
                          ? () => _confirmRemove(context, i)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 14, 4),
                        decoration: BoxDecoration(
                          color: i == s.current
                              ? K.pastel(K.green, .25)
                              : K.paper,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: i == s.current
                                ? K.green
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Pic(s.profiles[i].avatar, size: 36),
                            const SizedBox(width: 8),
                            Text(
                              s.profiles[i].name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  PillButton(
                    '+ Add child',
                    small: true,
                    color: K.blue,
                    base: K.blueDeep,
                    onTap: () => _addChild(context),
                  ),
                ],
              ),
              if (s.profiles.length > 1)
                const Text(
                  'Long-press a name to remove that child.',
                  style: TextStyle(color: K.inkSoft, fontSize: 13),
                ),
            ],
          ),
          _Panel(
            children: [
              _H('Report · ${s.child.name}'),
              Text(
                '${s.seen.length} / 49 letters explored · ${s.traced.length} / 49 written · ${s.stars} stars · ${s.streak}-day streak',
                style: const TextStyle(color: K.inkSoft, fontSize: 15),
              ),
              const _Legend(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final l in letters)
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: s.traced.contains(l.ch)
                            ? K.pastel(K.green, .45)
                            : s.seen.contains(l.ch)
                            ? K.pastel(K.turmeric, .45)
                            : const Color(0xFFEDEAF2),
                        borderRadius: BorderRadius.circular(12),
                        border: s.child.weak.containsKey(l.ch)
                            ? Border.all(color: K.red, width: 2.5)
                            : null,
                      ),
                      child: Text(
                        l.ch,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              if (s.weakLetters.isNotEmpty)
                Text(
                  'Needs practice: ${s.weakLetters.take(8).join('  ')}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: K.redDeep,
                  ),
                )
              else
                const Text(
                  'No weak letters yet. Mistakes in the games show up here.',
                  style: TextStyle(color: K.inkSoft, fontSize: 14),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: PillButton(
                  _armed
                      ? 'Tap again to erase ${s.child.name}\'s progress'
                      : 'Reset this child\'s progress',
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
          _Panel(
            children: [
              const _H('Language'),
              sw(
                'English help (sounds like "ka", meanings and subtitles). Turn off for Kannada only.',
                s.roman,
                (st, x) => st.roman = x,
              ),
            ],
          ),
          _Panel(
            children: [
              const _H('Record a native voice'),
              const Text(
                'AI voices can mispronounce single Kannada letters (for example ಖ said as two syllables, or ಕ with English breath). A parent or teacher who speaks Kannada can record every letter here. Recordings replace the built-in voice on this phone, and "Send recordings" shares them so they can be built into the app for every child.',
                style: TextStyle(color: K.inkSoft, fontSize: 15, height: 1.4),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: PillButton(
                  'Open recording studio',
                  small: true,
                  color: K.red,
                  base: K.redDeep,
                  onTap: () => push(context, const StudioScreen()),
                ),
              ),
            ],
          ),
          _Panel(
            children: [
              const _H('Writing demos (teachers)'),
              const Text(
                'Show children the correct stroke order: turn this on, open a letter in "ಬರೆಯೋಣ", write it slowly in the right order, then tap "Save demo". Children then see a "Watch" button that replays your writing.',
                style: TextStyle(color: K.inkSoft, fontSize: 15, height: 1.4),
              ),
              sw('Teacher mode', s.teacherMode, (st, x) => st.teacherMode = x),
              Text(
                '${s.demos.length} letters have a writing demo.',
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
          const _Panel(
            children: [
              _H('About'),
              Text(
                'Akshara Aata teaches the 49 letters of the Kannada varnamala (13 swaras, 2 yogavahas, 34 vyanjanas), kagunita and numbers through listening, tracing and games. No accounts and no in-app purchases. Progress stays on this phone. Ads are child-safe: G-rated, not personalised, never during learning, tracing or a game. Human recordings from Wikimedia Commons: letters by Surabhi18 (CC BY-SA 4.0); words from Lingua Libre by AnshulBhagwat and Brusquedandelion (CC0) and Shilpa Bhat N H (CC BY-SA 4.0). Other words: AI4Bharat Indic Parler-TTS (Apache-2.0). Stroke order in the writing animations: from animations by Gopala Krishna A, Wikimedia Commons (CC BY-SA 4.0). Pictures: Microsoft Fluent Emoji 3D, MIT license.',
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

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontSize: 13, color: K.inkSoft)),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        dot(K.pastel(K.green, .45), 'Written'),
        dot(K.pastel(K.turmeric, .45), 'Explored'),
        dot(const Color(0xFFEDEAF2), 'Not yet'),
        dot(Colors.white, 'Red border = needs practice'),
      ],
    );
  }
}

const _avatars = ['🧒', '👧', '👦', '🐘', '🦚', '🐯', '🦁', '🐬'];

void _addChild(BuildContext context) {
  final s = AppScope.read(context);
  final name = TextEditingController();
  var avatar = _avatars[s.profiles.length % _avatars.length];
  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Add a child'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              maxLength: 16,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in _avatars)
                  GestureDetector(
                    onTap: () => setD(() => avatar = a),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: a == avatar
                            ? K.pastel(K.green, .35)
                            : Colors.transparent,
                      ),
                      child: Pic(a, size: 40),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = name.text.trim();
              if (n.isEmpty) return;
              s.addProfile(n, avatar);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}

void _confirmRemove(BuildContext context, int i) {
  final s = AppScope.read(context);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Remove ${s.profiles[i].name}?'),
      content: const Text('Their stars and progress will be deleted.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: K.red),
          onPressed: () {
            s.removeProfile(i);
            Navigator.pop(ctx);
          },
          child: const Text('Remove'),
        ),
      ],
    ),
  );
}
