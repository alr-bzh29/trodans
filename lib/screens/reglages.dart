import 'package:flutter/material.dart';

import '../storage.dart';
import '../util.dart';
import '../widgets.dart';
import 'a_propos.dart';
import 'aide_synchro.dart';

class ReglagesEcran extends StatefulWidget {
  const ReglagesEcran({super.key});

  @override
  State<ReglagesEcran> createState() => _ReglagesEcranState();
}

class _ReglagesEcranState extends State<ReglagesEcran> {
  final r = Depot.I.reglages;
  late final _musique = TextEditingController(text: r.racineMusique);
  late final _donnees = TextEditingController(text: r.dossierDonnees);
  bool _scan = false;
  bool? _acces;

  @override
  void initState() {
    super.initState();
    Depot.I.accesAccorde().then((v) {
      if (mounted) setState(() => _acces = v);
    });
  }

  @override
  void dispose() {
    _musique.dispose();
    _donnees.dispose();
    super.dispose();
  }

  String _nettoyer(String s) {
    var t = s.trim();
    while (t.length > 1 && t.endsWith('/')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }

  Future<void> _enregistrer() async {
    r.racineMusique = _nettoyer(_musique.text);
    r.dossierDonnees = _nettoyer(_donnees.text);
    await Depot.I.sauverReglages();
  }

  Future<void> _scanner() async {
    await _enregistrer();
    setState(() => _scan = true);
    try {
      final n = await Depot.I.scanner();
      if (mounted) message(context, '$n titres trouvés');
    } catch (e) {
      if (mounted) message(context, 'Échec du scan : $e');
    } finally {
      if (mounted) setState(() => _scan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dernier = Depot.I.dernierScan;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _enregistrer();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Réglages')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_acces == false)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  title: const Text('Accès aux fichiers non accordé'),
                  trailing: FilledButton(
                    onPressed: () async {
                      final v = await Depot.I.demanderAcces();
                      if (mounted) setState(() => _acces = v);
                    },
                    child: const Text('Autoriser'),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _musique,
              decoration: const InputDecoration(
                labelText: 'Dossier de la sonothèque',
                helperText: 'Dossier contenant tes mp3 et ogg (sous-dossier = danse)',
                border: OutlineInputBorder(),
              ),
              onEditingComplete: _enregistrer,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _donnees,
              decoration: const InputDecoration(
                labelText: 'Dossier des données (à synchroniser)',
                helperText: 'Cours et notes, un fichier par fiche',
                border: OutlineInputBorder(),
              ),
              onEditingComplete: _enregistrer,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _scan ? null : _scanner,
              icon: _scan
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.manage_search),
              label: Text(_scan ? 'Scan en cours…' : 'Scanner la sonothèque'),
            ),
            const SizedBox(height: 8),
            Text(
              dernier == null
                  ? 'Jamais scannée'
                  : 'Dernier scan : ${dateFr(dernier)} ${deux(dernier.hour)}:${deux(dernier.minute)}'
                      ' · ${Depot.I.titres.length} titres',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 32),
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.sync),
              title: const Text('Synchroniser avec le PC'),
              subtitle: const Text('Aide pour installer Syncthing'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const AideSynchroEcran())),
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('À propos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AProposEcran())),
            ),
          ],
        ),
      ),
    );
  }
}
