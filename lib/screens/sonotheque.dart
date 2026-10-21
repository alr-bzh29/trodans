import 'package:flutter/material.dart';

import '../models.dart';
import '../player.dart';
import '../storage.dart';
import '../util.dart';
import '../widgets.dart';

/// Liste et recherche des titres. En mode choix, un appui sur un titre le renvoie
/// à l'écran précédent (ajout à un cours) ; le bouton lecture permet d'écouter avant.
class SonothequeEcran extends StatefulWidget {
  final bool choix;
  final String? titreEcran;
  const SonothequeEcran({super.key, this.choix = false, this.titreEcran});

  @override
  State<SonothequeEcran> createState() => _SonothequeEcranState();
}

class _SonothequeEcranState extends State<SonothequeEcran> {
  String _recherche = '';

  List<Titre> get _filtres {
    final mots = plier(_recherche).split(' ').where((m) => m.isNotEmpty).toList();
    if (mots.isEmpty) return Depot.I.titres;
    return Depot.I.titres.where((t) => mots.every(t.cleRecherche.contains)).toList();
  }

  Future<void> _ecouter(Titre t) async {
    final ok = await Lecteur.I.charger(
      chemin: t.chemin,
      nom: t.danse ?? t.titre,
      detail: t.artiste == null ? t.titre : '${t.titre} — ${t.artiste}',
      lancer: true,
    );
    if (!ok && mounted) message(context, 'Fichier introuvable : ${t.chemin}');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final liste = _filtres;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titreEcran ?? 'Sonothèque'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              autofocus: widget.choix,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Danse, titre, artiste…',
                border: const OutlineInputBorder(),
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (v) => setState(() => _recherche = v),
            ),
          ),
        ),
      ),
      body: Depot.I.titres.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'La sonothèque est vide.\nLance un scan dans les Réglages.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${liste.length} titres',
                        style: TextStyle(color: Theme.of(context).hintColor)),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: liste.length,
                    itemBuilder: (context, i) {
                      final t = liste[i];
                      final enCours = Lecteur.I.chemin == t.chemin;
                      final infos = [
                        t.artiste == null ? t.titre : '${t.titre} — ${t.artiste}',
                        if (t.dureeMs != null) duree(Duration(milliseconds: t.dureeMs!)),
                      ].join(' · ');
                      return ListTile(
                        selected: enCours,
                        leading: IconButton(
                          tooltip: 'Écouter',
                          icon: Icon(enCours ? Icons.graphic_eq : Icons.play_circle_outline),
                          onPressed: () => _ecouter(t),
                        ),
                        title: Text(t.danse ?? t.titre,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(infos),
                        trailing: widget.choix ? const Icon(Icons.add_circle) : null,
                        onTap: widget.choix ? () => Navigator.pop(context, t) : () => _ecouter(t),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const MiniLecteur(),
    );
  }
}
