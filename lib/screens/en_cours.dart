import 'dart:async';

import 'package:flutter/material.dart';

import '../markdown.dart';
import '../models.dart';
import '../player.dart';
import '../storage.dart';
import '../widgets.dart';
import 'fiche.dart';
import 'horloge.dart';
import 'lignes.dart';

/// Mode « en cours » : gros boutons, déroulé avec cases à cocher,
/// compteur de présents. Les lignes se déplacent par glisser-déposer
/// à l'intérieur de leur partie ; on peut ajouter ou retirer une danse.
/// L'écran peut se mettre en veille normalement.
class EnCours extends StatefulWidget {
  final Cours cours;
  const EnCours({super.key, required this.cours});

  @override
  State<EnCours> createState() => _EnCoursState();
}

class _EnCoursState extends State<EnCours> {
  late final Cours c = widget.cours;
  String? _courantId;
  final Set<String> _reveles = {};

  List<Entree> get _deroule => c.deroule;

  int get _index {
    final i = _deroule.indexWhere((e) => e.id == _courantId);
    return i < 0 ? 0 : i;
  }

  Entree? get _courante => _deroule.isEmpty ? null : _deroule[_index];

  @override
  void initState() {
    super.initState();
    final d = _deroule;
    // Reprend à la première danse pas encore faite…
    final pasFaite = d.where((e) => !e.fait);
    _courantId = pasFaite.isNotEmpty ? pasFaite.first.id : (d.isEmpty ? null : d.first.id);
    // … ou à celle dont le titre est déjà chargé dans le lecteur.
    for (final e in d) {
      if (e.titres.any((t) => t.chemin == Lecteur.I.chemin)) _courantId = e.id;
    }
  }

  Future<void> _sauver() => Depot.I.sauverCours(c);

  void _modifie() {
    if (mounted) setState(() {});
    _sauver();
  }

  bool _masque(Entree e) => e.section == Section.mystere && !_reveles.contains(e.id);

  Future<void> _selectionner(Entree e, {bool lancer = false}) async {
    setState(() => _courantId = e.id);
    if (e.chemin == null) return;
    final ok = await Lecteur.I.charger(
      chemin: e.chemin!,
      nom: _masque(e) ? 'Mystère' : e.nom,
      detail: _masque(e) ? '' : e.detail,
      lancer: lancer,
    );
    if (!ok && mounted) message(context, 'Fichier introuvable : ${e.chemin}');
  }

  void _voisin(int sens) {
    final d = _deroule;
    final j = _index + sens;
    if (j >= 0 && j < d.length) _selectionner(d[j]);
  }

  Future<void> _lecturePause() async {
    final e = _courante;
    if (e == null) return;
    if (Lecteur.I.chemin != e.chemin) {
      await _selectionner(e, lancer: true);
    } else {
      Lecteur.I.basculer();
    }
  }

  Future<void> _choisirTitre(Entree e, int k) async {
    if (k == e.choix) return;
    final jouait = Lecteur.I.enLecture && Lecteur.I.chemin == e.chemin;
    setState(() => e.choix = k);
    unawaited(_sauver());
    if (_courante == e) await _selectionner(e, lancer: jouait);
  }

