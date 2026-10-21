// Lecture et écriture des fichiers de TroDañs.
//
// - Réglages et index de la sonothèque : propres à l'appareil (dossier privé de l'appli).
// - Cours et notes de danses : un fichier JSON par fiche dans le dossier de données,
//   que Syncthing peut synchroniser entre le téléphone et le PC.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models.dart';
import 'util.dart';

class Reglages {
  String racineMusique;
  String dossierDonnees;

  Reglages({required this.racineMusique, required this.dossierDonnees});

  factory Reglages.parDefaut() {
    if (Platform.isAndroid) {
      return Reglages(
        racineMusique: '/storage/emulated/0/Music',
        dossierDonnees: '/storage/emulated/0/TroDans',
      );
    }
    final home = Platform.environment['HOME'] ?? '.';
    return Reglages(racineMusique: '$home/Music', dossierDonnees: '$home/TroDans');
  }

  factory Reglages.fromJson(Map<String, dynamic> j) {
    final d = Reglages.parDefaut();
    return Reglages(
      racineMusique: (j['racineMusique'] as String?) ?? d.racineMusique,
      dossierDonnees: (j['dossierDonnees'] as String?) ?? d.dossierDonnees,
    );
  }

  Map<String, dynamic> toJson() =>
      {'racineMusique': racineMusique, 'dossierDonnees': dossierDonnees};
}

/// Écrit un fichier de façon atomique (fichier temporaire puis renommage),
/// pour que Syncthing ne voie jamais un fichier à moitié écrit.
Future<void> ecrireJson(File f, Object data) async {
  await f.parent.create(recursive: true);
  final tmp = File('${f.parent.path}/.${f.uri.pathSegments.last}.tmp');
  await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(data), flush: true);
  await tmp.rename(f.path);
}

Future<Map<String, dynamic>?> lireJson(File f) async {
  try {
    if (!await f.exists()) return null;
    final v = jsonDecode(await f.readAsString());
    return v is Map ? Map<String, dynamic>.from(v) : null;
  } catch (_) {
    return null;
  }
}

class Depot {
  static final Depot I = Depot._();
  Depot._();

  late Directory _prive;
  Reglages reglages = Reglages.parDefaut();
  List<Titre> titres = [];
  DateTime? dernierScan;

  File get _fichierReglages => File('${_prive.path}/reglages.json');
  File get _fichierIndex => File('${_prive.path}/sonotheque.json');
  Directory get _dossierCours => Directory('${reglages.dossierDonnees}/cours');
  Directory get _dossierDanses => Directory('${reglages.dossierDonnees}/danses');

  Future<void> init() async {
    _prive = await getApplicationSupportDirectory();
    final r = await lireJson(_fichierReglages);
    if (r != null) reglages = Reglages.fromJson(r);
    final idx = await lireJson(_fichierIndex);
    if (idx != null) {
      titres = ((idx['titres'] as List?) ?? [])
          .map((e) => Titre.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final d = idx['dernierScan'] as String?;
      dernierScan = d == null ? null : DateTime.tryParse(d);
    }
  }

  Future<void> sauverReglages() => ecrireJson(_fichierReglages, reglages.toJson());

  Future<void> sauverIndex() => ecrireJson(_fichierIndex, {
        'dernierScan': dernierScan?.toIso8601String(),
        'titres': titres.map((t) => t.toJson()).toList(),
      });

  // ---------- Permissions ----------

  /// Demande l'accès aux fichiers. Renvoie true si l'accès est accordé.
  Future<bool> demanderAcces() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.manageExternalStorage.request().isGranted) return true;
    // Android 7 à 10 : permission de stockage classique.
    return Permission.storage.request().isGranted;
  }

  Future<bool> accesAccorde() async {
    if (!Platform.isAndroid) return true;
    return await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted;
  }

  // ---------- Sonothèque ----------

  String cheminAbsolu(String relatif) => '${reglages.racineMusique}/$relatif';

  /// Parcourt la sonothèque. Conserve les durées déjà connues.
  /// Renvoie le nombre de titres trouvés.
  Future<int> scanner() async {
    final racine = Directory(reglages.racineMusique);
    if (!await racine.exists()) {
      throw Exception('Dossier introuvable : ${reglages.racineMusique}');
    }
    final anciens = {for (final t in titres) t.chemin: t};
    final trouves = <Titre>[];
    final prefixe = racine.path.endsWith('/') ? racine.path.length : racine.path.length + 1;

    Future<void> parcourir(Directory d) async {
      List<FileSystemEntity> enfants;
      try {
        enfants = await d.list(followLinks: false).toList();
      } catch (_) {
        return; // dossier illisible : on l'ignore
      }
      for (final e in enfants) {
        final nom = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (nom.startsWith('.')) continue;
        if (e is Directory) {
          await parcourir(e);
        } else if (e is File) {
          final bas = nom.toLowerCase();
          if (bas.endsWith('.mp3') || bas.endsWith('.ogg')) {
            final rel = e.path.substring(prefixe);
            final t = Titre.depuisChemin(rel);
            t.dureeMs = anciens[rel]?.dureeMs;
            trouves.add(t);
          }
        }
      }
    }

    await parcourir(racine);
    trouves.sort((a, b) {
      final c = plier(a.danse ?? '~').compareTo(plier(b.danse ?? '~'));
      return c != 0 ? c : plier(a.titre).compareTo(plier(b.titre));
    });
    titres = trouves;
    dernierScan = DateTime.now();
    await sauverIndex();
    return trouves.length;
  }

  Titre? titreParChemin(String? chemin) {
    if (chemin == null) return null;
    for (final t in titres) {
      if (t.chemin == chemin) return t;
    }
    return null;
  }

  Future<void> memoriserDuree(String chemin, Duration d) async {
    final t = titreParChemin(chemin);
    if (t == null || t.dureeMs == d.inMilliseconds) return;
    t.dureeMs = d.inMilliseconds;
    await sauverIndex();
  }

  // ---------- Cours ----------

  Future<List<Cours>> listerCours() async {
    final res = <Cours>[];
    if (!await _dossierCours.exists()) return res;
    await for (final e in _dossierCours.list()) {
      final nom = e.uri.pathSegments.last;
      // Les copies de conflit Syncthing sont ignorées ici (à traiter plus tard).
      if (e is! File || !nom.endsWith('.json') || nom.startsWith('.') || nom.contains('sync-conflict')) {
        continue;
      }
      final j = await lireJson(e);
      if (j == null) continue;
      try {
        res.add(Cours.fromJson(j));
      } catch (_) {}
    }
    res.sort((a, b) => b.date.compareTo(a.date));
    return res;
  }

  Future<void> sauverCours(Cours c) =>
      ecrireJson(File('${_dossierCours.path}/${c.date}.json'), c.toJson());

  Future<void> supprimerCours(Cours c) async {
    final f = File('${_dossierCours.path}/${c.date}.json');
    if (await f.exists()) await f.delete();
  }

  Future<bool> coursExiste(String date) => File('${_dossierCours.path}/$date.json').exists();

  // ---------- Danses ----------

  Future<Danse> lireDanse(String nom) async {
    final j = await lireJson(File('${_dossierDanses.path}/${slug(nom)}.json'));
    return j == null ? Danse(nom: nom) : Danse.fromJson(j);
  }

  Future<void> sauverDanse(Danse d) =>
      ecrireJson(File('${_dossierDanses.path}/${slug(d.nom)}.json'), d.toJson());
}
