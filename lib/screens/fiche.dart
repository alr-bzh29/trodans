import 'package:flutter/material.dart';

import '../models.dart';
import '../player.dart';
import '../storage.dart';
import '../widgets.dart';

/// Fiche d'une danse du cours, avec un mini-lecteur en haut :
/// retour au début, lecture/pause, temps écoulé et restant.
class FicheEcran extends StatefulWidget {
  final Entree entree;
  final bool sombre;
  const FicheEcran({super.key, required this.entree, this.sombre = false});

  @override
  State<FicheEcran> createState() => _FicheEcranState();
}

class _FicheEcranState extends State<FicheEcran> {
  Danse? _danse;

  Entree get e => widget.entree;

  @override
  void initState() {
    super.initState();
    Depot.I.lireDanse(e.nom).then((d) {
      if (mounted) setState(() => _danse = d);
    });
  }

  Future<void> _lecturePause() async {
    final l = Lecteur.I;
    if (e.chemin != null && l.chemin != e.chemin) {
      final ok = await l.charger(chemin: e.chemin!, nom: e.nom, detail: e.detail, lancer: true);
      if (!ok && mounted) message(context, 'Fichier introuvable : ${e.chemin}');
    } else {
      l.basculer();
    }
  }

  Future<void> _modifierNote() async {
    final d = _danse;
    if (d == null) return;
    final ctrl = TextEditingController(text: d.note);
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Note · ${d.nom}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 4,
          maxLines: 12,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (r == null) return;
    d.note = r.trim();
    await Depot.I.sauverDanse(d);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final contenu = Scaffold(
      appBar: AppBar(
        title: Text(e.section.label),
        actions: [
          IconButton(
            tooltip: 'Modifier la note',
            icon: const Icon(Icons.edit),
            onPressed: _modifierNote,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(148),
          child: _MiniControle(entree: e, onLecture: _lecturePause),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(e.nom,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, height: 1.1)),
          const SizedBox(height: 4),
          Text(e.detail, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 15)),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MA NOTE',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 8),
                  if (_danse == null)
                    const LinearProgressIndicator()
                  else if (_danse!.note.isEmpty)
                    TextButton.icon(
                      onPressed: _modifierNote,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une note pour cette danse'),
                    )
                  else
                    Text(_danse!.note, style: const TextStyle(fontSize: 19, height: 1.45)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (!widget.sombre) return contenu;
    return Theme(data: themeEnCours(context), child: contenu);
  }
}

class _MiniControle extends StatelessWidget {
  final Entree entree;
  final VoidCallback onLecture;
  const _MiniControle({required this.entree, required this.onLecture});

  @override
  Widget build(BuildContext context) {
    final l = Lecteur.I;
    return ListenableBuilder(
      listenable: l,
      builder: (context, _) {
        final actif = l.chemin != null && l.chemin == entree.chemin;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Retour au début',
                  iconSize: 28,
                  icon: const Icon(Icons.skip_previous),
                  onPressed: actif ? l.auDebut : null,
                ),
                const SizedBox(width: 16),
                IconButton.filled(
                  tooltip: actif && l.enLecture ? 'Pause' : 'Lecture',
                  iconSize: 40,
                  icon: Icon(actif && l.enLecture ? Icons.pause : Icons.play_arrow),
                  onPressed: entree.chemin == null ? null : onLecture,
                ),
                if (!actif && l.chemin != null) ...[
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text('En cours : ${l.nom}',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
            const Progression(restant: true, taillePolice: 18),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

/// Thème sombre du mode « en cours ».
ThemeData themeEnCours(BuildContext context) => ThemeData(
      colorSchemeSeed: const Color(0xFFF2B66D),
      brightness: Brightness.dark,
      useMaterial3: true,
    );
