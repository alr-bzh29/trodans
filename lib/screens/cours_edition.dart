import 'package:flutter/material.dart';

import '../markdown.dart';
import '../models.dart';
import '../storage.dart';
import '../util.dart';
import '../widgets.dart';
import 'en_cours.dart';
import 'fiche.dart';
import 'lignes.dart';
import 'recap.dart';

/// Préparation d'un cours : date, numéro, thème, notes, puis les blocs
/// Échauffement, Mise en jambes, Mystère et le Corpus (révisions et nouvelles
/// danses dans l'ordre choisi). Les lignes se déplacent par glisser-déposer.
class CoursEdition extends StatefulWidget {
  final Cours cours;
  final bool nouveau;
  const CoursEdition({super.key, required this.cours, this.nouveau = false});

  @override
  State<CoursEdition> createState() => _CoursEditionState();
}

class _CoursEditionState extends State<CoursEdition> {
  late final Cours c = widget.cours;
  late final _theme = TextEditingController(text: c.theme);
  late final _numero = TextEditingController(text: '${c.numero}');
  late bool _enregistre = !widget.nouveau;

  @override
  void dispose() {
    _theme.dispose();
    _numero.dispose();
    super.dispose();
  }

  Future<void> _sauver() async {
    c.theme = _theme.text.trim();
    c.numero = int.tryParse(_numero.text) ?? c.numero;
    await Depot.I.sauverCours(c);
    _enregistre = true;
  }

  void _modifie() {
    if (mounted) setState(() {});
    _sauver();
  }

