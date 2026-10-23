// Modèle de données de TroDañs.
//
// Un Titre est un fichier audio de la sonothèque (propre à chaque appareil :
// l'index est reconstruit par le scan). Un Cours et les notes de Danse sont
// des fichiers JSON dans le dossier de données synchronisé (Syncthing).

import 'util.dart';

/// Nature d'une ligne du cours. Les révisions et les nouvelles danses
/// forment ensemble le « corpus », dans un ordre libre.
enum Section { echauffement, mej, mystere, revisions, nouvelles }

/// Les blocs du cours, dans l'ordre : trois parties fixes, puis le corpus.
enum Bloc { echauffement, mej, mystere, corpus }

extension SectionLabel on Section {
  String get label => switch (this) {
        Section.echauffement => 'Échauffement',
        Section.mej => 'Mise en jambes',
        Section.mystere => 'Mystère',
        Section.revisions => 'Révision',
        Section.nouvelles => 'Nouveau',
      };

  Bloc get bloc => switch (this) {
        Section.echauffement => Bloc.echauffement,
        Section.mej => Bloc.mej,
        Section.mystere => Bloc.mystere,
        Section.revisions || Section.nouvelles => Bloc.corpus,
      };
}

extension BlocLabel on Bloc {
  String get label => switch (this) {
        Bloc.echauffement => 'Échauffement',
        Bloc.mej => 'Mise en jambes',
        Bloc.mystere => 'Mystère',
        Bloc.corpus => 'Corpus',
      };

  /// Section donnée à une danse ajoutée dans ce bloc.
  Section get sectionParDefaut => switch (this) {
        Bloc.echauffement => Section.echauffement,
        Bloc.mej => Section.mej,
        Bloc.mystere => Section.mystere,
        Bloc.corpus => Section.revisions,
      };
}

/// Les anciens « extras » deviennent des révisions.
Section sectionFromName(String? name) =>
    Section.values.firstWhere((s) => s.name == name, orElse: () => Section.revisions);

/// Un fichier audio de la sonothèque.
class Titre {
  /// Chemin relatif à la racine de la sonothèque, avec des « / ».
  final String chemin;
  final String titre;
  final String? artiste;
  final String? album;
  final String? genre;

  /// Nom de la danse : tag « genre », sinon dossier (« Gavotte/Titre - Artiste.mp3 »).
  final String? danse;

  /// Durée en millisecondes (lue au scan, ou à la première lecture).
  int? dureeMs;

  Titre({
    required this.chemin,
    required this.titre,
    this.artiste,
    this.album,
    this.genre,
    this.danse,
    this.dureeMs,
  });

  factory Titre.fromJson(Map<String, dynamic> j) => Titre(
        chemin: j['chemin'] as String,
        titre: j['titre'] as String,
        artiste: j['artiste'] as String?,
        album: j['album'] as String?,
        genre: j['genre'] as String?,
        danse: j['danse'] as String?,
        dureeMs: j['dureeMs'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'chemin': chemin,
        'titre': titre,
        if (artiste != null) 'artiste': artiste,
        if (album != null) 'album': album,
        if (genre != null) 'genre': genre,
        if (danse != null) 'danse': danse,
        if (dureeMs != null) 'dureeMs': dureeMs,
      };

  /// Texte utilisé pour la recherche (sans accents, en minuscules) :
  /// danse, titre, artiste, album, genre et chemin du fichier.
  late final String cleRecherche = plier(
      '${danse ?? ''} $titre ${artiste ?? ''} ${album ?? ''} ${genre ?? ''} $chemin');

  /// Construit un Titre à partir de son chemin relatif et, si disponibles, de ses tags.
  /// Les dossiers commençant par « _ » (ex. _Ecoute, _A classer) ne sont pas des danses.
  factory Titre.depuisChemin(String chemin,
      {String? tagTitre, String? tagArtiste, String? album, String? genre, int? dureeMs}) {
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
    String? dossier;
    if (parties.length >= 2) {
      final d = parties[parties.length - 2];
      if (!d.startsWith('_')) dossier = d;
    }
    return Titre(
      chemin: chemin,
      titre: tagTitre ?? titre,
      artiste: tagArtiste ?? artiste,
      album: album,
      genre: genre,
      danse: genre ?? dossier,
      dureeMs: dureeMs,
    );
  }
}

/// Un titre choisi pour une danse du cours (copie des infos du fichier,
/// pour rester lisible même si le fichier a été déplacé).
class TitreChoisi {
  final String chemin;
  final String titre;
  final String? artiste;

  TitreChoisi({required this.chemin, required this.titre, this.artiste});

  factory TitreChoisi.depuis(Titre t) =>
      TitreChoisi(chemin: t.chemin, titre: t.titre, artiste: t.artiste);

