import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'screens/accueil.dart';
import 'storage.dart';

const couleurPrincipale = Color(0xFF1F4E8C);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'bzh.alr.trodans.lecture',
      androidNotificationChannelName: 'Lecture',
      // Le service reste actif pendant les pauses entre deux danses,
      // pour qu'Android ne coupe pas l'appli téléphone en poche.
      androidStopForegroundOnPause: false,
    );
  }
  await Depot.I.init();
  runApp(const TroDansApp());
}

class TroDansApp extends StatelessWidget {
  const TroDansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TroDañs',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorSchemeSeed: couleurPrincipale,
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
      ),
      home: const Accueil(),
    );
  }
}
