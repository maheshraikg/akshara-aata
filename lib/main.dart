import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads.dart';
import 'audio.dart';
import 'screens/home.dart';
import 'state.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Only local storage is awaited before the first frame; voice and ads set
  // themselves up in the background so a slow phone service can't keep the
  // app on a blank screen.
  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );
  final state = AppState(await SharedPreferences.getInstance());
  Audio.instance.init(state);
  unawaited(Ads.init());
  runApp(AksharaAata(state: state));
}

class AksharaAata extends StatelessWidget {
  const AksharaAata({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'BalooTamma2',
      scaffoldBackgroundColor: K.ivory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: K.red,
        brightness: Brightness.light,
        surface: K.ivory,
      ),
    );
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'ಅಕ್ಷರ ಆಟ',
        debugShowCheckedModeBanner: false,
        theme: base.copyWith(
          textTheme: base.textTheme.apply(
            bodyColor: K.ink,
            displayColor: K.ink,
            fontFamily: 'BalooTamma2',
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

/// Pushes a screen, stopping any speech from the one we leave.
Future<T?> push<T>(BuildContext context, Widget screen) {
  Audio.instance.stop();
  return Navigator.of(context).push<T>(
    PageRouteBuilder(
      pageBuilder: (_, _, _) => screen,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, a, _, child) {
        final curve = CurvedAnimation(parent: a, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: .92, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Swaps the current screen (next letter, play again…).
void replace(BuildContext context, Widget screen) {
  Audio.instance.stop();
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      pageBuilder: (_, _, _) => screen,
      transitionDuration: const Duration(milliseconds: 160),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    ),
  );
}
