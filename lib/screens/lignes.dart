// Éléments communs à la préparation et au mode « en cours » :
// ajout d'une ligne, gestion des titres d'une danse, étiquette Révision/Nouveau.

import 'package:flutter/material.dart';

import '../liens.dart';
import '../markdown.dart';
import '../models.dart';
import '../player.dart';
import '../widgets.dart';
import 'sonotheque.dart';

Future<Titre?> choisirTitre(BuildContext context, String titreEcran, {String recherche = ''}) {
  return Navigator.push<Titre>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          SonothequeEcran(choix: true, titreEcran: titreEcran, rechercheInitiale: recherche),
    ),
  );
}

/// Saisie d'un texte sur une ligne. Renvoie null si annulé.
Future<String?> saisirTexte(BuildContext context, String titre,
    {String initial = '', String? aide, TextInputType? clavier}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titre),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: clavier,
        decoration: InputDecoration(helperText: aide, helperMaxLines: 2),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('OK')),
      ],
    ),
  );
}

/// Crée une nouvelle ligne pour le bloc : depuis la sonothèque, ou un nom libre.
Future<Entree?> nouvelleLigne(BuildContext context, Bloc bloc) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Ajouter · ${bloc.label}',
                style: Theme.of(c).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.library_music),
            title: const Text('Choisir un titre dans la sonothèque'),
            onTap: () => Navigator.pop(c, 'sono'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Saisir un nom de danse'),
            subtitle: const Text('Musique jouée ailleurs (Spotify, YouTube…), lien facultatif'),
            onTap: () => Navigator.pop(c, 'libre'),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  final section = bloc.sectionParDefaut;
  if (source == 'sono') {
    final t = await choisirTitre(context, 'Ajouter · ${bloc.label}');
    return t == null ? null : Entree.depuisTitre(t, section);
  }
  final nom = await saisirTexte(context, 'Nom de la danse');
  if (nom == null || nom.trim().isEmpty || !context.mounted) return null;
  final lien = await saisirTexte(context, 'Lien (facultatif)',
      aide: 'Ex. une vidéo YouTube, ouverte dans Brave. Laisse vide si aucun.',
      clavier: TextInputType.url);
  return Entree.libre(nom.trim(), section,
      lien: (lien == null || lien.trim().isEmpty) ? null : lien.trim());
}

/// Feuille de gestion des titres d'une danse : choisir, écouter, retirer, ajouter.
/// [modifie] est appelé après chaque changement (pour enregistrer).
Future<void> gererTitres(BuildContext context, Entree e, VoidCallback modifie) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text('Titres · ${e.nom}', style: Theme.of(c).textTheme.titleMedium),
              ),
              if (e.titres.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Aucun titre de la sonothèque pour cette danse.'),
                ),
              for (var i = 0; i < e.titres.length; i++)
                ListTile(
                  leading: Icon(i == e.choix
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
                  title: Text(e.titres[i].detail),
                  onTap: () {
                    setState(() => e.choix = i);
                    modifie();
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Écouter',
                        icon: const Icon(Icons.play_circle_outline),
                        onPressed: () async {
                          final ok = await Lecteur.I.charger(
                              chemin: e.titres[i].chemin,
                              nom: e.nom,
                              detail: e.titres[i].detail,
                              lancer: true);
                          if (!ok && c.mounted) message(c, 'Fichier introuvable');
                        },
                      ),
                      IconButton(
                        tooltip: 'Retirer ce titre',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            e.titres.removeAt(i);
                            if (e.choix >= e.titres.length) e.choix = 0;
                          });
                          modifie();
                        },
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un titre'),
                onPressed: () async {
                  final t = await choisirTitre(c, 'Titre pour ${e.nom}', recherche: e.danse ?? '');
                  if (t == null || e.titres.any((x) => x.chemin == t.chemin)) return;
                  setState(() {
                    e.titres.add(TitreChoisi.depuis(t));
                    e.danse ??= t.danse;
                  });
                  modifie();
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Pastille « Révision » / « Nouveau » ; un appui bascule de l'une à l'autre.
class EtiquetteType extends StatelessWidget {
  final Entree entree;
  final VoidCallback? onBascule;
  const EtiquetteType({super.key, required this.entree, this.onBascule});

  @override
  Widget build(BuildContext context) {
    final couleur = couleurSection(entree.section, Theme.of(context).brightness);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onBascule,
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.15),
          border: Border.all(color: couleur),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(entree.section.label,
            style: TextStyle(color: couleur, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}

/// Bascule Révision ↔ Nouveau.
void basculerType(Entree e) {
  e.section = e.section == Section.nouvelles ? Section.revisions : Section.nouvelles;
}

/// Deuxième ligne affichée sous le nom de la danse.
String sousTitre(Entree e) {
  if (e.titres.isEmpty) {
    return e.lien == null ? 'Nom libre (hors sonothèque)' : 'Lien : ${e.lien}';
  }
  final autres = e.titres.length - 1;
  return autres > 0 ? '${e.detail}   (+$autres)' : e.detail;
}

Future<void> ouvrirLienEntree(BuildContext context, Entree e) async {
  final l = e.lien;
  if (l == null) return;
  final ok = await ouvrirLien(l);
  if (!ok && context.mounted) message(context, 'Impossible d\'ouvrir le lien');
}
