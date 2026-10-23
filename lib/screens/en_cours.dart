import 'dart:async';

import 'package:flutter/material.dart';

import '../markdown.dart';
import '../models.dart';
import '../player.dart';
import '../storage.dart';
import '../widgets.dart';
import 'fiche.dart';

/// Mode « en cours » : gros boutons, déroulé avec cases à cocher,
/// compteur de présents. L'écran peut se mettre en veille normalement.
class EnCours extends StatefulWidget {
  final Cours cours;
  const EnCours({super.key, required this.cours});

  @override
  State<EnCours> createState() => _EnCoursState();
}

class _EnCoursState extends State<EnCours> {
  late final Cours c = widget.cours;
  late final List<Entree> _deroule = c.deroule;
  int _index = 0;
  final Set<String> _reveles = {};

  Entree? get _courante => _deroule.isEmpty ? null : _deroule[_index];

  @override
  void initState() {
    super.initState();
    // Reprend à la première danse pas encore faite.
    final i = _deroule.indexWhere((e) => !e.fait);
    _index = i < 0 ? 0 : i;
    // Si le titre déjà chargé fait partie du cours, on le sélectionne.
    final j = _deroule.indexWhere((e) => e.chemin != null && e.chemin == Lecteur.I.chemin);
    if (j >= 0) _index = j;
  }

  Future<void> _sauver() => Depot.I.sauverCours(c);

  bool _masque(Entree e) => e.section == Section.mystere && !_reveles.contains(e.id);

  Future<void> _selectionner(int i, {bool lancer = false}) async {
    if (i < 0 || i >= _deroule.length) return;
    setState(() => _index = i);
    final e = _deroule[i];
    if (e.chemin == null) return;
    final ok = await Lecteur.I.charger(
      chemin: e.chemin!,
      nom: _masque(e) ? 'Mystère' : e.nom,
      detail: _masque(e) ? '' : e.detail,
      lancer: lancer,
    );
    if (!ok && mounted) message(context, 'Fichier introuvable : ${e.chemin}');
  }

  Future<void> _lecturePause() async {
    final e = _courante;
    if (e == null) return;
    if (Lecteur.I.chemin != e.chemin) {
      await _selectionner(_index, lancer: true);
    } else {
      Lecteur.I.basculer();
    }
  }

  Future<void> _choisirTitre(Entree e, int k) async {
    if (k == e.choix) return;
    final jouait = Lecteur.I.enLecture && Lecteur.I.chemin == e.chemin;
    setState(() => e.choix = k);
    unawaited(_sauver());
    if (_courante == e) await _selectionner(_index, lancer: jouait);
  }

  void _voirNotes() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notes du cours'),
        content: SingleChildScrollView(child: MarkdownSimple(c.notes, taille: 17)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
      ),
    );
  }

  void _presents(int delta) {
    setState(() => c.presents = (c.presents + delta).clamp(0, 999));
    _sauver();
  }

  Future<void> _terminer() async {
    await _sauver();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final e = _courante;
    return Theme(
      data: themeEnCours(context),
      child: Builder(builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text('Cours n°${c.numero}'),
            actions: [
              if (c.notes.trim().isNotEmpty)
                IconButton(
                  tooltip: 'Notes du cours',
                  onPressed: _voirNotes,
                  icon: const Icon(Icons.sticky_note_2_outlined),
                ),
              IconButton(
                tooltip: 'Un danseur de moins',
                onPressed: () => _presents(-1),
                icon: const Icon(Icons.remove),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${c.presents}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('présents', style: TextStyle(fontSize: 11)),
                ],
              ),
              IconButton(
                tooltip: 'Un danseur de plus',
                onPressed: () => _presents(1),
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              if (e != null) _carte(context, e, cs),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: _deroule.length,
                  itemBuilder: (context, i) {
                    final x = _deroule[i];
                    final courant = i == _index;
                    return Card(
                      color: courant ? cs.secondaryContainer : null,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: ListTile(
                        leading: Checkbox(
                          value: x.fait,
                          onChanged: (v) {
                            setState(() => x.fait = v ?? false);
                            _sauver();
                          },
                        ),
                        title: Text(
                          _masque(x) ? 'Mystère' : x.nom,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: x.fait ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          x.titres.length > 1
                              ? '${x.section.label} · ${x.titres.length} titres'
                              : x.section.label,
                          style: TextStyle(color: couleurSection(x.section, Brightness.dark)),
                        ),
                        onTap: () => _selectionner(i),
                        trailing: IconButton(
                          tooltip: 'Voir la fiche',
                          icon: const Icon(Icons.description_outlined),
                          onPressed: _masque(x)
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => FicheEcran(entree: x, sombre: true)),
                                  ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _terminer,
                child: const Text('Terminer'),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _carte(BuildContext context, Entree e, ColorScheme cs) {
    final l = Lecteur.I;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: ListenableBuilder(
          listenable: l,
          builder: (context, _) {
            final actif = l.chemin != null && l.chemin == e.chemin;
            final masque = _masque(e);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(e.section.label.toUpperCase(),
                        style: TextStyle(
                            color: couleurSection(e.section, Brightness.dark),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8)),
                    const Spacer(),
                    Text('${_index + 1} / ${_deroule.length}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(masque ? 'Danse mystère' : e.nom,
                              style: const TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.bold, height: 1.1)),
                          if (!masque)
                            Text(e.detail, style: TextStyle(color: Theme.of(context).hintColor)),
                        ],
                      ),
                    ),
                    if (masque)
                      OutlinedButton(
                        onPressed: () => setState(() => _reveles.add(e.id)),
                        child: const Text('Révéler'),
                      ),
                  ],
                ),
                if (e.titres.length > 1 && !masque)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (var k = 0; k < e.titres.length; k++)
                          ChoiceChip(
                            label: Text(e.titres[k].detail),
                            selected: k == e.choix,
                            onSelected: (_) => _choisirTitre(e, k),
                          ),
                      ],
                    ),
                  ),
                if (actif) const Progression(restant: false, taillePolice: 22)
                else const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Danse précédente',
                      iconSize: 28,
                      onPressed: _index > 0 ? () => _selectionner(_index - 1) : null,
                      icon: const Icon(Icons.skip_previous),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Reculer de 10 secondes',
                      iconSize: 28,
                      onPressed: actif ? () => l.decaler(-10) : null,
                      icon: const Icon(Icons.replay_10),
                    ),
                    IconButton.filled(
                      tooltip: actif && l.enLecture ? 'Pause' : 'Lecture',
                      iconSize: 52,
                      onPressed: e.chemin == null ? null : _lecturePause,
                      icon: Icon(actif && l.enLecture ? Icons.pause : Icons.play_arrow),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Avancer de 10 secondes',
                      iconSize: 28,
                      onPressed: actif ? () => l.decaler(10) : null,
                      icon: const Icon(Icons.forward_10),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Danse suivante',
                      iconSize: 28,
                      onPressed: _index < _deroule.length - 1
                          ? () => _selectionner(_index + 1)
                          : null,
                      icon: const Icon(Icons.skip_next),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Retour au début du morceau',
                      onPressed: actif ? l.auDebut : null,
                      icon: const Icon(Icons.first_page),
                    ),
                    const Icon(Icons.volume_up, size: 20),
                    Expanded(
                      child: Slider(
                        value: l.volume.clamp(0.0, 1.0),
                        onChanged: (v) => l.regleVolume(v),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
