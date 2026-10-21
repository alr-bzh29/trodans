// Modèle de données de TroDañs.
//
// Un Titre est un fichier audio de la sonothèque (propre à chaque appareil :
// l'index est reconstruit par le scan). Un Cours et les notes de Danse sont
// des fichiers JSON dans le dossier de données synchronisé (Syncthing).

import 'util.dart';

enum Section { echauffement, mej, mystere, revisions, nouvelles, extras }

extension SectionLabel on Section {
  String get label => switch (this) {
        Section.echauffement => 'Échauffement',
        Section.mej => 'Mise en jambes',
        Section.mystere => 'Mystère',
        Section.revisions => 'Révisions',
        Section.nouvelles => 'Nouvelles danses',
        Section.extras => 'Extras',
      };
}

Section sectionFromName(String? name) =>
    Section.values.firstWhere((s) => s.name == name, orElse: () => Section.extras);

/// Un fichier audio de la sonothèque.
class Titre {
  /// Chemin relatif à la racine de la sonothèque, avec des « / ».
  final String chemin;
  final String titre;
  final String? artiste;

  /// Nom de la danse, déduit du dossier (« Gavotte/Titre - Artiste.mp3 »).
  final String? danse;

  /// Durée en millisecondes, connue après la première lecture.
  int? dureeMs;

  Titre({required this.chemin, required this.titre, this.artiste, this.danse, this.dureeMs});

  factory Titre.fromJson(Map<String, dynamic> j) => Titre(
        chemin: j['chemin'] as String,
        titre: j['titre'] as String,
        artiste: j['artiste'] as String?,
        danse: j['danse'] as String?,
        dureeMs: j['dureeMs'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'chemin': chemin,
        'titre': titre,
        if (artiste != null) 'artiste': artiste,
        if (danse != null) 'danse': danse,
        if (dureeMs != null) 'dureeMs': dureeMs,
      };

  /// Texte utilisé pour la recherche (sans accents, en minuscules).
  late final String cleRecherche = plier('${danse ?? ''} $titre ${artiste ?? ''} $chemin');

  /// Construit un Titre à partir de son chemin relatif.
  /// Les dossiers commençant par « _ » (ex. _Ecoute, _A classer) ne sont pas des danses.
  factory Titre.depuisChemin(String chemin) {
    final parties = chemin.split('/');
    final fichier = parties.last;
    final point = fichier.lastIndexOf('.');
    final base = point > 0 ? fichier.substring(0, point) : fichier;
    String titre = base;
    String? artiste;
    final sep = base.indexOf(' - ');
    if (sep > 0) {
      titre = base.substring(0, sep).trim();
      artiste = base.substring(sep + 3).trim();
    }
    String? danse;
    if (parties.length >= 2) {
      final dossier = parties[parties.length - 2];
      if (!dossier.startsWith('_')) danse = dossier;
    }
    return Titre(chemin: chemin, titre: titre, artiste: artiste, danse: danse);
  }
}

/// Une ligne du déroulé d'un cours.
class Entree {
  final String id;
  Section section;
  String? chemin;
  String titre;
  String? artiste;
  String? danse;
  bool fait;

  Entree({
    required this.id,
    required this.section,
    this.chemin,
    required this.titre,
    this.artiste,
    this.danse,
    this.fait = false,
  });

  factory Entree.depuisTitre(Titre t, Section s) => Entree(
        id: nouvelId(),
        section: s,
        chemin: t.chemin,
        titre: t.titre,
        artiste: t.artiste,
        danse: t.danse,
      );

  factory Entree.fromJson(Map<String, dynamic> j) => Entree(
        id: (j['id'] as String?) ?? nouvelId(),
        section: sectionFromName(j['section'] as String?),
        chemin: j['chemin'] as String?,
        titre: (j['titre'] as String?) ?? '',
        artiste: j['artiste'] as String?,
        danse: j['danse'] as String?,
        fait: (j['fait'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'section': section.name,
        if (chemin != null) 'chemin': chemin,
        'titre': titre,
        if (artiste != null) 'artiste': artiste,
        if (danse != null) 'danse': danse,
        'fait': fait,
      };

  /// Nom affiché : la danse si elle est connue, sinon le titre.
  String get nom => danse ?? titre;

  String get detail => artiste == null ? titre : '$titre — $artiste';
}

class Cours {
  /// Date au format AAAA-MM-JJ ; sert aussi de nom de fichier.
  String date;
  int numero;
  String theme;
  int presents;
  String notes;
  List<Entree> entrees;

  Cours({
    required this.date,
    this.numero = 1,
    this.theme = '',
    this.presents = 0,
    this.notes = '',
    List<Entree>? entrees,
  }) : entrees = entrees ?? [];

  factory Cours.fromJson(Map<String, dynamic> j) => Cours(
        date: j['date'] as String,
        numero: (j['numero'] as int?) ?? 1,
        theme: (j['theme'] as String?) ?? '',
        presents: (j['presents'] as int?) ?? 0,
        notes: (j['notes'] as String?) ?? '',
        entrees: ((j['entrees'] as List?) ?? [])
            .map((e) => Entree.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'date': date,
        'saison': saison,
        'numero': numero,
        'theme': theme,
        'presents': presents,
        'notes': notes,
        'entrees': entrees.map((e) => e.toJson()).toList(),
      };

  DateTime get jour => DateTime.parse(date);

  /// Saison d'août à juillet : « 2026-2027 ».
  String get saison => saisonDe(jour);

  /// Les entrées dans l'ordre du cours (par section, puis ordre d'ajout).
  List<Entree> get deroule {
    final res = <Entree>[];
    for (final s in Section.values) {
      res.addAll(entrees.where((e) => e.section == s));
    }
    return res;
  }
}

/// Note personnelle sur une danse (fichier danses/<nom>.json).
class Danse {
  final String nom;
  String note;

  Danse({required this.nom, this.note = ''});

  factory Danse.fromJson(Map<String, dynamic> j) =>
      Danse(nom: j['nom'] as String, note: (j['note'] as String?) ?? '');

  Map<String, dynamic> toJson() => {'version': 1, 'nom': nom, 'note': note};
}
