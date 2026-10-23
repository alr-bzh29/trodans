import 'package:flutter/material.dart';

import '../markdown.dart';
import '../models.dart';
import '../player.dart';
import '../storage.dart';
import '../util.dart';
import '../widgets.dart';
import 'en_cours.dart';
import 'fiche.dart';
import 'recap.dart';
import 'sonotheque.dart';

/// Préparation d'un cours : date, numéro, thème, notes, puis le déroulé :
/// pour chaque section, des danses, et sous chaque danse un ou plusieurs titres.
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
    setState(() => c.notes = r.trim());
    await _sauver();
  }

  Future<Titre?> _choisirTitre(String titreEcran, {String recherche = ''}) {
    return Navigator.push<Titre>(
      context,
      MaterialPageRoute(
        builder: (_) => SonothequeEcran(
            choix: true, titreEcran: titreEcran, rechercheInitiale: recherche),
      ),
    );
  }

  /// Ajoute une danse à la section (à partir d'un de ses titres).
  /// Si cette danse est déjà dans la section, le titre s'ajoute sous elle.
  Future<void> _ajouterDanse(Section s) async {
    final t = await _choisirTitre('Ajouter · ${s.label}');
    if (t == null) return;
    setState(() {
      Entree? existante;
      if (t.danse != null) {
        for (final e in c.entrees) {
          if (e.section == s && e.danse == t.danse) existante = e;
        }
      }
      if (existante != null) {
        if (!existante.titres.any((x) => x.chemin == t.chemin)) {
          existante.titres.add(TitreChoisi.depuis(t));
        }
      } else {
        c.entrees.add(Entree.depuisTitre(t, s));
      }
    });
    await _sauver();
  }

  Future<void> _ajouterTitre(Entree e) async {
    final t = await _choisirTitre('Titre pour ${e.nom}', recherche: e.danse ?? '');
    if (t == null) return;
    if (e.titres.any((x) => x.chemin == t.chemin)) return;
    setState(() => e.titres.add(TitreChoisi.depuis(t)));
    await _sauver();
  }

  Future<void> _retirerTitre(Entree e, TitreChoisi t) async {
    setState(() {
      e.titres.remove(t);
      if (e.choix >= e.titres.length) e.choix = 0;
    });
    await _sauver();
  }

  Future<void> _ecouter(TitreChoisi t, String nom) async {
    final ok = await Lecteur.I.charger(chemin: t.chemin, nom: nom, detail: t.detail, lancer: true);
    if (!ok && mounted) message(context, 'Fichier introuvable : ${t.chemin}');
  }

  Future<void> _renommer(Entree e) async {
    final ctrl = TextEditingController(text: e.danse ?? '');
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nom de la danse'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('OK')),
        ],
      ),
    );
    if (r == null) return;
    setState(() => e.danse = r.trim().isEmpty ? null : r.trim());
    await _sauver();
  }

  Future<void> _deplacer(Entree e, int sens) async {
    final memeSection = c.entrees.where((x) => x.section == e.section).toList();
    final i = memeSection.indexOf(e);
    final j = i + sens;
    if (j < 0 || j >= memeSection.length) return;
    final autre = memeSection[j];
    final a = c.entrees.indexOf(e);
    final b = c.entrees.indexOf(autre);
    setState(() {
      c.entrees[a] = autre;
      c.entrees[b] = e;
    });
    await _sauver();
  }

  Future<void> _changerSection(Entree e) async {
    final s = await showDialog<Section>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Déplacer vers'),
        children: [
          for (final s in Section.values)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, s), child: Text(s.label)),
        ],
      ),
    );
    if (s == null || s == e.section) return;
    setState(() {
      c.entrees.remove(e);
      e.section = s;
      c.entrees.add(e);
    });
    await _sauver();
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
        body: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _theme,
                decoration: const InputDecoration(
                    labelText: 'Thème', border: OutlineInputBorder(), isDense: true),
                onEditingComplete: _sauver,
              ),
            ),
            _carteNotes(),
            for (final s in Section.values) ..._section(s),
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

  Widget _carteNotes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _modifierNotes,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
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
    );
  }

  List<Widget> _section(Section s) {
    final entrees = c.entrees.where((e) => e.section == s).toList();
    final couleur = couleurSection(s, Theme.of(context).brightness);
    return [
      Container(
        margin: const EdgeInsets.fromLTRB(12, 20, 12, 4),
        padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(s.label.toUpperCase(),
                  style: TextStyle(
                      color: couleur, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: couleur),
              icon: const Icon(Icons.add),
              label: const Text('Danse'),
              onPressed: () => _ajouterDanse(s),
            ),
          ],
        ),
      ),
      for (final e in entrees) _danse(e, couleur),
    ];
  }

  Widget _danse(Entree e, Color couleur) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 28, color: couleur),
              const SizedBox(width: 10),
              if (e.fait) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => FicheEcran(entree: e))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(e.nom,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'titre':
                      await _ajouterTitre(e);
                    case 'nom':
                      await _renommer(e);
                    case 'haut':
                      await _deplacer(e, -1);
                    case 'bas':
                      await _deplacer(e, 1);
                    case 'section':
                      await _changerSection(e);
                    case 'suppr':
                      setState(() => c.entrees.remove(e));
                      await _sauver();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'titre', child: Text('Ajouter un titre')),
                  PopupMenuItem(value: 'nom', child: Text('Renommer la danse')),
                  PopupMenuItem(value: 'haut', child: Text('Monter')),
                  PopupMenuItem(value: 'bas', child: Text('Descendre')),
                  PopupMenuItem(value: 'section', child: Text('Changer de section')),
                  PopupMenuItem(value: 'suppr', child: Text('Retirer la danse du cours')),
                ],
              ),
            ],
          ),
          for (var i = 0; i < e.titres.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Écouter',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Lecteur.I.chemin == e.titres[i].chemin
                        ? Icons.graphic_eq
                        : Icons.play_circle_outline),
                    onPressed: () => _ecouter(e.titres[i], e.nom),
                  ),
                  Expanded(
                    child: Text(e.titres[i].detail,
                        style: TextStyle(
                            fontWeight: i == e.choix && e.titres.length > 1
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ),
                  IconButton(
                    tooltip: 'Retirer ce titre',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _retirerTitre(e, e.titres[i]),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: TextButton.icon(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Titre'),
              onPressed: () => _ajouterTitre(e),
            ),
          ),
        ],
      ),
    );
  }
}
