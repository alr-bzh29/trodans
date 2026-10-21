// Lecteur audio unique de l'appli. La lecture continue écran éteint grâce au
// service de premier plan de just_audio_background (notification de lecture).

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'storage.dart';

class Lecteur extends ChangeNotifier {
  static final Lecteur I = Lecteur._();
  Lecteur._() {
    audio.playerStateStream.listen((_) => notifyListeners());
  }

  final AudioPlayer audio = AudioPlayer();

  /// Chemin relatif du titre chargé.
  String? chemin;
  String nom = '';
  String detail = '';

  Stream<Duration> get position => audio.positionStream;
  Duration get duree => audio.duration ?? Duration.zero;
  bool get enLecture => audio.playing;

  /// Charge un titre sans le lancer. Renvoie false si le fichier est absent.
  Future<bool> charger({
    required String chemin,
    required String nom,
    required String detail,
    bool lancer = false,
  }) async {
    final abs = Depot.I.cheminAbsolu(chemin);
    if (!File(abs).existsSync()) return false;
    if (this.chemin != chemin) {
      await audio.stop();
      this.chemin = chemin;
      this.nom = nom;
      this.detail = detail;
      final d = await audio.setAudioSource(
        AudioSource.file(abs, tag: MediaItem(id: chemin, title: nom, artist: detail)),
      );
      if (d != null) unawaited(Depot.I.memoriserDuree(chemin, d));
      notifyListeners();
    }
    if (lancer) unawaited(audio.play());
    return true;
  }

  void basculer() {
    if (chemin == null) return;
    if (audio.playing) {
      audio.pause();
    } else {
      if (audio.processingState == ProcessingState.completed) {
        audio.seek(Duration.zero);
      }
      audio.play();
    }
  }

  Future<void> auDebut() => audio.seek(Duration.zero);

  Future<void> decaler(int secondes) {
    var p = audio.position + Duration(seconds: secondes);
    if (p < Duration.zero) p = Duration.zero;
    if (p > duree) p = duree;
    return audio.seek(p);
  }

  Future<void> aller(Duration p) => audio.seek(p);

  double get volume => audio.volume;
  Future<void> regleVolume(double v) async {
    await audio.setVolume(v);
    notifyListeners();
  }
}