  factory TitreChoisi.fromJson(Map<String, dynamic> j) => TitreChoisi(
        chemin: j['chemin'] as String,
        titre: (j['titre'] as String?) ?? '',
        artiste: j['artiste'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'chemin': chemin, 'titre': titre, if (artiste != null) 'artiste': artiste};

  String get detail => artiste == null ? titre : '$titre — $artiste';
}

/// Une ligne du déroulé d'un cours : une danse et un ou plusieurs titres possibles.
class Entree {
  final String id;
  Section section;

  /// Nom de la danse (null pour un titre sans danse, ex. échauffement).
  String? danse;
  List<TitreChoisi> titres;

  /// Index du titre retenu pour la lecture.
  int choix;
  bool fait;

  /// Lien facultatif (ex. vidéo YouTube), ouvert dans Brave.
  String? lien;

  Entree({
    required this.id,
    required this.section,
    this.danse,
    List<TitreChoisi>? titres,
    this.choix = 0,
    this.fait = false,
    this.lien,
  }) : titres = titres ?? [];

  /// Danse saisie librement, sans titre de la sonothèque (ex. échauffement Spotify).
  factory Entree.libre(String danse, Section s, {String? lien}) =>
      Entree(id: nouvelId(), section: s, danse: danse, lien: lien);

  factory Entree.depuisTitre(Titre t, Section s) => Entree(
        id: nouvelId(),
        section: s,
        danse: t.danse,
        titres: [TitreChoisi.depuis(t)],
      );

  factory Entree.fromJson(Map<String, dynamic> j) {
    var titres = ((j['titres'] as List?) ?? [])
        .map((e) => TitreChoisi.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    // Ancien format (0.1.6) : un seul titre directement dans l'entrée.
    if (titres.isEmpty && j['chemin'] is String) {
      titres = [
        TitreChoisi(
          chemin: j['chemin'] as String,
          titre: (j['titre'] as String?) ?? '',
          artiste: j['artiste'] as String?,
        )
      ];
    }
    return Entree(
      id: (j['id'] as String?) ?? nouvelId(),
      section: sectionFromName(j['section'] as String?),
      danse: j['danse'] as String?,
      titres: titres,
      choix: (j['choix'] as int?) ?? 0,
      fait: (j['fait'] as bool?) ?? false,
      lien: j['lien'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'section': section.name,
        if (danse != null) 'danse': danse,
        'titres': titres.map((t) => t.toJson()).toList(),
        'choix': choix,
        'fait': fait,
        if (lien != null) 'lien': lien,
      };

  TitreChoisi? get titreChoisi =>
      titres.isEmpty ? null : titres[choix.clamp(0, titres.length - 1)];

  String? get chemin => titreChoisi?.chemin;
  String get titre => titreChoisi?.titre ?? '';
  String? get artiste => titreChoisi?.artiste;

  /// Nom affiché : la danse si elle est connue, sinon le titre.
  String get nom => danse ?? (titre.isEmpty ? '(sans nom)' : titre);

  String get detail => titreChoisi?.detail ?? '';
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
      )..normaliser();

  Map<String, dynamic> toJson() => {
        'version': 2,
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

  /// Les lignes d'un bloc, dans leur ordre.
  List<Entree> bloc(Bloc b) => entrees.where((e) => e.section.bloc == b).toList();

  /// Toutes les lignes dans l'ordre du cours : échauffement, mise en jambes,
  /// mystère, puis le corpus dans l'ordre choisi.
  List<Entree> get deroule => [for (final b in Bloc.values) ...bloc(b)];

  /// Range les lignes bloc par bloc (l'ordre à l'intérieur d'un bloc est conservé).
  void normaliser() => entrees = deroule;

  /// Déplace une ligne à l'intérieur de son bloc (indices du bloc).
  void deplacer(Bloc b, int ancien, int nouveau) {
    final l = bloc(b);
    if (ancien < 0 || ancien >= l.length) return;
    final e = l.removeAt(ancien);
    l.insert(nouveau.clamp(0, l.length), e);
    entrees = [for (final x in Bloc.values) ...(x == b ? l : bloc(x))];
  }

  /// Ajoute une ligne à la fin de son bloc.
  void ajouter(Entree e) {
    entrees.add(e);
    normaliser();
  }
}

/// Note personnelle sur une danse (fichier `danses/<nom>.json`).
class Danse {
  final String nom;
  String note;

  Danse({required this.nom, this.note = ''});

  factory Danse.fromJson(Map<String, dynamic> j) =>
      Danse(nom: j['nom'] as String, note: (j['note'] as String?) ?? '');

  Map<String, dynamic> toJson() => {'version': 1, 'nom': nom, 'note': note};
}
