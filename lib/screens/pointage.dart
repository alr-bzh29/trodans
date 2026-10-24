import 'package:flutter/material.dart';

import '../models.dart';
import '../storage.dart';
import '../util.dart';

/// Ajoute des danseurs à partir d'un texte (un prénom par ligne, ou séparés
/// par des virgules). Renvoie les danseurs créés.
List<Danseur> ajouterPrenoms(List<Danseur> liste, String texte) {
  final crees = <Danseur>[];
  final existants = {for (final d in liste) plier(d.prenom)};
  for (final brut in texte.split(RegExp(r'[\n,;]'))) {
    final p = brut.trim();
    if (p.isEmpty || existants.contains(plier(p))) continue;
    final d = Danseur(id: nouvelId(), prenom: p);
    liste.add(d);
    crees.add(d);
    existants.add(plier(p));
  }
  liste.sort((a, b) => plier(a.prenom).compareTo(plier(b.prenom)));
  return crees;
}

/// Ouvre la feuille de pointage du cours. [modifie] est appelé à chaque changement.
Future<void> pointer(BuildContext context, Cours c, VoidCallback modifie) async {
  final liste = await Depot.I.lireDanseurs();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _Pointage(cours: c, liste: liste, modifie: modifie),
    ),
  );
}

class _Pointage extends StatefulWidget {
  final Cours cours;
  final List<Danseur> liste;
  final VoidCallback modifie;
  const _Pointage({required this.cours, required this.liste, required this.modifie});

  @override
  State<_Pointage> createState() => _PointageState();
}

class _PointageState extends State<_Pointage> {
  String _recherche = '';
  final _ctrl = TextEditingController();

  Cours get c => widget.cours;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _changer(VoidCallback f) {
    setState(f);
    widget.modifie();
  }

  Future<void> _nouveau() async {
    final prenom = _recherche.trim();
    if (prenom.isEmpty) return;
    final crees = ajouterPrenoms(widget.liste, prenom);
    await Depot.I.sauverDanseurs(widget.liste);
    _ctrl.clear();
    _changer(() {
      _recherche = '';
      for (final d in crees) {
        c.pointes.add(d.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mots = plier(_recherche).trim();
    // Les danseurs actifs, plus les inactifs déjà pointés (pour pouvoir les décocher).
    final visibles = widget.liste
        .where((d) => d.actif || c.pointes.contains(d.id))
        .where((d) => mots.isEmpty || plier(d.prenom).contains(mots))
        .toList();
    final inconnu = mots.isNotEmpty && !widget.liste.any((d) => plier(d.prenom) == mots);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('${c.presents} présents',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const Text('Visiteurs'),
                IconButton(
                  tooltip: 'Un visiteur de moins',
                  onPressed: c.visiteurs > 0 ? () => _changer(() => c.visiteurs--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('${c.visiteurs}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  tooltip: 'Un visiteur de plus',
                  onPressed: () => _changer(() => c.visiteurs++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Chercher ou ajouter un prénom',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _recherche = v),
              onSubmitted: (_) {
                if (inconnu) _nouveau();
              },
            ),
          ),
          if (inconnu)
            ListTile(
              leading: const Icon(Icons.person_add),
              title: Text('Ajouter « ${_recherche.trim()} » et le pointer'),
              onTap: _nouveau,
            ),
          if (widget.liste.isEmpty && !inconnu)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'La liste des danseurs est vide. Tape un prénom ci-dessus pour l\'ajouter, '
                'ou remplis la liste dans Réglages › Liste des danseurs.',
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: visibles.length,
              itemBuilder: (context, i) {
                final d = visibles[i];
                final present = c.pointes.contains(d.id);
                return CheckboxListTile(
                  value: present,
                  title: Text(d.prenom, style: const TextStyle(fontSize: 18)),
                  subtitle: d.actif ? null : const Text('inactif'),
                  onChanged: (v) => _changer(() {
                    if (v == true) {
                      if (!present) c.pointes.add(d.id);
                    } else {
                      c.pointes.remove(d.id);
                    }
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Réglages › Liste des danseurs : ajout (un ou plusieurs), renommage,
/// désactivation. Affiche le nombre de venues de chacun.
class DanseursEcran extends StatefulWidget {
  const DanseursEcran({super.key});

  @override
  State<DanseursEcran> createState() => _DanseursEcranState();
}

class _DanseursEcranState extends State<DanseursEcran> {
  List<Danseur>? _liste;
  Map<String, int> _venues = {};

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final l = await Depot.I.lireDanseurs();
    final cours = await Depot.I.listerCours();
    final v = <String, int>{};
    for (final c in cours) {
      for (final id in c.pointes) {
        v[id] = (v[id] ?? 0) + 1;
      }
    }
    if (mounted) {
      setState(() {
        _liste = l;
        _venues = v;
      });
    }
  }

  Future<void> _sauver() async {
    await Depot.I.sauverDanseurs(_liste!);
    if (mounted) setState(() {});
  }

  Future<void> _ajouter() async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ajouter des danseurs'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 4,
          maxLines: 12,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            helperText: 'Un prénom par ligne (ex. « Marie 2 » pour distinguer deux Marie). '
                'Tu peux coller une liste.',
            helperMaxLines: 3,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Ajouter')),
        ],
      ),
    );
    if (r == null) return;
    final n = ajouterPrenoms(_liste!, r).length;
    await _sauver();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$n danseur(s) ajouté(s)')));
    }
  }

  Future<void> _renommer(Danseur d) async {
    final ctrl = TextEditingController(text: d.prenom);
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Prénom'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('OK')),
        ],
      ),
    );
    if (r == null || r.trim().isEmpty) return;
    d.prenom = r.trim();
    _liste!.sort((a, b) => plier(a.prenom).compareTo(plier(b.prenom)));
    await _sauver();
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    final actifs = l?.where((d) => d.actif).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Liste des danseurs')),
      body: l == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    '$actifs actifs · ${l.length - actifs} inactifs\n'
                    'Un danseur désactivé disparaît du pointage mais reste dans l\'historique.',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
                for (final d in l)
                  ListTile(
                    title: Text(d.prenom,
                        style: TextStyle(
                            fontSize: 17,
                            color: d.actif ? null : Theme.of(context).disabledColor)),
                    subtitle: Text('${_venues[d.id] ?? 0} venue(s)'),
                    onTap: () => _renommer(d),
                    trailing: Switch(
                      value: d.actif,
                      onChanged: (v) {
                        d.actif = v;
                        _sauver();
                      },
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: l == null ? null : _ajouter,
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
