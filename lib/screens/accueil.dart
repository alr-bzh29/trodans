import 'package:flutter/material.dart';

import '../models.dart';
import '../storage.dart';
import '../util.dart';
import '../widgets.dart';
import 'cours_edition.dart';
import 'reglages.dart';
import 'sonotheque.dart';

/// Liste des cours, du plus récent au plus ancien.
class Accueil extends StatefulWidget {
  const Accueil({super.key});

  @override
  State<Accueil> createState() => _AccueilState();
}

class _AccueilState extends State<Accueil> {
  List<Cours>? _cours;
  bool _acces = true;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    _acces = await Depot.I.accesAccorde();
    if (!_acces) _acces = await Depot.I.demanderAcces();
    await _recharger();
  }

  Future<void> _recharger() async {
    final c = _acces ? await Depot.I.listerCours() : <Cours>[];
    if (mounted) setState(() => _cours = c);
  }

  Future<void> _nouveau() async {
    // Par défaut : le prochain vendredi (ou aujourd'hui si on est vendredi).
    var d = DateTime.now();
    d = DateTime(d.year, d.month, d.day);
    while (d.weekday != DateTime.friday) {
      d = d.add(const Duration(days: 1));
    }
    while (await Depot.I.coursExiste(dateIso(d))) {
      d = d.add(const Duration(days: 7));
    }
    final saison = saisonDe(d);
    final dejaFaits = (_cours ?? []).where((c) => c.saison == saison && c.date.compareTo(dateIso(d)) < 0);
    final c = Cours(date: dateIso(d), numero: dejaFaits.length + 1);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CoursEdition(cours: c, nouveau: true)),
    );
    _recharger();
  }

  Future<void> _ouvrir(Cours c) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CoursEdition(cours: c)));
    _recharger();
  }

  @override
  Widget build(BuildContext context) {
    final cours = _cours;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TroDañs'),
        actions: [
          IconButton(
            tooltip: 'Sonothèque',
            icon: const Icon(Icons.library_music),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SonothequeEcran())),
          ),
          IconButton(
            tooltip: 'Réglages',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ReglagesEcran()));
              _acces = await Depot.I.accesAccorde();
              _recharger();
            },
          ),
        ],
      ),
      body: !_acces
          ? _SansAcces(onReessayer: _demarrer)
          : cours == null
              ? const Center(child: CircularProgressIndicator())
              : cours.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Aucun cours pour l\'instant.\n\n'
                          'Commence par scanner ta sonothèque dans les Réglages, '
                          'puis crée ton premier cours avec le bouton +.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _recharger,
                      child: ListView.separated(
                        itemCount: cours.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final c = cours[i];
                          final faits = c.entrees.where((e) => e.fait).length;
                          return ListTile(
                            title: Text('Cours n°${c.numero} · ${dateFrCourte(c.jour)}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text([
                              if (c.theme.isNotEmpty) c.theme,
                              '${c.entrees.length} danses',
                              if (faits > 0) '$faits faites',
                              if (c.presents > 0) '${c.presents} présents',
                            ].join(' · ')),
                            trailing: Text(c.saison,
                                style: TextStyle(color: Theme.of(context).hintColor)),
                            onTap: () => _ouvrir(c),
                          );
                        },
                      ),
                    ),
      floatingActionButton: _acces
          ? FloatingActionButton.extended(
              onPressed: _nouveau,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau cours'),
            )
          : null,
      bottomNavigationBar: const MiniLecteur(),
    );
  }
}

class _SansAcces extends StatelessWidget {
  final VoidCallback onReessayer;
  const _SansAcces({required this.onReessayer});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'TroDañs a besoin de l\'accès aux fichiers pour lire ta sonothèque '
              'et enregistrer tes cours.\n\nSur l\'écran qui va s\'ouvrir, active '
              '« Autoriser l\'accès pour gérer tous les fichiers ».',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onReessayer, child: const Text('Autoriser l\'accès')),
          ],
        ),
      ),
    );
  }
}