  Future<void> _ajouter() async {
    final b = await showDialog<Bloc>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Ajouter dans'),
        children: [
          for (final b in Bloc.values)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, b), child: Text(b.label)),
        ],
      ),
    );
    if (b == null || !mounted) return;
    final e = await nouvelleLigne(context, b);
    if (e == null) return;
    c.ajouter(e);
    _modifie();
  }

  Future<void> _retirer(Entree e) async {
    if (!await confirmer(context, 'Retirer « ${e.nom} » du cours ?', oui: 'Retirer')) return;
    if (_courantId == e.id) {
      final d = _deroule;
      final i = d.indexOf(e);
      final suivant = i + 1 < d.length ? d[i + 1] : (i > 0 ? d[i - 1] : null);
      _courantId = suivant?.id;
    }
    c.entrees.remove(e);
    _modifie();
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
                tooltip: 'Ajouter une danse',
                onPressed: _ajouter,
                icon: const Icon(Icons.playlist_add),
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
              const HorlogeCours(),
              if (e != null) _carte(context, e),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    for (final b in Bloc.values)
                      if (c.bloc(b).isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                            child: Text(b.label.toUpperCase(),
                                style: TextStyle(
                                    color: couleurBloc(b, context),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8)),
                          ),
                        ),
                        _liste(b),
                      ],
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],
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

  Widget _liste(Bloc b) {
    final lignes = c.bloc(b);
    final cs = Theme.of(context).colorScheme;
    return SliverReorderableList(
      itemCount: lignes.length,
      // onReorderItem : « nouveau » est déjà corrigé pour l'élément retiré.
      onReorderItem: (ancien, nouveau) {
        c.deplacer(b, ancien, nouveau);
        _modifie();
      },
      itemBuilder: (context, i) {
        final x = lignes[i];
        final courant = x.id == _courante?.id;
        final masque = _masque(x);
        return Card(
          key: ValueKey(x.id),
          color: courant ? cs.secondaryContainer : null,
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _selectionner(x),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(8, 10, 2, 10),
                      child: Icon(Icons.drag_indicator),
                    ),
                  ),
                  Checkbox(
                    value: x.fait,
                    onChanged: (v) {
                      x.fait = v ?? false;
                      _modifie();
                    },
                  ),
                  if (b == Bloc.corpus) ...[
                    EtiquetteType(
                      entree: x,
                      onBascule: () {
                        basculerType(x);
                        _modifie();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          masque ? 'Mystère' : x.nom,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: x.fait ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (!masque)
                          Text(sousTitre(x),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      switch (v) {
                        case 'fiche':
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => FicheEcran(entree: x, sombre: true)),
                          );
                          if (mounted) setState(() {});
                        case 'titres':
                          await gererTitres(context, x, _modifie);
                        case 'retirer':
                          await _retirer(x);
                      }
                    },
                    itemBuilder: (_) => [
                      if (!masque) const PopupMenuItem(value: 'fiche', child: Text('Voir la fiche')),
                      if (!masque) const PopupMenuItem(value: 'titres', child: Text('Titres…')),
                      const PopupMenuItem(value: 'retirer', child: Text('Retirer du cours')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _carte(BuildContext context, Entree e) {
    final l = Lecteur.I;
    final d = _deroule;
    final i = _index;
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
                    Text(
                        e.section.bloc == Bloc.corpus
                            ? e.section.label.toUpperCase()
                            : e.section.bloc.label.toUpperCase(),
                        style: TextStyle(
                            color: couleurSection(e.section, Brightness.dark),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8)),
                    const Spacer(),
                    Text('${i + 1} / ${d.length}'),
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
                          if (!masque && e.titres.isNotEmpty)
                            Text(e.detail, style: TextStyle(color: Theme.of(context).hintColor)),
                        ],
                      ),
                    ),
                    if (masque)
                      OutlinedButton(
                        onPressed: () => setState(() => _reveles.add(e.id)),
                        child: const Text('Révéler'),
                      ),
                    if (e.lien != null && !masque)
                      IconButton.filledTonal(
                        tooltip: 'Ouvrir la vidéo',
                        iconSize: 28,
                        onPressed: () => ouvrirLienEntree(context, e),
                        icon: const Icon(Icons.ondemand_video),
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
                if (e.titres.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      e.lien != null ? 'Musique hors sonothèque : ouvre la vidéo.' : 'Musique hors sonothèque.',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  )
                else if (actif)
                  const Progression(restant: false, taillePolice: 22)
                else
                  const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Danse précédente',
                      iconSize: 28,
                      onPressed: i > 0 ? () => _voisin(-1) : null,
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
                      onPressed: i < d.length - 1 ? () => _voisin(1) : null,
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
