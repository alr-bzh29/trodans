import 'package:flutter/material.dart';

import '../models.dart';
import '../storage.dart';
import '../util.dart';
import '../widgets.dart';
import 'en_cours.dart';
import 'fiche.dart';
import 'recap.dart';
import 'sonotheque.dart';

/// Préparation d'un cours : date, numéro, thème, déroulé par section, notes.
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
  late final _notes = TextEditingController(text: c.notes);
  late final _numero = TextEditingController(text: '${c.numero}');
  late bool _enregistre = !widget.nouveau;

  @override
  void dispose() {
    _theme.dispose();
    _notes.dispose();
    _numero.dispose();
    super.dispose();
  }

  Future<void> _sauver() async {
    c.theme = _theme.text.trim();
    c.notes = _notes.text;
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

  Future<void> _ajouter(Section s) async {
    final t = await Navigator.push<Titre>(
      context,
      MaterialPageRoute(
        builder: (_) => SonothequeEcran(choix: true, titreEcran: 'Ajouter · ${s.label}'),
      ),
    );
    if (t == null) return;
    setState(() => c.entrees.add(Entree.depuisTitre(t, s)));
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
            _notes.text.trim().isNotEmpty;
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
            for (final s in Section.values) ..._section(s),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _notes,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                    labelText: 'Notes du cours', border: OutlineInputBorder()),
              ),
            ),
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
      ),
    );
  }

  List<Widget> _section(Section s) {
    final entrees = c.entrees.where((e) => e.section == s).toList();
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        );
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 4, 0),
        child: Row(
          children: [
            Expanded(child: Text(s.label.toUpperCase(), style: style)),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
              onPressed: () => _ajouter(s),
            ),
          ],
        ),
      ),
      for (final e in entrees)
        ListTile(
          dense: true,
          title: Text(e.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(e.detail),
          leading: e.fait ? const Icon(Icons.check_circle, color: Colors.green) : null,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => FicheEcran(entree: e))),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
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
              PopupMenuItem(value: 'haut', child: Text('Monter')),
              PopupMenuItem(value: 'bas', child: Text('Descendre')),
              PopupMenuItem(value: 'section', child: Text('Changer de section')),
              PopupMenuItem(value: 'suppr', child: Text('Retirer du cours')),
            ],
          ),
        ),
    ];
  }
}