  Future<void> _changerDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: c.jour,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null || dateIso(d) == c.date) return;
    if (await Depot.I.coursExiste(dateIso(d))) {
      if (mounted) message(context, 'Un cours existe déjà le ${dateFr(d)}.');
      return;
    }
    if (_enregistre) await Depot.I.supprimerCours(c);
    setState(() => c.date = dateIso(d));
    await _sauver();
  }

  Future<void> _modifierNotes() async {
    final r = await editerMarkdown(context, 'Notes du cours', c.notes);
    if (r == null) return;
    c.notes = r.trim();
    _modifie();
  }

  Future<void> _ajouter(Bloc b) async {
    final e = await nouvelleLigne(context, b);
    if (e == null) return;
    // Même danse déjà dans le bloc : le titre s'ajoute sous elle.
    final existante = c.bloc(b).where((x) => x.danse != null && x.danse == e.danse).toList();
    if (existante.isNotEmpty && e.titres.isNotEmpty) {
      final x = existante.first;
      if (!x.titres.any((t) => t.chemin == e.titres.first.chemin)) x.titres.add(e.titres.first);
    } else {
      c.ajouter(e);
    }
    _modifie();
  }

  Future<void> _changerBloc(Entree e) async {
    final b = await showDialog<Bloc>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Déplacer vers'),
        children: [
          for (final b in Bloc.values)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, b), child: Text(b.label)),
        ],
      ),
    );
    if (b == null || b == e.section.bloc) return;
    c.entrees.remove(e);
    e.section = b.sectionParDefaut;
    c.ajouter(e);
    _modifie();
  }

  Future<void> _menu(Entree e, String v) async {
    switch (v) {
      case 'titres':
        await gererTitres(context, e, _modifie);
      case 'nom':
        final r = await saisirTexte(context, 'Nom de la danse', initial: e.danse ?? '');
        if (r == null) return;
        e.danse = r.trim().isEmpty ? null : r.trim();
        _modifie();
      case 'lien':
        final r = await saisirTexte(context, 'Lien (vidéo YouTube…)',
            initial: e.lien ?? '', aide: 'Laisse vide pour retirer le lien.', clavier: TextInputType.url);
        if (r == null) return;
        e.lien = r.trim().isEmpty ? null : r.trim();
        _modifie();
      case 'bloc':
        await _changerBloc(e);
      case 'suppr':
        c.entrees.remove(e);
        _modifie();
    }
  }

  Future<void> _supprimer() async {
    if (!await confirmer(context, 'Supprimer ce cours ?', oui: 'Supprimer')) return;
    await Depot.I.supprimerCours(c);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        final aGarder = _enregistre ||
            c.entrees.isNotEmpty ||
            _theme.text.trim().isNotEmpty ||
            c.notes.trim().isNotEmpty;
        if (aGarder) _sauver();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Cours n°${c.numero}'),
          actions: [
            IconButton(
              tooltip: 'Récap WhatsApp',
              icon: const Icon(Icons.chat),
              onPressed: () async {
                await _sauver();
                if (!context.mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) => RecapEcran(cours: c)));
              },
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'suppr') _supprimer();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'suppr', child: Text('Supprimer le cours')),
              ],
            ),
          ],
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _entete()),
            for (final b in Bloc.values) ...[
              SliverToBoxAdapter(child: _titreBloc(b)),
              _liste(b),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Démarrer le cours'),
          onPressed: c.entrees.isEmpty
              ? null
              : () async {
                  await _sauver();
                  if (!context.mounted) return;
                  await Navigator.push(
                      context, MaterialPageRoute(builder: (_) => EnCours(cours: c)));
                  setState(() {});
                },
        ),
        bottomNavigationBar: const MiniLecteur(),
      ),
    );
  }

  Widget _entete() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(dateFrCourte(c.jour)),
                  onPressed: _changerDate,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _numero,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'N°', border: OutlineInputBorder(), isDense: true),
                  onChanged: (v) => setState(() => c.numero = int.tryParse(v) ?? c.numero),
                  onEditingComplete: _sauver,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _theme,
            decoration: const InputDecoration(
                labelText: 'Thème', border: OutlineInputBorder(), isDense: true),
            onEditingComplete: _sauver,
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _modifierNotes,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 6, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('NOTES DU COURS',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: Theme.of(context).colorScheme.primary)),
                        ),
                        IconButton(
                          tooltip: 'Modifier les notes',
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: _modifierNotes,
                        ),
                      ],
                    ),
                    if (c.notes.trim().isEmpty)
                      Text('Touche pour écrire tes notes (Markdown : **gras**, - listes…)',
                          style: TextStyle(color: Theme.of(context).hintColor))
                    else
                      MarkdownSimple(c.notes, taille: 15),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titreBloc(Bloc b) {
    final couleur = couleurBloc(b, context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 20, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(b.label.toUpperCase(),
                style: TextStyle(color: couleur, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: couleur),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
            onPressed: () => _ajouter(b),
          ),
        ],
      ),
    );
  }

  Widget _liste(Bloc b) {
    final lignes = c.bloc(b);
    return SliverReorderableList(
      itemCount: lignes.length,
      // onReorderItem : « nouveau » est déjà corrigé pour l'élément retiré.
      onReorderItem: (ancien, nouveau) {
        c.deplacer(b, ancien, nouveau);
        _modifie();
      },
      itemBuilder: (context, i) {
        final e = lignes[i];
        return Material(
          key: ValueKey(e.id),
          color: Colors.transparent,
          child: _ligne(e, i, b),
        );
      },
    );
  }

  Widget _ligne(Entree e, int i, Bloc b) {
    final couleur = couleurSection(e.section, Theme.of(context).brightness);
    return InkWell(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => FicheEcran(entree: e))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 0, 2),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: i,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.drag_indicator),
              ),
            ),
            if (b == Bloc.corpus) ...[
              EtiquetteType(
                entree: e,
                onBascule: () {
                  basculerType(e);
                  _modifie();
                },
              ),
              const SizedBox(width: 10),
            ] else
              Container(width: 4, height: 36, margin: const EdgeInsets.only(right: 10), color: couleur),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (e.fait)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.check_circle, color: Colors.green, size: 18),
                          ),
                        Flexible(
                          child: Text(e.nom,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: e.titres.isEmpty ? null : () => gererTitres(context, e, _modifie),
                      child: Text(sousTitre(e),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Theme.of(context).hintColor)),
                    ),
                  ],
                ),
              ),
            ),
            if (e.lien != null)
              IconButton(
                tooltip: 'Ouvrir le lien',
                icon: const Icon(Icons.ondemand_video),
                onPressed: () => ouvrirLienEntree(context, e),
              ),
            PopupMenuButton<String>(
              onSelected: (v) => _menu(e, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'titres', child: Text('Titres…')),
                PopupMenuItem(value: 'nom', child: Text('Nom de la danse')),
                PopupMenuItem(value: 'lien', child: Text('Lien vidéo')),
                PopupMenuItem(value: 'bloc', child: Text('Changer de partie')),
                PopupMenuItem(value: 'suppr', child: Text('Retirer du cours')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
